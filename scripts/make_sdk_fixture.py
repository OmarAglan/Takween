#!/usr/bin/env python3
"""Write baa-sdk-v1 test archives for Takween's SDK store tests.

The archives hold fake SDK files, never a working compiler. Each valid archive
follows docs/BAA_SDK_V1.md in the Baa repository byte for byte; each invalid
one breaks exactly one rule that `تكوين طقم ثبت` must enforce. Every archive
gets a `<name>.sha256` sidecar so a test can tell a rejected archive apart from
a rejected hash.

    python make_sdk_fixture.py --host x86_64-windows --output-dir <dir>
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

HOSTS = ("x86_64-windows", "x86_64-linux")
METADATA = "BAA-SDK.json"


def is_executable(path: str) -> bool:
    return (path.startswith(("bin/", "gcc/bin/", "gcc/libexec/"))
            or path.endswith((".exe", ".dll")))


def sdk_files(version: str, host: str) -> dict[str, bytes]:
    """Fake SDK contents. big.bin spans many deflate blocks and the 32 KiB window."""
    suffix = ".exe" if host == "x86_64-windows" else ""
    seed = hashlib.sha256(version.encode()).digest()
    big = bytearray()
    while len(big) < 300_000:
        seed = hashlib.sha256(seed).digest()
        big += seed[:7] * (1 + seed[7] % 40)
    return {
        f"bin/baa{suffix}": f"fake baa {version}\n".encode(),
        "lib/baa/libbaa_runtime.a": b"!<arch>\n",
        "share/baa/big.bin": bytes(big),
        "share/baa/empty.txt": b"",
        "share/baa/stdlib/baalib.baahd": f"// baa {version}\n".encode(),
        "share/baa/مكتبة/نص عربي.txt": "مرحبا\n".encode(),
    }


def inventory(files: dict[str, bytes]) -> list[dict]:
    return [
        {
            "path": path,
            "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "executable": is_executable(path),
        }
        for path, data in sorted(files.items(), key=lambda item: item[0].encode())
    ]


def canonical_metadata(version: str, host: str, entries: list[dict]) -> bytes:
    head = {
        "schema_version": "baa-sdk-v1",
        "name": "baa-sdk",
        "version": version,
        "host": host,
        "targets": [host],
        "components": {
            "compiler": {"path": "bin/baa", "version": version, "revision": None},
            "linker": {"kind": "gcc", "bundled": False, "path": "gcc"},
        },
    }
    text = json.dumps(head, ensure_ascii=False, indent=2)
    lines = ["    " + json.dumps(entry, ensure_ascii=False) for entry in entries]
    return (text[:-2] + ',\n  "files": [\n' + ",\n".join(lines) + "\n  ]\n}\n").encode()


def octal(value: int, width: int) -> bytes:
    return f"{value:0{width - 1}o}".encode() + b"\0"


def tar_header(name: str, size: int, mode: int, typeflag: bytes = b"0",
               linkname: str = "", bad_checksum: bool = False) -> bytes:
    raw = name.encode()
    prefix = b""
    if len(raw) > 100:
        cut = raw.rindex(b"/", 0, 156)
        prefix, raw = raw[:cut], raw[cut + 1:]
    header = bytearray(512)
    header[0:len(raw)] = raw
    header[100:108] = octal(mode, 8)
    header[108:116] = octal(0, 8)
    header[116:124] = octal(0, 8)
    header[124:136] = octal(size, 12)
    header[136:148] = octal(0, 12)
    header[148:156] = b" " * 8
    header[156:157] = typeflag
    header[157:157 + len(linkname.encode())] = linkname.encode()
    header[257:265] = b"ustar\x0000"
    header[345:345 + len(prefix)] = prefix
    checksum = sum(header) + (1 if bad_checksum else 0)
    header[148:156] = f"{checksum:06o}".encode() + b"\0 "
    return bytes(header)


def tar_entry(name: str, data: bytes, mode: int, **header) -> bytes:
    padding = (512 - len(data) % 512) % 512
    return tar_header(name, len(data), mode, **header) + data + b"\0" * padding


def tar_bytes(top: str, metadata: bytes, files: dict[str, bytes],
              entries: list[dict]) -> list[bytes]:
    parts = [tar_entry(f"{top}/{METADATA}", metadata, 0o644)]
    for entry in entries:
        mode = 0o755 if entry["executable"] else 0o644
        parts.append(tar_entry(f"{top}/{entry['path']}", files[entry["path"]], mode))
    return parts


def end_blocks() -> bytes:
    return b"\0" * 10240


def gzip_bytes(payload: bytes, mode: str = "dynamic", flags: int = 0) -> bytes:
    if mode == "stored":
        compressor = zlib.compressobj(0, zlib.DEFLATED, -15)
    elif mode == "fixed":
        compressor = zlib.compressobj(9, zlib.DEFLATED, -15, 9, zlib.Z_FIXED)
    else:
        compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    body = compressor.compress(payload) + compressor.flush()
    header = bytes([31, 139, 8, flags, 0, 0, 0, 0, 2, 255])
    if flags & 8:
        header += b"name\0"
    trailer = struct.pack("<II", zlib.crc32(payload) & 0xFFFFFFFF, len(payload) & 0xFFFFFFFF)
    return header + body + trailer


def write(out: Path, name: str, data: bytes) -> None:
    path = out / name
    path.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    (out / f"{name}.sha256").write_text(f"{digest}  {name}\n", encoding="utf-8", newline="\n")


def valid_parts(version: str, host: str):
    files = sdk_files(version, host)
    entries = inventory(files)
    top = f"baa-sdk-{version}-{host}"
    return top, files, entries, canonical_metadata(version, host, entries)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", required=True, choices=HOSTS)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    host = args.host
    other = HOSTS[1] if host == HOSTS[0] else HOSTS[0]
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)

    # Valid archives: one per deflate block kind.
    for version, mode in (("0.6.0", "dynamic"), ("0.7.0", "fixed"), ("0.8.0", "stored")):
        top, files, entries, metadata = valid_parts(version, host)
        payload = b"".join(tar_bytes(top, metadata, files, entries)) + end_blocks()
        write(out, f"valid-{version}.tar.gz", gzip_bytes(payload, mode))
    # Same SDK identity as valid-0.6.0, different archive bytes.
    top, files, entries, metadata = valid_parts("0.6.0", host)
    payload = b"".join(tar_bytes(top, metadata, files, entries)) + end_blocks()
    write(out, "repacked-0.6.0.tar.gz", gzip_bytes(payload, "stored"))

    bad: dict[str, bytes] = {}

    def from_parts(version: str, edit) -> bytes:
        top, files, entries, metadata = valid_parts(version, host)
        parts = tar_bytes(top, metadata, files, entries)
        return edit(top, files, entries, metadata, parts)

    def joined(parts: list[bytes]) -> bytes:
        return b"".join(parts) + end_blocks()

    def with_inventory(version: str, files: dict[str, bytes], top: str | None = None,
                       meta_version: str | None = None, meta_host: str | None = None,
                       entries: list[dict] | None = None) -> bytes:
        entries = entries if entries is not None else inventory(files)
        metadata = canonical_metadata(meta_version or version, meta_host or host, entries)
        top = top or f"baa-sdk-{version}-{host}"
        return joined(tar_bytes(top, metadata, files, entries))

    base = sdk_files("0.9.0", host)

    for path in ("../evil.txt", "share/../evil.txt", "share/./x.txt", "share//x.txt",
                 "share/CON", "share/aux.txt", "share/com1", "share/x.", "share/x ",
                 "share/a:b", "share/a\\b", "share/x?", ".تكوين-طقم-v1", "BAA-SDK.json"):
        files = dict(base)
        files[path] = b"x"
        safe = hashlib.sha256(path.encode()).hexdigest()[:8]
        bad[f"path-{safe}"] = with_inventory("0.9.0", files)

    bad["extra-entry"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts + [tar_entry(f"{top}/zzz.txt", b"extra", 0o644)]))
    bad["missing-entry"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(parts[:-1]))
    bad["symlink-entry"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[:2] + [tar_header(f"{top}/lib/baa/libbaa_runtime.a", 0, 0o644, b"2",
                                linkname="/etc/passwd")] + parts[3:]))
    bad["directory-entry"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[:1] + [tar_header(f"{top}/bin/", 0, 0o755, b"5")] + parts[1:]))
    bad["pax-entry"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[:1] + [tar_entry(f"{top}/pax", b"18 path=/etc/evil\n", 0o644, typeflag=b"x")]
        + parts[1:]))
    bad["wrong-mode"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[:2] + [tar_entry(f"{top}/lib/baa/libbaa_runtime.a",
                               f["lib/baa/libbaa_runtime.a"], 0o755)] + parts[3:]))
    bad["setuid-mode"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[:1] + [tar_entry(f"{top}/{e[0]['path']}", f[e[0]["path"]], 0o4755)] + parts[2:]))
    bad["bad-checksum"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[:2] + [tar_entry(f"{top}/lib/baa/libbaa_runtime.a",
                               f["lib/baa/libbaa_runtime.a"], 0o644, bad_checksum=True)]
        + parts[3:]))
    bad["nonzero-padding"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[:2] + [parts[2][:-1] + b"\x01"] + parts[3:]))
    bad["data-after-end"] = from_parts("0.9.0", lambda top, f, e, m, parts: b"".join(parts)
                                       + b"\0" * 1024 + b"\x01" + b"\0" * 511)
    bad["no-end-blocks"] = from_parts("0.9.0", lambda top, f, e, m, parts: b"".join(parts))
    bad["metadata-not-first"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        parts[1:2] + parts[:1] + parts[2:]))
    bad["noncanonical-json"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        [tar_entry(f"{top}/{METADATA}", (json.dumps(
            {**json.loads(m), "files": e}, indent=2) + "\n").encode(), 0o644)] + parts[1:]))
    bad["host-mismatch"] = with_inventory("0.9.0", base, top=f"baa-sdk-0.9.0-{other}",
                                          meta_host=other)
    bad["top-mismatch"] = with_inventory("0.9.0", base, top=f"baa-sdk-0.9.1-{host}")
    bad["version-invalid"] = with_inventory("0.9", base, top=f"baa-sdk-0.9-{host}")
    hashed = inventory(base)
    hashed[0] = {**hashed[0], "sha256": "0" * 64}
    bad["hash-mismatch"] = with_inventory("0.9.0", base, entries=hashed)
    sized = inventory(base)
    sized[0] = {**sized[0], "size": sized[0]["size"] + 1}
    bad["size-mismatch"] = with_inventory("0.9.0", base, entries=sized)
    unsorted = inventory(base)
    unsorted[0], unsorted[1] = unsorted[1], unsorted[0]
    bad["unsorted-inventory"] = with_inventory("0.9.0", base, entries=unsorted)
    def flip_executable(top, f, e, m, parts):
        flipped = [dict(entry) for entry in e]
        flipped[0]["executable"] = not flipped[0]["executable"]
        metadata = canonical_metadata("0.9.0", host, flipped)
        return joined([tar_entry(f"{top}/{METADATA}", metadata, 0o644)] + parts[1:])

    bad["executable-mismatch"] = from_parts("0.9.0", flip_executable)
    bad["invalid-utf8-metadata"] = from_parts("0.9.0", lambda top, f, e, m, parts: joined(
        [tar_entry(f"{top}/{METADATA}", m.replace(b"baa-sdk\"", b"baa-sdk\xff\""), 0o644)]
        + parts[1:]))

    for name, payload in bad.items():
        write(out, f"bad-{name}.tar.gz", gzip_bytes(payload))

    valid = gzip_bytes(with_inventory("0.9.0", base))
    write(out, "bad-gzip-truncated.tar.gz", valid[:-100])
    write(out, "bad-gzip-crc.tar.gz", valid[:-8] + bytes([valid[-8] ^ 1]) + valid[-7:])
    write(out, "bad-gzip-size.tar.gz", valid[:-4] + bytes([valid[-4] ^ 1]) + valid[-3:])
    write(out, "bad-gzip-trailing.tar.gz", valid + b"\0")
    write(out, "bad-gzip-member.tar.gz", valid + valid)
    write(out, "bad-gzip-fname.tar.gz", gzip_bytes(with_inventory("0.9.0", base), flags=8))
    write(out, "bad-gzip-corrupt.tar.gz", valid[:40] + bytes([valid[40] ^ 255]) + valid[41:])
    write(out, "bad-not-gzip.tar.gz", with_inventory("0.9.0", base))
    return 0


if __name__ == "__main__":
    sys.exit(main())
