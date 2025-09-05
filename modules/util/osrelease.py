#!/usr/bin/env python3
import os
import platform
import re
import shutil
import subprocess

def run(cmd):
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
        return out.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

def parse_major(ver: str) -> str:
    """
    Return the leading integer portion of a version string (before the first dot).
    e.g. "24.04" -> "24", "9" -> "9", "" -> "".
    """
    if not ver:
        return ""
    m = re.search(r"\d+", ver)
    return m.group(0) if m else ""

def read_os_release():
    """
    Parse /etc/os-release into a dict. Returns {} if not present.
    """
    path = "/etc/os-release"
    data = {}
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                # Strip surrounding quotes if present
                v = v.strip().strip('"').strip("'")
                data[k] = v
    return data

def linux_os_version():
    osr = read_os_release()
    # Fallbacks if /etc/os-release is missing (rare)
    if not osr:
        # Try Red Hat style
        rh_path = "/etc/redhat-release"
        if os.path.exists(rh_path):
            txt = open(rh_path).read().strip()
            # Examples:
            # "Fedora release 40 (Forty)"
            # "AlmaLinux release 9.4 (Seafoam Ocelot)"
            # "Red Hat Enterprise Linux release 9.3 (Plow)"
            low = txt.lower()
            if low.startswith("fedora"):
                maj = parse_major(txt)
                return f"fedora{maj}"
            if "almalinux" in low:
                maj = parse_major(txt)
                return f"almalinux{maj}"
            if low.startswith("red hat enterprise"):
                maj = parse_major(txt)
                return f"rhel{maj}"
            # Generic fallback
            maj = parse_major(txt)
            base = txt.split()[0].lower()
            return f"{base}{maj}" if maj else base
        raise ValueError("Unsupported linux version: missing /etc/os-release")

    id_ = osr.get("ID", "").lower()
    ver = osr.get("VERSION_ID", "")
    maj = parse_major(ver)

    # Normalize well-known distros
    if id_ in {"ubuntu", "debian", "fedora", "almalinux", "rhel", "centos", "rocky"}:
        return f"{id_}{maj}" if maj else id_
    if id_ == "arch":
        # Arch is rolling; usually no VERSION_ID. Keep it simple.
        return "arch"
    # Some derivatives may not be directly listed above:
    # Try to use ID with major if we have one, else just ID.
    return f"{id_}{maj}" if maj else id_

def compiler_tag(system_name: str) -> str:
    """
    macOS: always use clang major version.
    Linux: prefer gcc major if available, else clang major.
    """
    if system_name == "Darwin":
        out = run(["clang", "--version"])
        # Usually: "Apple clang version 15.0.0 (clang-1500.1.0.2.5)"
        m = re.search(r"\bclang[^ ]*\s+version\s+(\d+)", out)
        major = m.group(1) if m else ""
        return f"clang{major}" if major else "clang"
    else:
        if shutil.which("gcc"):
            out = run(["gcc", "--version"])
            # Usually: "gcc (GCC) 14.2.1 20240805 (Red Hat 14.2.1-1)"
            m = re.search(r"\bgcc.*\)\s+(\d+)", out, re.IGNORECASE) or \
                re.search(r"\bGCC\)?\s+(\d+)", out)
            # Fallback: first number in output
            if not m:
                m = re.search(r"\b(\d+)\.\d+", out)
            major = m.group(1) if m else ""
            return f"gcc{major}" if major else "gcc"
        elif shutil.which("clang"):
            out = run(["clang", "--version"])
            m = re.search(r"\bclang[^ ]*\s+version\s+(\d+)", out)
            major = m.group(1) if m else ""
            return f"clang{major}" if major else "clang"
        else:
            # Last resort: unknown compiler
            return "compiler"

def main():
    sysname = platform.system()
    if sysname == "Darwin":
        # macOS: "macosx<major>"
        mac_ver = platform.mac_ver()[0]  # e.g. "14.5"
        mac_major = mac_ver.split(".")[0] if mac_ver else ""
        os_version = f"macosx{mac_major}" if mac_major else "macosx"
        comp = compiler_tag(sysname)
    elif sysname == "Linux":
        os_version = linux_os_version()
        comp = compiler_tag(sysname)
    else:
        raise ValueError(f"Unsupported platform: {sysname}")

    print(f"{os_version}-{comp}")

if __name__ == "__main__":
    main()
