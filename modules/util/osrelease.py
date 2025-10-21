#!/usr/bin/env python3
import os
import platform
import re
import shutil
import subprocess
from typing import Dict

def run(cmd):
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
        return out.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

def parse_major(ver: str) -> str:
    """Return the leading integer portion of a version string (before the first dot)."""
    if not ver:
        return ""
    m = re.search(r"\d+", ver)
    return m.group(0) if m else ""

def read_os_release() -> Dict[str, str]:
    """Parse /etc/os-release into a dict. Returns {} if not present."""
    path = "/etc/os-release"
    data: Dict[str, str] = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                # Strip surrounding quotes if present
                v = v.strip().strip('"').strip("'")
                data[k] = v
    return data

def linux_os_version() -> str:
    osr = read_os_release()

    if not osr:
        # Fallbacks if /etc/os-release is missing (rare)
        rh_path = "/etc/redhat-release"
        if os.path.exists(rh_path):
            txt = open(rh_path, encoding="utf-8").read().strip()
            low = txt.lower()
            maj = parse_major(txt)
            if low.startswith("fedora"):
                return f"fedora{maj or ''}".rstrip()
            if "almalinux" in low:
                return f"almalinux{maj or ''}".rstrip()
            if low.startswith("red hat enterprise"):
                return f"rhel{maj or ''}".rstrip()
            base = (txt.split() or ["linux"])[0].lower()
            return f"{base}{maj}" if maj else base
        raise ValueError("Unsupported linux version: missing /etc/os-release")

    id_ = osr.get("ID", "").lower()
    ver = osr.get("VERSION_ID", "")
    maj = parse_major(ver)

    # Normalize well-known distros
    if id_ in {"ubuntu", "debian", "fedora", "almalinux", "rhel", "centos", "rocky"}:
        return f"{id_}{maj}" if maj else id_
    if id_ == "arch":
        # Arch is rolling; usually no VERSION_ID.
        return "arch"

    return f"{id_}{maj}" if maj else id_ or "linux"

def parse_clang_major(text: str) -> str:
    # Matches both Apple clang and LLVM clang outputs
    m = re.search(r"\bclang(?:[-\w]*)?\s+version\s+(\d+)", text, re.IGNORECASE)
    return m.group(1) if m else ""

def parse_gcc_major(text: str) -> str:
    # Try common formats first
    # e.g. "gcc (GCC) 14.2.1 ..." or "gcc (Ubuntu 13.2.0-23ubuntu3) 13.2.0"
    m = re.search(r"\bgcc\b.*?\b(\d+)\.(\d+)", text, re.IGNORECASE)
    if m:
        return m.group(1)
    # Fallback: first integer that looks like a major before a dot
    m = re.search(r"\b(\d+)\.\d+", text)
    return m.group(1) if m else ""

def compiler_tag(system_name: str) -> str:
    """
    macOS: always use clang major version.
    Linux: prefer gcc major if available, else clang major.
    """
    if system_name == "Darwin":
        out = run(["clang", "--version"])
        major = parse_clang_major(out)
        return f"clang{major}" if major else "clang"
    else:
        if shutil.which("gcc"):
            out = run(["gcc", "--version"])
            major = parse_gcc_major(out)
            return f"gcc{major}" if major else "gcc"
        if shutil.which("clang"):
            out = run(["clang", "--version"])
            major = parse_clang_major(out)
            return f"clang{major}" if major else "clang"
        return "compiler"

def arch_tag() -> str:
    """
    Normalize platform.machine() to 'x86_64' or 'arm64'.
    """
    mach = (platform.machine() or "").lower()

    # Common x86_64 identifiers
    if mach in {"x86_64", "amd64", "x64"}:
        return "x86_64"

    # Common ARM64 identifiers
    if mach in {"aarch64", "arm64"}:
        return "arm64"

    # Some platforms may report things like 'armv8', 'armv7l' — treat armv8 as arm64, others fallback
    if mach.startswith("armv8"):
        return "arm64"

    # Last-resort: try uname -m
    uname_m = run(["uname", "-m"]).lower()
    if uname_m in {"x86_64", "amd64"}:
        return "x86_64"
    if uname_m in {"aarch64", "arm64"}:
        return "arm64"

    # Default to x86_64 if unknown (safer default for most build farms)
    return "x86_64"

def main():
    sysname = platform.system()

    if sysname == "Darwin":
        mac_ver = platform.mac_ver()[0]  # e.g. "14.5"
        mac_major = mac_ver.split(".")[0] if mac_ver else ""
        os_version = f"macosx{mac_major}" if mac_major else "macosx"
        comp = compiler_tag(sysname)
    elif sysname == "Linux":
        os_version = linux_os_version()
        comp = compiler_tag(sysname)
    else:
        raise ValueError(f"Unsupported platform: {sysname}")

    arch = arch_tag()
    print(f"{os_version}-{comp}-{arch}")

if __name__ == "__main__":
    main()
