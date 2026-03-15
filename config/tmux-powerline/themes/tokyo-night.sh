# shellcheck shell=bash disable=SC2034
####################################################################################################
# Tokyo Night theme for tmux-powerline
# Flat/minimal style with thin separators
####################################################################################################

# Tokyo Night Storm palette
thm_bg="#24283b"
thm_bg_dark="#1f2335"
thm_bg_highlight="#292e42"
thm_fg="#c0caf5"
thm_fg_dark="#a9b1d6"
thm_fg_gutter="#3b4261"
thm_blue="#7aa2f7"
thm_cyan="#7dcfff"
thm_green="#9ece6a"
thm_magenta="#bb9af7"
thm_purple="#9d7cd8"
thm_orange="#ff9e64"
thm_red="#f7768e"
thm_yellow="#e0af68"
thm_teal="#1abc9c"
thm_comment="#565f89"
thm_dark3="#545c7e"
thm_dark5="#737aa2"
thm_terminal_black="#414868"

# Flat/minimal separators - thin vertical bars
TMUX_POWERLINE_SEPARATOR_LEFT_BOLD=""
TMUX_POWERLINE_SEPARATOR_LEFT_THIN="│"
TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD=""
TMUX_POWERLINE_SEPARATOR_RIGHT_THIN="│"
TMUX_POWERLINE_SEPARATOR_THIN="│"

TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR:-$thm_bg}
TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR:-$thm_fg}

TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}
TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_LEFT_BOLD}

# Window status: current window (highlighted)
# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_CURRENT" ]; then
	TMUX_POWERLINE_WINDOW_STATUS_CURRENT=(
		"#[fg=$thm_blue,bg=$thm_bg_highlight,bold]"
		" #I:#W "
		"#[$(format regular)]"
	)
fi

# Window status: default style
# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_STYLE" ]; then
	TMUX_POWERLINE_WINDOW_STATUS_STYLE=(
		"$(format regular)"
	)
fi

# Window status: inactive windows
# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_FORMAT" ]; then
	TMUX_POWERLINE_WINDOW_STATUS_FORMAT=(
		"#[fg=$thm_dark5,bg=$thm_bg]"
		" #I:#W "
	)
fi

# ──────────────────────────────────────────────────────
# LEFT: session  │  git branch
# ──────────────────────────────────────────────────────
# shellcheck disable=SC1143,SC2128
if [ -z "$TMUX_POWERLINE_LEFT_STATUS_SEGMENTS" ]; then
	TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=(
		"tmux_session_info $thm_blue $thm_bg_dark"
		"vcs_branch $thm_green $thm_bg"
	)
fi

# ──────────────────────────────────────────────────────
# RIGHT: sparkline  │  weather  │  battery  │  date  │  time
# ──────────────────────────────────────────────────────
# shellcheck disable=SC1143,SC2128
if [ -z "$TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS" ]; then
	TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=(
		"sparkline $thm_bg $thm_orange"
		"weather $thm_cyan $thm_bg"
		"battery $thm_cyan $thm_bg"
		"date $thm_fg_dark $thm_bg ${TMUX_POWERLINE_SEPARATOR_LEFT_THIN}"
		"time $thm_blue $thm_bg ${TMUX_POWERLINE_SEPARATOR_LEFT_THIN} $thm_bg $thm_comment"
	)
fi
