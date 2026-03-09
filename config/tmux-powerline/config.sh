# shellcheck shell=bash
# tmux-powerline configuration

export TMUX_POWERLINE_DEBUG_MODE_ENABLED="false"
export TMUX_POWERLINE_PATCHED_FONT_IN_USE="true"
export TMUX_POWERLINE_THEME="tokyo-night"
export TMUX_POWERLINE_DIR_USER_THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-powerline/themes"
export TMUX_POWERLINE_DIR_USER_SEGMENTS="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-powerline/segments"
export TMUX_POWERLINE_STATUS_VISIBILITY="on"
export TMUX_POWERLINE_STATUS_INTERVAL=5
export TMUX_POWERLINE_STATUS_JUSTIFICATION="centre"
export TMUX_POWERLINE_STATUS_LEFT_LENGTH="80"
export TMUX_POWERLINE_STATUS_RIGHT_LENGTH="140"
export TMUX_POWERLINE_WINDOW_STATUS_SEPARATOR=""

export TMUX_POWERLINE_MUTE_LEFT_KEYBINDING="C-["
export TMUX_POWERLINE_MUTE_RIGHT_KEYBINDING="C-]"

# Segment: vcs_branch
export TMUX_POWERLINE_SEG_VCS_BRANCH_MAX_LEN="24"

# Segment: battery
export TMUX_POWERLINE_SEG_BATTERY_TYPE="percentage"

# Segment: rainbarf (CPU/RAM sparkline chart)
export TMUX_POWERLINE_SEG_RAINBARF_ARGS="--width 14 --no-battery"

# Segment: time
export TMUX_POWERLINE_SEG_TIME_FORMAT="%I:%M %p"
