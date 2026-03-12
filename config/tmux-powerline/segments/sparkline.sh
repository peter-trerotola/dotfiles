# shellcheck shell=bash
# System monitor segment: CPU sparkline, memory %, network throughput, disk usage
# 🖥▁▂▃▅▇▅▃ 🧠 61% 🌐 12MB/s 💾 22%

SPARK_CHARS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
CPU_HIST="${TMPDIR:-/tmp}/tmux-sparkline-cpu.dat"
NET_PREV="${TMPDIR:-/tmp}/tmux-sparkline-net.dat"
HIST_LEN=10

# Tokyo Night palette
COLOR_LOW="#9ece6a"    # green  < 50%
COLOR_MED="#e0af68"    # yellow 50-79%
COLOR_HIGH="#f7768e"   # red    >= 80%
LABEL_COLOR="#737aa2"  # dark5 - subtle labels
BG_COLOR="#24283b"     # background

__color_for_pct() {
	local pct=$1
	if (( pct < 50 )); then
		echo "$COLOR_LOW"
	elif (( pct < 80 )); then
		echo "$COLOR_MED"
	else
		echo "$COLOR_HIGH"
	fi
}

__spark_char() {
	local pct=$1
	local idx=$(( pct * 7 / 100 ))
	(( idx > 7 )) && idx=7
	(( idx < 0 )) && idx=0
	echo "${SPARK_CHARS[$idx]}"
}

__get_cpu() {
	local ncpu
	ncpu=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
	local total
	total=$(ps -A -o %cpu | awk '{sum += $1} END {printf "%.0f", sum}')
	echo $(( total * 100 / (ncpu * 100) ))
}

__get_mem() {
	local free_pct
	free_pct=$(memory_pressure 2>/dev/null | awk '/free percentage/ {print $5}' | tr -d '%')
	if [ -n "$free_pct" ]; then
		echo $(( 100 - free_pct ))
	else
		echo 0
	fi
}

__get_net() {
	# Read total bytes in+out on en0, diff against last reading
	local now_in now_out
	read -r now_in now_out <<< "$(netstat -ib | awk '/en0/ && /Link/ {print $7, $10}')"

	local prev_in=0 prev_out=0 prev_time=0
	if [ -f "$NET_PREV" ]; then
		read -r prev_in prev_out prev_time < "$NET_PREV"
	fi

	local now_time
	now_time=$(date +%s)
	echo "${now_in} ${now_out} ${now_time}" > "$NET_PREV"

	local elapsed=$(( now_time - prev_time ))
	if (( elapsed <= 0 || prev_time == 0 )); then
		printf "%4sB/s" "0"
		return
	fi

	local delta_in=$(( now_in - prev_in ))
	local delta_out=$(( now_out - prev_out ))
	local total_bytes=$(( (delta_in + delta_out) / elapsed ))

	# Convert to human-readable, right-padded to 5 chars (e.g. "482K/s" or "  2M/s")
	if (( total_bytes >= 1048576 )); then
		printf "%4sM/s" "$(( total_bytes / 1048576 ))"
	elif (( total_bytes >= 1024 )); then
		printf "%4sK/s" "$(( total_bytes / 1024 ))"
	else
		printf "%4sB/s" "${total_bytes}"
	fi
}

__get_disk() {
	df / | awk 'NR==2 {gsub(/%/,""); print $5}'
}

__push_history() {
	local file=$1
	local value=$2
	local history=""
	[ -f "$file" ] && history=$(cat "$file")
	history="${history} ${value}"
	echo "$history" | tr ' ' '\n' | grep -v '^$' | tail -n "$HIST_LEN" | tr '\n' ' ' > "$file"
	cat "$file"
}

__render_spark() {
	local data=$1
	local bg=$2
	local out=""
	local last_color=""
	for val in $data; do
		local color
		color=$(__color_for_pct "$val")
		if [ "$color" != "$last_color" ]; then
			out="${out}#[fg=${color},bg=${bg}]"
			last_color="$color"
		fi
		out="${out}$(__spark_char "$val")"
	done
	echo "$out"
}

__colored_pct() {
	local pct=$1
	local color
	color=$(__color_for_pct "$pct")
	printf "#[fg=${color},bg=${BG_COLOR}]%3s%%" "$pct"
}

run_segment() {
	local cpu_pct mem_pct disk_pct net_rate
	cpu_pct=$(__get_cpu)
	mem_pct=$(__get_mem)
	disk_pct=$(__get_disk)
	net_rate=$(__get_net)

	local cpu_data
	cpu_data=$(__push_history "$CPU_HIST" "$cpu_pct")

	local lbl="#[fg=${LABEL_COLOR},bg=${BG_COLOR}]"

	echo "${lbl}🔲 $(__render_spark "$cpu_data" "$BG_COLOR") ${lbl}🧠 $(__colored_pct "$mem_pct") ${lbl}🌐 #[fg=#7dcfff,bg=${BG_COLOR}]${net_rate} ${lbl}💾 $(__colored_pct "$disk_pct")"
	return 0
}
