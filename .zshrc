# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# CONFIG_MODE: Set this to specify which environment configuration to use
# Examples: "default", "VideoAmp/central", "peter-trerotola/quantum-2123"
# This is typically set via environment variables before running install.sh
# export CONFIG_MODE="VideoAmp/central"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

# Base plugins for all environments
plugins=(git brew vi-mode)

# Add work-specific plugins (set WORK_ORG_PATTERN to match your work org, e.g., "work-org/*")
if [[ -n "$WORK_ORG_PATTERN" ]] && [[ "$CONFIG_MODE" == $WORK_ORG_PATTERN ]]; then
  plugins+=(bazel docker docker-compose gh golang kubectl)
fi

source $ZSH/oh-my-zsh.sh

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias vim="nvim"

# Work-specific aliases (only loaded when WORK_ORG_PATTERN matches CONFIG_MODE)
if [[ -n "$WORK_ORG_PATTERN" ]] && [[ "$CONFIG_MODE" == $WORK_ORG_PATTERN ]]; then
  # Add your work-specific aliases here
  # Example:
  # alias deploy="./scripts/deploy.sh"
  # alias test-all="bazel test //..."
  :  # Placeholder - remove this line when adding actual aliases
fi

# Exports
export GOPATH=~/go
export PATH=~/.opencode/bin:$PATH
export TERM=xterm-256color

# powerline go
function powerline_precmd() {
    local powerline_cmd="$GOPATH/bin/powerline-go -error $? -jobs ${${(%):%j}:-0}"

    # Add CONFIG_MODE to the prompt if set
    if [ ! -z "$CONFIG_MODE" ] && [ "$CONFIG_MODE" != "default" ]; then
        powerline_cmd="$powerline_cmd -shell-var CONFIG_MODE"
    fi

    PS1="$($powerline_cmd)"

    # Uncomment the following line to automatically clear errors after showing
    # them once. This not only clears the error for powerline-go, but also for
    # everything else you run in that shell. Don't enable this if you're not
    # sure this is what you want.

    #set "?"
}
function install_powerline_precmd() {
  for s in "${precmd_functions[@]}"; do
    if [ "$s" = "powerline_precmd" ]; then
      return
    fi
  done
  precmd_functions+=(powerline_precmd)
}
if [ "$TERM" != "linux" ] && [ -f "$GOPATH/bin/powerline-go" ]; then
    install_powerline_precmd
fi
