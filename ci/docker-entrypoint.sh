#!/usr/bin/env bash

ensure_modules() {
  die() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

  # Detect shell (only special-case bash/zsh)
  shell="sh"
  [ -n "${BASH_VERSION-}" ] && shell="bash"
  [ -n "${ZSH_VERSION-}" ]  && shell="zsh"

  module_is_available() {
    if [ "$shell" = "bash" ]; then
      command -v module >/dev/null 2>&1 || declare -F module >/dev/null 2>&1
    elif [ "$shell" = "zsh" ]; then
      command -v module >/dev/null 2>&1 || whence -w module >/dev/null 2>&1
    else
      command -v module >/dev/null 2>&1
    fi
  }

  note_if_module_is_function() {
    if [ "$shell" = "bash" ]; then
      declare -F module >/dev/null 2>&1 && printf '%s\n' "module exists as a function"
    elif [ "$shell" = "zsh" ]; then
      whence -w module 2>/dev/null | grep -q 'function' && printf '%s\n' "module exists as a function"
    fi
  }

  # If already available, note when it's a function and return
  if module_is_available; then
    note_if_module_is_function
    return 0
  fi

  # Prefer Homebrew prefix if present (and only if readable)
  brew_prefix=/opt/homebrew
  brew_init="$brew_prefix/opt/modules/init/$shell"

  if [ -r "$brew_init" ]; then
    # shellcheck disable=SC1090
    . "$brew_init" || die "failed to source $brew_init"
    module_is_available || die "sourced $brew_init but 'module' is still unavailable"
    note_if_module_is_function
    return 0
  fi

  candidates="
    /usr/share/Modules/init/$shell
    /usr/share/Modules/init/sh
    /usr/share/modules/init/$shell
    /usr/share/modules/init/sh
    /etc/profile.d/modules.sh
    /etc/profile.d/env-modules.sh
  "

  found=""
  for f in $candidates; do
    if [ -r "$f" ]; then
      # shellcheck disable=SC1090
      . "$f" || die "failed to source $f"
      found="$f"
      break
    fi
  done

  [ -n "$found" ] || die "no Environment Modules init script found"
  module_is_available || die "sourced $found but 'module' is still unavailable"
  note_if_module_is_function
}

ensure_module

export TERM=xterm-256color
source additional-entrycommands.sh

if [ "${DOCKER_ENTRYPOINT_SOURCE_ONLY:-}" != "1" ]; then
	exec "$@"
fi
