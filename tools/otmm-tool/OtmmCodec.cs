using System;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace OtmmTool
{
    public static class OtmmCodec
    {
        public const int BlockSize = 64 * 64 * 3;
        static readonly byte[] RawMagic = Encoding.ASCII.GetBytes("OTMMRAW1");

        static byte[] Read(BinaryReader reader, int count)
        {
            byte[] data = reader.ReadBytes(count);
            if (data.Length != count) throw new InvalidDataException("Arquivo truncado ou incompleto.");
            return data;
        }

        static uint Adler(byte[] data)
        {
            uint a = 1, b = 0;
            foreach (byte value in data) { a = (a + value) % 65521; b = (b + a) % 65521; }
            return (b << 16) | a;
        }

        static byte[] Inflate(byte[] data)
        {
            if (data.Length < 6 || (data[0] & 15) != 8 || (data[0] >> 4) > 7 ||
                ((data[0] << 8) + data[1]) % 31 != 0 || (data[1] & 32) != 0)
                throw new InvalidDataException("Bloco zlib inválido ou não suportado.");
            byte[] raw = new byte[BlockSize];
            using (var input = new MemoryStream(data, 2, data.Length - 6))
            using (var stream = new DeflateStream(input, CompressionMode.Decompress))
            {
                int offset = 0, count;
                while (offset < raw.Length && (count = stream.Read(raw, offset, raw.Length - offset)) > 0) offset += count;
                if (offset != raw.Length || stream.ReadByte() != -1)
                    throw new InvalidDataException("Tamanho de bloco incompatível com este OTClient.");
            }
            int end = data.Length - 4;
            uint expected = ((uint)data[end] << 24) | ((uint)data[end + 1] << 16) | ((uint)data[end + 2] << 8) | data[end + 3];
            if (Adler(raw) != expected) throw new InvalidDataException("Bloco corrompido: checksum zlib incorreto.");
            return raw;
        }

        static byte[] Deflate(byte[] raw)
        {
            using (var output = new MemoryStream())
            {
                output.WriteByte(0x78); output.WriteByte(0x9c);
                using (var stream = new DeflateStream(output, CompressionLevel.Optimal, true)) stream.Write(raw, 0, raw.Length);
                uint checksum = Adler(raw);
                for (int shift = 24; shift >= 0; shift -= 8) output.WriteByte((byte)(checksum >> shift));
                return output.ToArray();
            }
        }

        // RAW1 wraps the original OTMM header and records, replacing zlib payloads with raw tiles.
        public static int Convert(string source, string destination, bool compress, Action<int> progress)
        {
            if (String.Equals(Path.GetFullPath(source), Path.GetFullPath(destination), StringComparison.OrdinalIgnoreCase))
                throw new IOException("A saída deve ser diferente do arquivo de origem.");
            using (var input = File.OpenRead(source))
            using (var reader = new BinaryReader(input))
            using (var output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write))
            using (var writer = new BinaryWriter(output))
            {
                if (compress)
                {
                    if (Encoding.ASCII.GetString(Read(reader, 8)) != "OTMMRAW1")
                        throw new InvalidDataException("Selecione um .otmm.raw gerado por este aplicativo.");
                }
                else writer.Write(RawMagic);
                byte[] prefix = Read(reader, 14);
                ushort start = BitConverter.ToUInt16(prefix, 4);
                ushort descriptionLength = BitConverter.ToUInt16(prefix, 12);
                if (BitConverter.ToUInt32(prefix, 0) != 0x4D4D544F || BitConverter.ToUInt16(prefix, 6) != 1)
                    throw new InvalidDataException("Formato inválido. É necessário um minimapa OTMM versão 1.");
                if (BitConverter.ToUInt32(prefix, 8) != 0 || start < 14 + descriptionLength)
                    throw new InvalidDataException("Cabeçalho OTMM inválido ou flags não suportadas.");
                writer.Write(prefix); writer.Write(Read(reader, start - 14));
                int blocks = 0, lastPercent = -1;
                while (true)
                {
                    byte[] position = Read(reader, 5);
                    ushort x = BitConverter.ToUInt16(position, 0), y = BitConverter.ToUInt16(position, 2);
                    byte z = position[4];
                    writer.Write(position);
                    if (x == 65535 && y == 65535 && z == 255)
                    {
                        if (input.Position != input.Length) throw new InvalidDataException("Dados inesperados após o fim do minimapa.");
                        break;
                    }
                    if (x % 64 != 0 || y % 64 != 0 || z > 15)
                        throw new InvalidDataException("Coordenadas de bloco incompatíveis (andares 0–15).");
                    ushort length = reader.ReadUInt16();
                    if (compress && length != BlockSize) throw new InvalidDataException("Bloco RAW com tamanho inválido.");
                    byte[] data = Read(reader, length);
                    byte[] converted = compress ? Deflate(data) : Inflate(data);
                    writer.Write(checked((ushort)converted.Length)); writer.Write(converted);
                    blocks++;
                    int percent = (int)(input.Position * 100 / input.Length);
                    if (progress != null && percent != lastPercent) { progress(percent); lastPercent = percent; }
                }
                if (progress != null) progress(100);
                return blocks;
            }
        }
    }
}
