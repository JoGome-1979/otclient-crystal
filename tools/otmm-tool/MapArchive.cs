using System;
using System.IO;
using System.IO.Compression;

namespace OtmmTool
{
    // CrystalServer stores a single GZIP stream under the original .otbm name.
    public static class MapArchive
    {
        static readonly uint[] CrcTable = MakeCrcTable();

        static uint[] MakeCrcTable()
        {
            var table = new uint[256];
            for (uint i = 0; i < table.Length; i++)
            {
                uint crc = i;
                for (int bit = 0; bit < 8; bit++) crc = (crc & 1) != 0 ? 0xedb88320U ^ (crc >> 1) : crc >> 1;
                table[i] = crc;
            }
            return table;
        }

        public static void ValidateOtbm(Stream stream)
        {
            using (var reader = new BinaryReader(stream, System.Text.Encoding.UTF8, true))
            {
                byte[] identifier = reader.ReadBytes(4);
                if (identifier.Length >= 2 && identifier[0] == 0x1f && identifier[1] == 0x8b)
                    throw new InvalidDataException("Este mapa já está compactado. Use a aba Descompactar para abrir no editor.");
                if (identifier.Length != 4 || (BitConverter.ToUInt32(identifier, 0) != 0 && BitConverter.ToUInt32(identifier, 0) != 0x4d42544f) || reader.ReadByte() != 0xfe)
                    throw new InvalidDataException("O arquivo não possui um cabeçalho OTBM reconhecido pelo editor.");
                // Escaped root header consumed by IOMapOTBM::getVersionInfo in the editor.
                byte[] root = new byte[17];
                for (int i = 0; i < root.Length; i++)
                {
                    byte value = reader.ReadByte();
                    if (value == 0xfd) value = reader.ReadByte();
                    else if (value == 0xfe || value == 0xff) throw new InvalidDataException("Cabeçalho OTBM incompleto.");
                    root[i] = value;
                }
                if (root[0] != 0 || BitConverter.ToUInt16(root, 5) == 0 || BitConverter.ToUInt16(root, 7) == 0)
                    throw new InvalidDataException("Cabeçalho OTBM inválido: tipo raiz ou dimensões do mapa.");
            }
        }

        public static void Convert(string source, string destination, bool compress, Action<int> progress)
        {
            if (String.Equals(Path.GetFullPath(source), Path.GetFullPath(destination), StringComparison.OrdinalIgnoreCase))
                throw new IOException("Escolha outro destino para preservar o arquivo original.");
            bool created = false;
            try
            {
                using (var input = File.OpenRead(source))
                {
                    uint expectedCrc = 0, expectedSize = 0;
                    if (compress) ValidateOtbm(input);
                    else
                    {
                        if (input.Length < 18 || input.ReadByte() != 0x1f || input.ReadByte() != 0x8b)
                            throw new InvalidDataException("Este arquivo não é um mapa compactado em GZIP. Se já abre no editor, use a aba Compactar.");
                        if (input.ReadByte() != 8 || (input.ReadByte() & 0xe0) != 0)
                            throw new InvalidDataException("Cabeçalho GZIP inválido ou não suportado.");
                        input.Position = input.Length - 8;
                        using (var reader = new BinaryReader(input, System.Text.Encoding.UTF8, true))
                        { expectedCrc = reader.ReadUInt32(); expectedSize = reader.ReadUInt32(); }
                    }
                    input.Position = 0;
                    using (var output = new FileStream(destination, FileMode.CreateNew, FileAccess.ReadWrite))
                    {
                        created = true;
                        using (var gzip = compress ? new GZipStream(output, CompressionLevel.Optimal, true)
                            : new GZipStream(input, CompressionMode.Decompress, true))
                        {
                            Stream from = compress ? (Stream)input : gzip;
                            Stream to = compress ? (Stream)gzip : output;
                            byte[] buffer = new byte[81920];
                            long total = 0; uint crc = 0xffffffff; int count, previous = -1;
                            while ((count = from.Read(buffer, 0, buffer.Length)) > 0)
                            {
                                to.Write(buffer, 0, count); total += count;
                                if (!compress) for (int i = 0; i < count; i++) crc = CrcTable[(crc ^ buffer[i]) & 255] ^ (crc >> 8);
                                int percent = (int)Math.Min(99, input.Position * 100 / input.Length);
                                if (percent != previous && progress != null) { progress(percent); previous = percent; }
                            }
                            if (!compress && ((crc ^ 0xffffffff) != expectedCrc || unchecked((uint)total) != expectedSize))
                                throw new InvalidDataException("Mapa GZIP corrompido ou incompleto: CRC32/tamanho não conferem. Selecione um arquivo GZIP de um único mapa.");
                        }
                        if (!compress) { output.Position = 0; ValidateOtbm(output); }
                    }
                }
                if (progress != null) progress(100);
            }
            catch
            {
                if (created) try { File.Delete(destination); } catch (IOException) { } catch (UnauthorizedAccessException) { }
                throw;
            }
        }
    }
}
