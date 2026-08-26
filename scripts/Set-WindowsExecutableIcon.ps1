param(
    [Parameter(Mandatory = $true)]
    [string]$Executable,

    [Parameter(Mandatory = $true)]
    [string]$Icon
)

$ErrorActionPreference = 'Stop'

$executablePath = (Resolve-Path -LiteralPath $Executable).Path
$iconPath = (Resolve-Path -LiteralPath $Icon).Path

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Windows executable resources can only be updated on Windows.'
}

if (-not ('Takween.WindowsIconWriter' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

namespace Takween
{
    public static class WindowsIconWriter
    {
        private const ushort ResourceIcon = 3;
        private const ushort ResourceGroupIcon = 14;

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr BeginUpdateResourceW(
            string fileName,
            [MarshalAs(UnmanagedType.Bool)] bool deleteExistingResources);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UpdateResourceW(
            IntPtr update,
            IntPtr type,
            IntPtr name,
            ushort language,
            byte[] data,
            uint dataSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool EndUpdateResourceW(
            IntPtr update,
            [MarshalAs(UnmanagedType.Bool)] bool discard);

        private sealed class IconImage
        {
            public byte Width;
            public byte Height;
            public byte ColorCount;
            public ushort Planes;
            public ushort BitCount;
            public byte[] Data = Array.Empty<byte>();
        }

        public static void Apply(string executablePath, string iconPath)
        {
            List<IconImage> images = ReadIcon(iconPath);
            IntPtr update = BeginUpdateResourceW(executablePath, false);
            if (update == IntPtr.Zero)
                throw new Win32Exception(Marshal.GetLastWin32Error());

            bool committed = false;
            try
            {
                for (int index = 0; index < images.Count; ++index)
                {
                    IconImage image = images[index];
                    if (!UpdateResourceW(update,
                        (IntPtr)ResourceIcon,
                        (IntPtr)(index + 1),
                        0,
                        image.Data,
                        (uint)image.Data.Length))
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }
                }

                byte[] group = CreateGroup(images);
                if (!UpdateResourceW(update,
                    (IntPtr)ResourceGroupIcon,
                    (IntPtr)1,
                    0,
                    group,
                    (uint)group.Length))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                if (!EndUpdateResourceW(update, false))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                committed = true;
            }
            finally
            {
                if (!committed)
                    EndUpdateResourceW(update, true);
            }
        }

        private static List<IconImage> ReadIcon(string path)
        {
            using (FileStream stream = File.OpenRead(path))
            using (BinaryReader reader = new BinaryReader(stream))
            {
                ushort reserved = reader.ReadUInt16();
                ushort type = reader.ReadUInt16();
                ushort count = reader.ReadUInt16();
                if (reserved != 0 || type != 1 || count == 0)
                    throw new InvalidDataException("The file is not a supported ICO image.");

                var entries = new List<Tuple<IconImage, uint, uint>>(count);
                for (int index = 0; index < count; ++index)
                {
                    var image = new IconImage
                    {
                        Width = reader.ReadByte(),
                        Height = reader.ReadByte(),
                        ColorCount = reader.ReadByte()
                    };
                    reader.ReadByte();
                    image.Planes = reader.ReadUInt16();
                    image.BitCount = reader.ReadUInt16();
                    uint length = reader.ReadUInt32();
                    uint offset = reader.ReadUInt32();
                    entries.Add(Tuple.Create(image, length, offset));
                }

                var result = new List<IconImage>(count);
                foreach (Tuple<IconImage, uint, uint> entry in entries)
                {
                    stream.Position = entry.Item3;
                    entry.Item1.Data = reader.ReadBytes(checked((int)entry.Item2));
                    if (entry.Item1.Data.Length != entry.Item2)
                        throw new EndOfStreamException("The ICO image is truncated.");
                    result.Add(entry.Item1);
                }
                return result;
            }
        }

        private static byte[] CreateGroup(List<IconImage> images)
        {
            using (var stream = new MemoryStream())
            using (var writer = new BinaryWriter(stream))
            {
                writer.Write((ushort)0);
                writer.Write((ushort)1);
                writer.Write((ushort)images.Count);
                for (int index = 0; index < images.Count; ++index)
                {
                    IconImage image = images[index];
                    writer.Write(image.Width);
                    writer.Write(image.Height);
                    writer.Write(image.ColorCount);
                    writer.Write((byte)0);
                    writer.Write(image.Planes);
                    writer.Write(image.BitCount);
                    writer.Write((uint)image.Data.Length);
                    writer.Write((ushort)(index + 1));
                }
                return stream.ToArray();
            }
        }
    }
}
'@
}

[Takween.WindowsIconWriter]::Apply($executablePath, $iconPath)
Write-Output "Embedded icon: $executablePath"
