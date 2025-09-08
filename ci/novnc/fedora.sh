# Fedora/RHEL/AlmaLinux overrides for start-novnc

# Resolve novnc_proxy (prefer vendored /opt, else system path)
distro_resolve_novnc_proxy() {
  if [ -x /opt/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/opt/novnc/utils/novnc_proxy
  elif [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/usr/share/novnc/utils/novnc_proxy
  elif command -v novnc_proxy >/dev/null 2>&1; then
    NOVNC_PROXY_BIN="$(command -v novnc_proxy)"
  else
    return 1
  fi
}
