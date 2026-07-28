#!/usr/bin/env python3
"""Install only Godot's Windows x86_64 export-template files via HTTP ranges."""

from __future__ import annotations

import argparse
import binascii
import os
from pathlib import Path
import struct
import urllib.request
import zlib


EOCD_SIGNATURE = b"PK\x05\x06"
CENTRAL_SIGNATURE = b"PK\x01\x02"
LOCAL_SIGNATURE = b"PK\x03\x04"
TARGET_FILES = (
    "windows_debug_x86_64.exe",
    "windows_debug_x86_64_console.exe",
    "windows_release_x86_64.exe",
    "windows_release_x86_64_console.exe",
    "icudt_godot.dat",
)


class RangeArchive:
    def __init__(self, url: str) -> None:
        request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "Godot/4.7.1"})
        with urllib.request.urlopen(request, timeout=60) as response:
            self.url = response.geturl()
            self.length = int(response.headers["Content-Length"])

    def read(self, start: int, end: int) -> bytes:
        if start < 0 or end < start or end >= self.length:
            raise ValueError(f"invalid byte range {start}-{end} for {self.length}")
        request = urllib.request.Request(
            self.url,
            headers={"Range": f"bytes={start}-{end}", "User-Agent": "Godot/4.7.1"},
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
            if response.status == 200 and len(data) == self.length:
                return data[start : end + 1]
            expected = end - start + 1
            if response.status != 206 or len(data) != expected:
                raise RuntimeError(
                    f"range {start}-{end} returned HTTP {response.status} and {len(data)} bytes"
                )
            return data

    def entries(self) -> dict[str, tuple[int, int, int, int, int]]:
        tail_size = min(self.length, 1 << 20)
        tail_start = self.length - tail_size
        tail = self.read(tail_start, self.length - 1)
        eocd_pos = tail.rfind(EOCD_SIGNATURE)
        if eocd_pos < 0:
            raise RuntimeError("ZIP end-of-central-directory record was not found")
        (
            _signature,
            _disk,
            _central_disk,
            _disk_entries,
            total_entries,
            central_size,
            central_offset,
            _comment_length,
        ) = struct.unpack_from("<4s4H2LH", tail, eocd_pos)
        central = self.read(central_offset, central_offset + central_size - 1)
        result: dict[str, tuple[int, int, int, int, int]] = {}
        cursor = 0
        for _ in range(total_entries):
            if central[cursor : cursor + 4] != CENTRAL_SIGNATURE:
                raise RuntimeError(f"invalid central-directory record at {cursor}")
            fields = struct.unpack_from("<4s6H3L5H2L", central, cursor)
            method = fields[4]
            crc32 = fields[7]
            compressed_size = fields[8]
            uncompressed_size = fields[9]
            name_length = fields[10]
            extra_length = fields[11]
            comment_length = fields[12]
            local_offset = fields[16]
            name_start = cursor + 46
            name = central[name_start : name_start + name_length].decode("utf-8")
            result[name] = (
                local_offset,
                method,
                crc32,
                compressed_size,
                uncompressed_size,
            )
            cursor += 46 + name_length + extra_length + comment_length
        return result

    def extract(self, entry: tuple[int, int, int, int, int]) -> bytes:
        local_offset, method, expected_crc, compressed_size, uncompressed_size = entry
        header = self.read(local_offset, local_offset + 29)
        if header[:4] != LOCAL_SIGNATURE:
            raise RuntimeError(f"invalid local ZIP header at {local_offset}")
        fields = struct.unpack("<4s5H3L2H", header)
        name_length = fields[9]
        extra_length = fields[10]
        data_start = local_offset + 30 + name_length + extra_length
        compressed = self.read(data_start, data_start + compressed_size - 1)
        if method == 0:
            data = compressed
        elif method == 8:
            data = zlib.decompress(compressed, -zlib.MAX_WBITS)
        else:
            raise RuntimeError(f"unsupported ZIP compression method {method}")
        if len(data) != uncompressed_size:
            raise RuntimeError(f"size mismatch: expected {uncompressed_size}, got {len(data)}")
        actual_crc = binascii.crc32(data) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise RuntimeError(f"CRC mismatch: expected {expected_crc:08x}, got {actual_crc:08x}")
        return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="4.7.1.stable")
    parser.add_argument(
        "--url",
        default=(
            "https://godot-releases.nbg1.your-objectstorage.com/4.7.1-stable/"
            "Godot_v4.7.1-stable_export_templates.tpz"
        ),
    )
    args = parser.parse_args()

    app_data = os.environ.get("APPDATA")
    if not app_data:
        raise RuntimeError("APPDATA is not defined")
    destination = Path(app_data) / "Godot" / "export_templates" / args.version
    destination.mkdir(parents=True, exist_ok=True)

    archive = RangeArchive(args.url)
    entries = archive.entries()
    for filename in TARGET_FILES:
        archive_name = f"templates/{filename}"
        if archive_name not in entries:
            raise RuntimeError(f"{archive_name} is missing from the official archive")
        data = archive.extract(entries[archive_name])
        temporary = destination / f"{filename}.tmp"
        target = destination / filename
        temporary.write_bytes(data)
        os.replace(temporary, target)
        print(f"installed {filename}: {len(data)} bytes")
    (destination / "version.txt").write_text(args.version + "\n", encoding="utf-8")
    print(f"installed into {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
