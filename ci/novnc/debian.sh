# Debian/Ubuntu overrides for start-novnc

distro_resolve_novnc_proxy() {
  if [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/usr/share/novnc/utils/novnc_proxy
  elif [ -x /opt/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/opt/novnc/utils/novnc_proxy
  elif command -v novnc_proxy >/dev/null 2>&1; then
    NOVNC_PROXY_BIN="$(command -v novnc_proxy)"
  else
    return 1
  fi
}


# Optional: ensure dbus-launch for some WMs (if installed)
distro_pretty_desktop() {
  if command -v openbox-session >/dev/null 2>&1 && command -v dbus-launch >/dev/null 2>&1; then
    # Relaunch openbox under dbus if it wasn't started with it (best-effort)
    if ! pgrep -f 'dbus-daemon --session' >/dev/null 2>&1; then
      DISPLAY="$DISPLAY" dbus-launch openbox --config-file /etc/xdg/openbox/rc.xml >/dev/null 2>&1 &
    fi
  fi
}
