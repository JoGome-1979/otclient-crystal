using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace OtmmTool
{
    internal sealed class SshEndpoint
    {
        public string Host;
        public string User;
        public string Port;
        public string MapPath;

        public string Target { get { return String.IsNullOrEmpty(User) ? Host : User + "@" + Host; } }
        public string Identity { get { return Target + "\n" + Port + "\n" + MapPath; } }
    }

    internal sealed class CommandResult
    {
        public int ExitCode;
        public string Output;
        public string Error;
    }

    public sealed class SshMapTab : TabPage
    {
        readonly ConversionTab decompressTab;
        readonly ConversionTab compressTab;
        readonly Action selectDecompressTab;
        readonly TextBox host = new TextBox { Dock = DockStyle.Fill, BorderStyle = BorderStyle.FixedSingle };
        readonly TextBox port = new TextBox { Dock = DockStyle.Fill, BorderStyle = BorderStyle.FixedSingle };
        readonly TextBox user = new TextBox { Dock = DockStyle.Fill, BorderStyle = BorderStyle.FixedSingle };
        readonly TextBox mapPath = new TextBox { Dock = DockStyle.Fill, BorderStyle = BorderStyle.FixedSingle, Text = "/home/crystal/crystalserver/data-global/world/world.otbm" };
        readonly Button test = new Button { Text = "Testar conexão", AutoSize = true };
        readonly Button download = new Button { Text = "1. Baixar mapa da VPS", AutoSize = true };
        readonly Button publish = new Button { Text = "Publicar mapa compactado…", AutoSize = true };
        readonly CheckBox stopped = new CheckBox { AutoSize = true, Text = "Servidor parado/em manutenção; reiniciarei depois da publicação." };
        readonly ProgressBar progress = new ProgressBar { Dock = DockStyle.Fill };
        readonly Label status = new Label { Dock = DockStyle.Fill, AutoSize = true,
            Text = "Informe o host/IP ou alias SSH. Usuário e porta podem ficar vazios quando já estiverem definidos em ~/.ssh/config." };
        string downloadedMap;
        string baselineHash;
        string endpointIdentity;
        bool busy;
        string sshExe;
        string scpExe;

        public bool Busy { get { return busy; } }

        public SshMapTab(ConversionTab decompressTab, ConversionTab compressTab, Action selectDecompressTab)
        {
            this.decompressTab = decompressTab;
            this.compressTab = compressTab;
            this.selectDecompressTab = selectDecompressTab;
            Text = "Servidor SSH";
            Padding = new Padding(22);
            BackColor = Color.White;

            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5 };
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 55));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 94));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 46));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            layout.Controls.Add(new Label { Dock = DockStyle.Fill,
                Text = "Baixe o world.otbm da VPS para editar e publique a cópia compactada por SSH.\n" +
                    "A publicação substitui o arquivo no disco; não atualiza o mapa que já está carregado no servidor." }, 0, 0);

            var fields = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 4, RowCount = 3, Padding = new Padding(0, 2, 0, 2) };
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 88));
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 48));
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 66));
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 52));
            fields.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
            fields.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
            fields.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
            fields.Controls.Add(FieldLabel("Host / alias"), 0, 0); fields.Controls.Add(host, 1, 0);
            fields.Controls.Add(FieldLabel("Porta"), 2, 0); fields.Controls.Add(port, 3, 0);
            fields.Controls.Add(FieldLabel("Usuário"), 0, 1); fields.Controls.Add(user, 1, 1); fields.SetColumnSpan(user, 3);
            fields.Controls.Add(FieldLabel("Mapa remoto"), 0, 2); fields.Controls.Add(mapPath, 1, 2); fields.SetColumnSpan(mapPath, 3);
            layout.Controls.Add(fields, 0, 1);

            var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight };
            buttons.Controls.AddRange(new Control[] { test, download, publish });
            layout.Controls.Add(buttons, 0, 2);
            layout.Controls.Add(stopped, 0, 3);
            var lower = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
            lower.RowStyles.Add(new RowStyle(SizeType.Absolute, 24));
            lower.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            lower.Controls.Add(progress, 0, 0); lower.Controls.Add(status, 0, 1);
            layout.Controls.Add(lower, 0, 4);
            Controls.Add(layout);

            test.Click += TestConnection;
            download.Click += DownloadMap;
            publish.Click += PublishMap;
            stopped.CheckedChanged += delegate { publish.Enabled = stopped.Checked && downloadedMap != null && !busy; };
            LoadSettings();
            publish.Enabled = false;
        }

        static Label FieldLabel(string text)
        {
            return new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left, TextAlign = ContentAlignment.MiddleLeft };
        }

        async void TestConnection(object sender, EventArgs e)
        {
            SshEndpoint endpoint;
            if (!TryReadEndpoint(out endpoint)) return;
            SaveSettings(endpoint);
            SetBusy(true, "Verificando SSH e acesso de leitura ao mapa…");
            try
            {
                string hash = await Task.Run(delegate { return ReadRemoteHash(endpoint); });
                status.Text = "Conexão OK. world.otbm acessível; SHA-256: " + hash;
            }
            catch (Exception ex) { ShowFailure("Falha na conexão SSH", ex); }
            finally { SetBusy(false, status.Text); }
        }

        async void DownloadMap(object sender, EventArgs e)
        {
            if (decompressTab.Busy)
            {
                MessageBox.Show(this, "Aguarde a conversão da aba Descompactar terminar antes de baixar outro mapa.",
                    "Conversão em andamento", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            SshEndpoint endpoint;
            if (!TryReadEndpoint(out endpoint)) return;
            SaveSettings(endpoint);
            SetBusy(true, "Baixando e validando o mapa da VPS…");
            string downloaded = null;
            try
            {
                var result = await Task.Run(delegate
                {
                    EnsureOpenSsh();
                    string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OTMapas", "CrystalServer", "downloads");
                    Directory.CreateDirectory(root);
                    string final = Path.Combine(root, "world-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".otbm");
                    string partial = final + ".part";
                    try
                    {
                        ScpDownload(endpoint, partial);
                        string localHash = HashFile(partial);
                        string remoteHash = ReadRemoteHash(endpoint);
                        if (!String.Equals(localHash, remoteHash, StringComparison.OrdinalIgnoreCase))
                            throw new IOException("O mapa mudou durante o download. Nenhuma cópia foi carregada; tente baixar novamente.");
                        ValidateCompressedMap(partial);
                        File.Move(partial, final);
                        return new KeyValuePair<string, string>(final, remoteHash);
                    }
                    finally { if (File.Exists(partial)) File.Delete(partial); }
                });
                downloaded = result.Key;
                downloadedMap = result.Key;
                baselineHash = result.Value;
                endpointIdentity = endpoint.Identity;
                publish.Enabled = stopped.Checked;
                if (!decompressTab.Busy)
                {
                    decompressTab.SelectFile(downloadedMap);
                    selectDecompressTab();
                    status.Text = "Download validado e selecionado na aba Descompactar. Converta para o editor; depois compacte e volte aqui para publicar.";
                }
                else status.Text = "Download validado em " + downloadedMap + ". A conversão já estava em andamento; abra esse arquivo manualmente na aba Descompactar quando terminar.";
            }
            catch (Exception ex) { ShowFailure("Não foi possível baixar o mapa", ex); }
            finally { SetBusy(false, status.Text); }
        }

        async void PublishMap(object sender, EventArgs e)
        {
            if (compressTab.Busy)
            {
                MessageBox.Show(this, "Aguarde a compactação e o salvamento da aba Compactar terminarem antes de publicar.",
                    "Conversão em andamento", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (!stopped.Checked)
            {
                MessageBox.Show(this, "Pare o CrystalServer ou coloque-o em manutenção antes de publicar. O app não consegue aplicar alterações ao mapa que já está carregado na memória.",
                    "Servidor precisa estar parado", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            SshEndpoint endpoint;
            if (!TryReadEndpoint(out endpoint)) return;
            if (String.IsNullOrEmpty(baselineHash) || !String.Equals(endpoint.Identity, endpointIdentity, StringComparison.Ordinal))
            {
                MessageBox.Show(this, "Baixe o mapa desta VPS nesta sessão antes de publicar. Isso permite detectar se o arquivo remoto mudou durante a edição.",
                    "Baixe o mapa primeiro", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            using (var dialog = new OpenFileDialog())
            {
                dialog.Title = "Selecione o world.otbm compactado para publicar";
                dialog.Filter = "Mapa GZIP do CrystalServer (*.otbm)|*.otbm|Todos os arquivos (*.*)|*.*";
                dialog.FileName = Path.GetFileName(mapPath.Text.Trim());
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                string localFile = dialog.FileName;
                string confirmation = "Publicar este arquivo no CrystalServer?\n\n" + endpoint.Target + ":" + endpoint.MapPath +
                    "\n\nSerá criado um backup remoto. Confirme que o servidor está parado ou em manutenção.";
                if (MessageBox.Show(this, confirmation, "Confirmar publicação", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;

                SetBusy(true, "Validando o mapa e enviando para a VPS…");
                try
                {
                    string backup = await Task.Run(delegate { return PublishCompressedMap(endpoint, localFile); });
                    baselineHash = HashFile(localFile);
                    status.Text = "Mapa publicado. Backup remoto: " + backup + "\nInicie o servidor para carregar o mapa novo.";
                }
                catch (Exception ex) { ShowFailure("Não foi possível publicar o mapa", ex); }
                finally { SetBusy(false, status.Text); }
            }
        }

        string PublishCompressedMap(SshEndpoint endpoint, string localFile)
        {
            EnsureOpenSsh();
            ValidateCompressedMap(localFile);
            string newHash = HashFile(localFile);
            string parent = endpoint.MapPath.Substring(0, endpoint.MapPath.LastIndexOf('/'));
            string stage = parent + "/.world.otbm.new." + Guid.NewGuid().ToString("N");
            string backup = endpoint.MapPath + ".backup." + DateTime.UtcNow.ToString("yyyyMMddTHHmmssZ") + "." + Guid.NewGuid().ToString("N").Substring(0, 8);
            try
            {
                ScpUpload(endpoint, localFile, stage);
                string command = BuildPublishCommand(endpoint.MapPath, stage, backup, baselineHash, newHash);
                ExecuteSsh(endpoint, command, 120000);
                return backup;
            }
            catch
            {
                try { ExecuteSsh(endpoint, "rm -f -- " + ShellQuote(stage), 30000); } catch { }
                throw;
            }
        }

        internal static string BuildPublishCommand(string target, string stage, string backup, string expectedOldHash, string expectedNewHash)
        {
            string qTarget = ShellQuote(target), qStage = ShellQuote(stage), qBackup = ShellQuote(backup);
            return "set -eu; " +
                "target=" + qTarget + "; stage=" + qStage + "; backup=" + qBackup + "; " +
                "trap 'rm -f -- \"$stage\"' EXIT HUP INT TERM; " +
                "test -f \"$target\"; " +
                "[ ! -L \"$target\" ] || { echo 'O caminho do mapa remoto é um link simbólico; publicação cancelada.' >&2; exit 45; }; " +
                "current=$(sha256sum -- \"$target\" | awk '{print $1}'); " +
                "[ \"$current\" = " + ShellQuote(expectedOldHash) + " ] || { echo 'O mapa remoto mudou desde o download; publicação cancelada.' >&2; exit 42; }; " +
                "gzip -t -- \"$stage\"; " +
                "uploaded=$(sha256sum -- \"$stage\" | awk '{print $1}'); " +
                "[ \"$uploaded\" = " + ShellQuote(expectedNewHash) + " ] || { echo 'Falha na verificação do arquivo enviado.' >&2; exit 43; }; " +
                "dest_owner=$(stat -c '%u:%g' -- \"$target\"); " +
                "stage_owner=$(stat -c '%u:%g' -- \"$stage\"); " +
                "[ \"$dest_owner\" = \"$stage_owner\" ] || { echo 'O usuário SSH não publica com o mesmo proprietário/grupo do mapa.' >&2; exit 44; }; " +
                "cp -p -- \"$target\" \"$backup\"; " +
                "chmod --reference=\"$target\" \"$stage\"; " +
                "mv -fT -- \"$stage\" \"$target\"; " +
                "trap - EXIT HUP INT TERM; printf 'BACKUP=%s\\n' \"$backup\";";
        }

        static void ValidateCompressedMap(string fileName)
        {
            string temp = Path.Combine(Path.GetTempPath(), "otmapas-ssh-check-" + Guid.NewGuid().ToString("N") + ".otbm");
            try { MapArchive.Convert(fileName, temp, false, null); }
            finally { if (File.Exists(temp)) File.Delete(temp); }
        }

        string ReadRemoteHash(SshEndpoint endpoint)
        {
            string command = "set -e; test -r " + ShellQuote(endpoint.MapPath) +
                "; sha256sum -- " + ShellQuote(endpoint.MapPath) + " | awk '{print $1}'";
            CommandResult result = ExecuteSsh(endpoint, command, 60000);
            string hash = result.Output.Trim();
            if (!Regex.IsMatch(hash, "^[a-fA-F0-9]{64}$"))
                throw new IOException("O SSH conectou, mas não consegui ler o SHA-256 remoto. Verifique se sha256sum está instalado.");
            return hash.ToLowerInvariant();
        }

        void ScpDownload(SshEndpoint endpoint, string localFile)
        {
            var args = NewSshOptions(false);
            AddPort(args, endpoint, true);
            args.Add(endpoint.Target + ":" + endpoint.MapPath);
            args.Add(localFile);
            RunCommand(GetScpExe(), args, 15 * 60 * 1000);
        }

        void ScpUpload(SshEndpoint endpoint, string localFile, string remoteFile)
        {
            var args = NewSshOptions(true);
            AddPort(args, endpoint, false);
            args.Add(localFile);
            args.Add(endpoint.Target + ":" + remoteFile);
            RunCommand(GetScpExe(), args, 15 * 60 * 1000);
        }

        CommandResult ExecuteSsh(SshEndpoint endpoint, string command, int timeout)
        {
            var args = NewSshOptions(false);
            AddPort(args, endpoint, true);
            args.Add(endpoint.Target);
            args.Add(command);
            return RunCommand(GetSshExe(), args, timeout);
        }

        static List<string> NewSshOptions(bool scp)
        {
            var args = new List<string>();
            if (scp) { args.Add("-q"); args.Add("-B"); }
            else args.Add("-T");
            args.Add("-o"); args.Add("BatchMode=yes");
            args.Add("-o"); args.Add("StrictHostKeyChecking=yes");
            args.Add("-o"); args.Add("ConnectTimeout=15");
            return args;
        }

        static void AddPort(List<string> args, SshEndpoint endpoint, bool ssh)
        {
            if (String.IsNullOrWhiteSpace(endpoint.Port)) return;
            args.Add(ssh ? "-p" : "-P");
            args.Add(endpoint.Port);
        }

        static CommandResult RunCommand(string executable, List<string> arguments, int timeout)
        {
            var info = new ProcessStartInfo { FileName = executable, Arguments = JoinArguments(arguments),
                UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8 };
            var output = new StringBuilder();
            var error = new StringBuilder();
            var gate = new object();
            using (var process = new Process { StartInfo = info, EnableRaisingEvents = true })
            {
                process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) lock (gate) output.AppendLine(e.Data); };
                process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) lock (gate) error.AppendLine(e.Data); };
                try
                {
                    if (!process.Start()) throw new IOException("Não foi possível iniciar o OpenSSH.");
                }
                catch (Exception ex) { throw new IOException("Não foi possível iniciar " + Path.GetFileName(executable) + ". Instale o OpenSSH Client do Windows ou o Git for Windows.", ex); }
                process.BeginOutputReadLine(); process.BeginErrorReadLine();
                if (!process.WaitForExit(timeout))
                {
                    try { process.Kill(); } catch { }
                    throw new TimeoutException(Path.GetFileName(executable) + " excedeu o tempo limite.");
                }
                process.WaitForExit();
                var result = new CommandResult { ExitCode = process.ExitCode, Output = output.ToString(), Error = error.ToString() };
                if (result.ExitCode != 0) throw CreateSshException(executable, result);
                return result;
            }
        }

        static Exception CreateSshException(string executable, CommandResult result)
        {
            string detail = (result.Error + "\n" + result.Output).Trim();
            string name = Path.GetFileName(executable);
            if (detail.IndexOf("Host key verification failed", StringComparison.OrdinalIgnoreCase) >= 0 ||
                detail.IndexOf("REMOTE HOST IDENTIFICATION HAS CHANGED", StringComparison.OrdinalIgnoreCase) >= 0)
                return new IOException("A chave do servidor não está validada em known_hosts. Abra o PowerShell e conecte uma vez para conferir a impressão digital do servidor; depois tente novamente.\n" + detail);
            if (detail.IndexOf("Permission denied", StringComparison.OrdinalIgnoreCase) >= 0 ||
                detail.IndexOf("publickey", StringComparison.OrdinalIgnoreCase) >= 0)
                return new IOException("A autenticação por chave SSH falhou. Configure sua chave em ~/.ssh/config ou carregue-a no ssh-agent. O OTMapas não armazena senha.\n" + detail);
            if (String.IsNullOrEmpty(detail)) detail = "código de saída " + result.ExitCode;
            return new IOException(name + " falhou: " + detail);
        }

        static string JoinArguments(List<string> arguments)
        {
            var output = new StringBuilder();
            foreach (string argument in arguments)
            {
                if (output.Length != 0) output.Append(' ');
                output.Append(QuoteWindowsArgument(argument));
            }
            return output.ToString();
        }

        internal static string QuoteWindowsArgument(string argument)
        {
            if (argument.Length != 0 && argument.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0) return argument;
            var result = new StringBuilder("\"");
            int slashes = 0;
            foreach (char c in argument)
            {
                if (c == '\\') { slashes++; continue; }
                if (c == '"') { result.Append('\\', slashes * 2 + 1); result.Append('"'); slashes = 0; continue; }
                result.Append('\\', slashes); slashes = 0; result.Append(c);
            }
            result.Append('\\', slashes * 2); result.Append('"');
            return result.ToString();
        }

        static string ShellQuote(string value)
        {
            return "'" + value.Replace("'", "'\"'\"'") + "'";
        }

        static string HashFile(string path)
        {
            using (var stream = File.OpenRead(path))
            using (var sha = SHA256.Create())
            {
                byte[] hash = sha.ComputeHash(stream);
                var result = new StringBuilder(hash.Length * 2);
                foreach (byte value in hash) result.Append(value.ToString("x2"));
                return result.ToString();
            }
        }

        bool TryReadEndpoint(out SshEndpoint endpoint)
        {
            endpoint = null;
            string hostValue = host.Text.Trim();
            string userValue = user.Text.Trim();
            string portValue = port.Text.Trim();
            string pathValue = mapPath.Text.Trim();
            if (!Regex.IsMatch(hostValue, "^[A-Za-z0-9_.:%\\[\\]-]+$") || hostValue.StartsWith("-", StringComparison.Ordinal))
                return InvalidField("Informe um host/IP ou alias SSH válido.");
            if (userValue.Length != 0 && !Regex.IsMatch(userValue, "^[A-Za-z0-9._-]+$")) return InvalidField("Informe um usuário SSH válido.");
            if (portValue.Length != 0)
            {
                int portNumber;
                if (!Int32.TryParse(portValue, out portNumber) || portNumber < 1 || portNumber > 65535)
                    return InvalidField("A porta deve estar entre 1 e 65535, ou vazia para usar ~/.ssh/config.");
            }
            if (!Regex.IsMatch(pathValue, "^/[A-Za-z0-9._/-]+$") ||
                Array.IndexOf(pathValue.Split('/'), "..") >= 0)
                return InvalidField("Use um caminho absoluto Linux com letras, números, ponto, hífen ou barra; não use segmentos '..'.");
            endpoint = new SshEndpoint { Host = hostValue, User = userValue, Port = portValue, MapPath = pathValue };
            return true;
        }

        bool InvalidField(string message)
        {
            MessageBox.Show(this, message, "Dados SSH inválidos", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return false;
        }

        void EnsureOpenSsh()
        {
            if (String.IsNullOrEmpty(sshExe) || String.IsNullOrEmpty(scpExe))
            {
                string directory = FindSshDirectory();
                if (directory == null) throw new FileNotFoundException("Não encontrei ssh.exe e scp.exe. Instale o OpenSSH Client do Windows ou o Git for Windows.");
                sshExe = Path.Combine(directory, "ssh.exe"); scpExe = Path.Combine(directory, "scp.exe");
            }
        }

        string GetSshExe() { EnsureOpenSsh(); return sshExe; }
        string GetScpExe() { EnsureOpenSsh(); return scpExe; }

        static string FindSshDirectory()
        {
            string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            string[] candidates = {
                Path.Combine(windows, "System32", "OpenSSH"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Git", "usr", "bin"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Git", "usr", "bin")
            };
            foreach (string directory in candidates)
                if (File.Exists(Path.Combine(directory, "ssh.exe")) && File.Exists(Path.Combine(directory, "scp.exe")) && File.Exists(Path.Combine(directory, "sftp.exe"))) return directory;
            string path = Environment.GetEnvironmentVariable("PATH") ?? "";
            foreach (string directory in path.Split(Path.PathSeparator))
                if (!String.IsNullOrWhiteSpace(directory) && File.Exists(Path.Combine(directory.Trim(), "ssh.exe")) && File.Exists(Path.Combine(directory.Trim(), "scp.exe")) && File.Exists(Path.Combine(directory.Trim(), "sftp.exe"))) return directory.Trim();
            return null;
        }

        void SetBusy(bool value, string message)
        {
            busy = value;
            test.Enabled = download.Enabled = !value;
            host.Enabled = user.Enabled = port.Enabled = mapPath.Enabled = !value;
            stopped.Enabled = !value;
            publish.Enabled = !value && stopped.Checked && downloadedMap != null;
            progress.Style = value ? ProgressBarStyle.Marquee : ProgressBarStyle.Continuous;
            status.Text = message;
        }

        void ShowFailure(string title, Exception exception)
        {
            status.Text = title + ": " + exception.Message;
            MessageBox.Show(this, exception.Message, title, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        string SettingsFile
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "OTMapas", "ssh-settings.txt"); }
        }

        void SaveSettings(SshEndpoint endpoint)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(SettingsFile));
                File.WriteAllLines(SettingsFile, new[] {
                    Convert.ToBase64String(Encoding.UTF8.GetBytes(endpoint.Host)),
                    Convert.ToBase64String(Encoding.UTF8.GetBytes(endpoint.Port)),
                    Convert.ToBase64String(Encoding.UTF8.GetBytes(endpoint.User)),
                    Convert.ToBase64String(Encoding.UTF8.GetBytes(endpoint.MapPath))
                });
            }
            catch (Exception ex) { status.Text = "Não consegui salvar as configurações no PC: " + ex.Message; }
        }

        void LoadSettings()
        {
            try
            {
                if (!File.Exists(SettingsFile)) return;
                string[] lines = File.ReadAllLines(SettingsFile);
                if (lines.Length < 4) return;
                host.Text = Encoding.UTF8.GetString(Convert.FromBase64String(lines[0]));
                port.Text = Encoding.UTF8.GetString(Convert.FromBase64String(lines[1]));
                user.Text = Encoding.UTF8.GetString(Convert.FromBase64String(lines[2]));
                mapPath.Text = Encoding.UTF8.GetString(Convert.FromBase64String(lines[3]));
            }
            catch { status.Text = "Não foi possível ler as configurações SSH salvas. Verifique os campos."; }
        }
    }
}
