#!/bin/sh

# If sourced from zsh, enable zsh options; if bash, do bash setup.
if [ -n "${ZSH_VERSION:-}" ]; then
  # --- Zsh setup (native autolist/autocomplete) ---
  setopt AUTO_LIST         # like 'autolist'
  setopt AUTO_MENU         # menu complete on repeated TAB
  setopt LIST_PACKED       # tighter listing
  setopt LIST_TYPES        # file type indicators
  setopt COMPLETE_IN_WORD
  autoload -Uz compinit && compinit
else
  # --- Bash setup ---
  # Load Environment Modules if available
  if [ -f /usr/share/Modules/init/bash ]; then
    # RHEL/Fedora style
    # shellcheck disable=SC1091
    source /usr/share/Modules/init/bash
  elif [ -f /usr/share/modules/init/bash ]; then
    # Debian/Ubuntu style
    # shellcheck disable=SC1091
    source /usr/share/modules/init/bash
  elif [ -f /etc/profile.d/modules.sh ]; then
 	source /etc/profile.d/modules.sh
  fi

  # Enable bash-completion if installed (common paths across distros)
  for f in \
    /usr/share/bash-completion/bash_completion \
    /etc/bash_completion \
    /opt/homebrew/etc/bash_completion \
    /usr/local/etc/bash_completion
  do
    [ -r "$f" ] && { # shellcheck disable=SC1090
      source "$f"; break
    }
  done

  # Readline: emulate zsh `autolist` behavior
  bind 'set show-all-if-ambiguous on'
  bind 'set show-all-if-unmodified on'
  bind 'set completion-ignore-case on'
  bind 'set menu-complete-display-prefix on'

  # Arrow keys do prefix search through history (type a prefix then ↑/↓)
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'

  # History quality-of-life
  export HISTSIZE=5000
  export HISTFILESIZE=10000
  export HISTCONTROL=ignoredups:erasedups
  shopt -s histappend 2>/dev/null || true
fi

# -------- Common to both bash and zsh --------
export TERM=xterm-256color

# Aliases
alias l='ls -l'
alias lt='ls -lhrt'
alias ll='ls -lah'
alias gist='git status -s | grep -v \?'
alias gista='git status -s'

# Helpful: ensure we’re interactive (prompt etc.) if you ‘docker run … bash -l’
# Only set PS1 if not already set and we’re on a tty
if [ -t 1 ] && [ -z "${PS1:-}" ]; then
  export PS1='\u@\h:\w\$ '
fi
