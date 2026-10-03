using System;
using System.Drawing;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace OtmmTool
{
    internal static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainWindow());
        }
    }

    public class MainWindow : Form
    {
        public MainWindow()
        {
            Text = "OT Mapas — Compactar e descompactar";
            Size = new Size(850, 450); MinimumSize = new Size(700, 420);
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI", 10);
            var tabs = new TabControl { Dock = DockStyle.Fill, Padding = new Point(20, 10) };
            var decompress = new ConversionTab(false);
            var compress = new ConversionTab(true);
            tabs.TabPages.Add(decompress);
            tabs.TabPages.Add(compress);
            var server = new SshMapTab(decompress, compress, delegate { tabs.SelectedTab = decompress; });
            tabs.TabPages.Add(server);
            Controls.Add(tabs);
            FormClosing += delegate(object sender, FormClosingEventArgs e)
            {
                foreach (TabPage page in tabs.TabPages)
                {
                    ConversionTab tab = page as ConversionTab;
                    if (tab != null && tab.Busy) { e.Cancel = true; MessageBox.Show(this, "Aguarde a operação terminar antes de fechar."); return; }
                }
                if (server.Busy) { e.Cancel = true; MessageBox.Show(this, "Aguarde a operação SSH terminar antes de fechar."); return; }
                foreach (TabPage page in tabs.TabPages)
                {
                    ConversionTab tab = page as ConversionTab;
                    if (tab != null) tab.Cleanup();
                }
            };
        }
    }

    public class ConversionTab : TabPage
    {
        readonly bool compress;
        readonly TextBox path = new TextBox { ReadOnly = true, Dock = DockStyle.Fill };
        readonly Button open = new Button { Text = "1. Abrir arquivo…", AutoSize = true };
        readonly Button run = new Button { AutoSize = true, Enabled = false };
        readonly Button save = new Button { Text = "3. Salvar como…", AutoSize = true, Enabled = false };
        readonly Button editor = new Button { Text = "Abrir no editor…", AutoSize = true, Enabled = false, Visible = false };
        readonly Label status = new Label { Dock = DockStyle.Fill, AutoSize = true, Text = "Selecione um arquivo para começar." };
        readonly ProgressBar progress = new ProgressBar { Dock = DockStyle.Fill };
        string result;
        string savedMap;
        bool editorNeedsRestart;
        public bool Busy { get; private set; }

        public void SelectFile(string fileName)
        {
            if (Busy) throw new InvalidOperationException("Aguarde a conversão terminar antes de trocar o arquivo.");
            Cleanup(); savedMap = null; editor.Enabled = false; path.Text = fileName;
            run.Enabled = true; save.Enabled = false; progress.Value = 0;
            status.Text = "Mapa recebido. Clique em Descompactar para abrir no editor.";
        }

        public ConversionTab(bool compress)
        {
            this.compress = compress;
            Text = compress ? "Compactar" : "Descompactar";
            run.Text = compress ? "2. Compactar" : "2. Descompactar";
            Padding = new Padding(22); BackColor = Color.White;
            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5 };
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 72));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 55));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            layout.Controls.Add(new Label { Dock = DockStyle.Fill, Text = compress
                ? "Depois de editar: compacte o mapa para o servidor\nAbra o .otbm salvo no editor. O resultado GZIP continua com a extensão .otbm."
                : "Prepare o mapa do servidor para abrir no editor\nDescompacte o .otbm GZIP e salve uma cópia OTBM para edição." }, 0, 0);
            layout.Controls.Add(path, 0, 1);
            var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill };
            editor.Visible = !compress;
            buttons.Controls.AddRange(new Control[] { open, run, save, editor }); layout.Controls.Add(buttons, 0, 2);
            layout.Controls.Add(progress, 0, 3); layout.Controls.Add(status, 0, 4); Controls.Add(layout);
            open.Click += Open; run.Click += Run; save.Click += Save; editor.Click += OpenEditor;
        }

        public void Cleanup()
        {
            if (result == null) return;
            try { File.Delete(result); } catch (IOException) { } catch (UnauthorizedAccessException) { }
            result = null;
        }

        void Open(object sender, EventArgs e)
        {
            using (var dialog = new OpenFileDialog())
            {
                string toolFolder = GetBundledMapToolFolder();
                string expectedInput = toolFolder == null ? null : Path.Combine(toolFolder, compress ? "descompactado" : "");
                dialog.InitialDirectory = !String.IsNullOrEmpty(expectedInput) && Directory.Exists(expectedInput)
                    ? expectedInput : Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                dialog.Filter = compress ? "Mapa OTBM salvo pelo editor (*.otbm)|*.otbm|Todos os arquivos (*.*)|*.*"
                    : "Mapa GZIP do servidor (*.otbm;*.otbm.gz)|*.otbm;*.otbm.gz|Todos os arquivos (*.*)|*.*";
                dialog.Title = "Selecione o mapa";
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                Cleanup(); savedMap = null; editor.Enabled = false; path.Text = dialog.FileName; run.Enabled = true; save.Enabled = false;
                progress.Value = 0; status.Text = "Arquivo carregado. Clique em " + (compress ? "Compactar." : "Descompactar.");
            }
        }

        async void Run(object sender, EventArgs e)
        {
            Cleanup(); savedMap = null; editor.Enabled = false; Busy = true; open.Enabled = run.Enabled = save.Enabled = false;
            progress.Value = 0; progress.Style = ProgressBarStyle.Continuous;
            status.Text = "Processando mapa…";
            string source = path.Text;
            result = Path.Combine(Path.GetTempPath(), "otmm-" + Guid.NewGuid().ToString("N") + ".tmp");
            var reporter = new Progress<int>(delegate(int value) { progress.Value = value; });
            try
            {
                await Task.Run(delegate { MapArchive.Convert(source, result, compress, ((IProgress<int>)reporter).Report); });
                status.Text = String.Format("Concluído. Resultado: {0:N0} bytes.\nClique em Salvar como para escolher o destino.", new FileInfo(result).Length);
                save.Enabled = true;
            }
            catch (Exception ex) { Cleanup(); status.Text = "Falha: " + ex.Message; MessageBox.Show(this, ex.Message, "Não foi possível converter", MessageBoxButtons.OK, MessageBoxIcon.Error); }
            finally { Busy = false; open.Enabled = run.Enabled = true; }
        }

        async void Save(object sender, EventArgs e)
        {
            using (var dialog = new SaveFileDialog())
            {
                string toolFolder = GetBundledMapToolFolder();
                string expectedOutput = toolFolder == null ? null : Path.Combine(toolFolder, compress ? "compactado" : "descompactado");
                dialog.InitialDirectory = !String.IsNullOrEmpty(expectedOutput) && Directory.Exists(expectedOutput)
                    ? expectedOutput : Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                dialog.Filter = compress ? "Mapa GZIP para o servidor (*.otbm)|*.otbm" : "Mapa OTBM para o editor (*.otbm)|*.otbm";
                dialog.DefaultExt = "otbm";
                string name = Path.GetFileName(path.Text);
                dialog.FileName = name.EndsWith(".gz", StringComparison.OrdinalIgnoreCase) ? name.Substring(0, name.Length - 3) : name;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                if (String.Equals(Path.GetFullPath(path.Text), Path.GetFullPath(dialog.FileName), StringComparison.OrdinalIgnoreCase))
                { MessageBox.Show(this, "Escolha outro nome para preservar o arquivo original."); return; }
                Busy = true; editor.Enabled = false; open.Enabled = run.Enabled = save.Enabled = false;
                progress.Style = ProgressBarStyle.Marquee;
                string target = dialog.FileName;
                string staging = Path.Combine(Path.GetDirectoryName(target), ".otmm-" + Guid.NewGuid().ToString("N") + ".tmp");
                string backup = null;
                try
                {
                    await Task.Run(delegate
                    {
                        try
                        {
                            File.Copy(result, staging, false);
                            if (File.Exists(target))
                            {
                                string targetDirectory = Path.GetDirectoryName(target);
                                string backupRoot = String.Equals(targetDirectory, expectedOutput, StringComparison.OrdinalIgnoreCase)
                                    ? Path.Combine(toolFolder, "backups") : Path.Combine(targetDirectory, "backups");
                                string backupDirectory = Path.Combine(backupRoot, DateTime.Now.ToString("yyyyMMdd-HHmmss-fff"),
                                    compress ? "compactado" : "descompactado");
                                Directory.CreateDirectory(backupDirectory);
                                backup = Path.Combine(backupDirectory, Path.GetFileName(target));
                                File.Replace(staging, target, backup);
                            }
                            else File.Move(staging, target);
                        }
                        finally { if (File.Exists(staging)) File.Delete(staging); }
                    });
                    status.Text = "Arquivo salvo com sucesso:\n" + target +
                        (backup == null ? "" : "\nCópia anterior: " + backup);
                    if (!compress) savedMap = target;
                }
                catch (Exception ex) { status.Text = "Não foi possível salvar. O resultado continua disponível."; MessageBox.Show(this, ex.Message, "Erro ao salvar", MessageBoxButtons.OK, MessageBoxIcon.Error); }
                finally { Busy = false; editor.Enabled = savedMap != null; open.Enabled = run.Enabled = save.Enabled = true; progress.Style = ProgressBarStyle.Continuous; }
            }
        }

        void OpenEditor(object sender, EventArgs e)
        {
            using (var dialog = new OpenFileDialog())
            {
                dialog.Title = "Selecione o executável do seu editor de mapas";
                dialog.Filter = "Editor de mapas (*.exe)|*.exe";
                dialog.InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                string localEditor = Path.Combine(dialog.InitialDirectory, "map-editor-v4.0-windows", "canary-map-editor.exe");
                if (File.Exists(localEditor)) dialog.FileName = localEditor;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                try
                {
                    bool canaryEditor = String.Equals(Path.GetFileName(dialog.FileName), "canary-map-editor.exe", StringComparison.OrdinalIgnoreCase);
                    if (canaryEditor && !ConfigureCanaryAssets()) return;
                    if (canaryEditor && editorNeedsRestart && IsCanaryEditorRunning())
                    {
                        MessageBox.Show(this,
                            "Os assets foram configurados, mas o editor que já está aberto ainda usa as configurações antigas. Feche essa janela do Canary Map Editor e clique em Abrir no editor novamente.",
                            "Reinicie o editor", MessageBoxButtons.OK, MessageBoxIcon.Information);
                        return;
                    }
                    if (canaryEditor && editorNeedsRestart)
                        MessageBox.Show(this, "Configurei os assets do cliente. O Canary Map Editor será aberto com esse caminho.",
                            "Editor configurado", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    Process.Start(new ProcessStartInfo(dialog.FileName, "\"" + savedMap + "\"") {
                        WorkingDirectory = Path.GetDirectoryName(dialog.FileName), UseShellExecute = true });
                    if (canaryEditor) editorNeedsRestart = false;
                }
                catch (Exception ex) { MessageBox.Show(this, ex.Message, "Não foi possível abrir o editor", MessageBoxButtons.OK, MessageBoxIcon.Error); }
            }
        }

        bool ConfigureCanaryAssets()
        {
            const string registryPath = @"Software\OpenTibiaBR\Canary Map Editor\Version";
            string currentConfig = null;
            using (RegistryKey current = Registry.CurrentUser.OpenSubKey(registryPath))
                if (current != null) currentConfig = current.GetValue("ASSETS_DATA_DIRS") as string;

            Match savedPath = Regex.Match(currentConfig ?? "", "\"path\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
            if (savedPath.Success)
            {
                string existing = Regex.Unescape(savedPath.Groups[1].Value);
                if (IsCanaryClientFolder(existing)) return true;
            }

            string clientPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Tibia", "packages", "Tibia");
            if (!IsCanaryClientFolder(clientPath))
            {
                using (var picker = new FolderBrowserDialog())
                {
                    picker.Description = "Selecione a pasta do cliente que contém package.json e assets\\catalog-content.json.";
                    picker.ShowNewFolderButton = false;
                    picker.RootFolder = Environment.SpecialFolder.MyComputer;
                    if (picker.ShowDialog(this) != DialogResult.OK) return false;
                    clientPath = picker.SelectedPath;
                }
            }

            if (!IsCanaryClientFolder(clientPath))
            {
                MessageBox.Show(this,
                    "Essa pasta não contém package.json e assets\\catalog-content.json. Selecione a pasta do cliente Tibia, não a pasta do editor nem a pasta assets.",
                    "Assets do editor não encontrados", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return false;
            }

            Match version = Regex.Match(File.ReadAllText(Path.Combine(clientPath, "package.json")),
                "\"version\"\\s*:\\s*\"([^\"]+)\"");
            if (!version.Success)
            {
                MessageBox.Show(this, "Não encontrei a versão do cliente em package.json.", "Assets do editor inválidos",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return false;
            }

            string json = "[{\"id\":\"" + EscapeJson(version.Groups[1].Value) + "\",\"path\":\"" + EscapeJson(clientPath) + "\"}]";
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(registryPath))
                key.SetValue("ASSETS_DATA_DIRS", json, RegistryValueKind.String);
            editorNeedsRestart = true;
            return true;
        }

        static bool IsCanaryEditorRunning()
        {
            Process[] processes = Process.GetProcessesByName("canary-map-editor");
            bool running = processes.Length != 0;
            foreach (Process process in processes) process.Dispose();
            return running;
        }

        static bool IsCanaryClientFolder(string path)
        {
            return !String.IsNullOrWhiteSpace(path) && Directory.Exists(path) &&
                File.Exists(Path.Combine(path, "package.json")) &&
                File.Exists(Path.Combine(path, "assets", "catalog-content.json"));
        }

        static string EscapeJson(string value)
        {
            return value.Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        static string GetBundledMapToolFolder()
        {
            string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                "map-editor-v4.0-windows", "ferramentas-mapa-otbm");
            return Directory.Exists(folder) ? folder : null;
        }
    }
}
