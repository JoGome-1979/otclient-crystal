using System;
using System.IO;
using System.IO.Compression;
using OtmmTool;

class Tests
{
    [STAThread]
    static int Main(string[] args)
    {
        try
        {
            if (args[0] == "otmm") OtmmCodec.Convert(args[1], args[2], args[3] == "compress", null);
            else if (args[0] == "map") MapArchive.Convert(args[1], args[2], args[3] == "compress", null);
            else if (args[0] == "validate") using (var input = File.OpenRead(args[1])) MapArchive.ValidateOtbm(input);
            else if (args[0] == "ssh")
            {
                string command = SshMapTab.BuildPublishCommand("/home/crystal/map's files/world.otbm",
                    "/home/crystal/map's files/.world.otbm.new.id", "/home/crystal/map's files/world.otbm.backup.id",
                    new string('a', 64), new string('b', 64));
                if (!command.Contains("target='/home/crystal/map'\"'\"'s files/world.otbm'")) throw new Exception("Caminho remoto não foi escapado corretamente.");
                if (!command.Contains("gzip -t -- \"$stage\"") || !command.Contains("cp -p -- \"$target\" \"$backup\"") ||
                    !command.Contains("mv -fT -- \"$stage\" \"$target\"") || !command.Contains("sha256sum -- \"$target\""))
                    throw new Exception("Publicação SSH não valida, cria backup e substitui o arquivo atomicamente.");
                if (!command.Contains("[ ! -L \"$target\" ]")) throw new Exception("O app deve recusar substituir um caminho de mapa que seja link simbólico.");
                string quoted = SshMapTab.QuoteWindowsArgument("C:\\maps folder\\world.otbm");
                if (quoted != "\"C:\\maps folder\\world.otbm\"") throw new Exception("Argumento Windows com espaços foi escapado incorretamente.");
            }
            else if (args[0] == "ssh-script")
                Console.WriteLine(SshMapTab.BuildPublishCommand("/home/crystal/map's files/world.otbm", "/home/crystal/map's files/.world.otbm.new.id",
                    "/home/crystal/map's files/world.otbm.backup.id", new string('a', 64), new string('b', 64)));
            else if (args[0] == "ui")
            {
                System.Windows.Forms.Application.EnableVisualStyles();
                System.Windows.Forms.Application.SetCompatibleTextRenderingDefault(false);
                using (var form = new MainWindow())
                {
                    form.Show(); System.Windows.Forms.Application.DoEvents();
                    if (form.Controls.Count != 1) throw new Exception("Janela sem abas.");
                    var tabs = (System.Windows.Forms.TabControl)form.Controls[0];
                    if (tabs.TabPages.Count != 3) throw new Exception("Número incorreto de abas.");
                    tabs.SelectedIndex = 2; System.Windows.Forms.Application.DoEvents();
                    using (var bitmap = new System.Drawing.Bitmap(form.Width, form.Height))
                    {
                        form.DrawToBitmap(bitmap, new System.Drawing.Rectangle(0, 0, form.Width, form.Height));
                        bitmap.Save(args[2]);
                    }
                    form.Close();
                }
            }
            else throw new Exception("Modo inválido.");
            return 0;
        }
        catch (Exception ex) { Console.Error.WriteLine(ex.Message); return 1; }
    }
}
