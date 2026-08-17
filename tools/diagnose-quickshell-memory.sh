#!/usr/bin/env bash
# Read-only Quickshell memory sampler. It never signals, restarts, or attaches
# to the process. Run: bash tools/diagnose-quickshell-memory.sh [seconds] [samples]
set -euo pipefail

interval="${1:-5}"
samples="${2:-36}"
pid="${QS_PID:-$(pgrep -n -x qs || true)}"

if [[ -z "$pid" || ! -r "/proc/$pid/smaps_rollup" ]]; then
    echo "No readable qs process found. Set QS_PID=<pid> if necessary." >&2
    exit 1
fi

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
report_dir="${QS_MEMORY_REPORT_DIR:-$runtime_dir/quickshell-memory-${pid}-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$report_dir"

sample() {
    local stamp="$1"
    local status="/proc/$pid/status"
    local rollup="/proc/$pid/smaps_rollup"
    if [[ ! -r "$status" || ! -r "$rollup" ]]; then
        echo "Quickshell exited while sampling." >&2
        return 1
    fi
    local rss anon file shared pss
    rss=$(awk '/^VmRSS:/ { print $2 }' "$status")
    anon=$(awk '/^RssAnon:/ { print $2 }' "$status")
    file=$(awk '/^RssFile:/ { print $2 }' "$status")
    shared=$(awk '/^RssShmem:/ { print $2 }' "$status")
    pss=$(awk '/^Pss:/ { print $2 }' "$rollup")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$stamp" "$rss" "$anon" "$file" "$shared" "$pss"
}

{
    printf 'timestamp\trss_kib\tanon_kib\tfile_kib\tshmem_kib\tpss_kib\n'
    for ((index = 0; index < samples; index++)); do
        sample "$(date --iso-8601=seconds)" || break
        if (( index + 1 < samples )); then
            sleep "$interval"
        fi
    done
} | tee "$report_dir/timeline.tsv"

awk '
    /^[0-9a-f]+-[0-9a-f]+ / {
        path = "[anonymous]"
        if (NF >= 6) path = $6
        if (path ~ /memfd:JSGCHeap/) group = "QtQml JS GC heap"
        else if (path ~ /memfd:JSVMStack/) group = "QtQml JS VM stack"
        else if (path ~ /memfd:JITCode/) group = "QtQml JIT code"
        else if (path == "[heap]") group = "glibc heap"
        else if (path == "[anonymous]") group = "unnamed anonymous mappings"
        else if (path ~ /Noto.*\.ttc/) group = "Noto CJK font mappings"
        else if (path ~ /lib/) group = "shared libraries"
        else group = path
        next
    }
    /^Rss:/ { rss[group] += $2 }
    /^Pss:/ { pss[group] += $2 }
    /^Anonymous:/ { anon[group] += $2 }
    END { for (group in rss) printf "%10d %10d %10d  %s\n", rss[group], pss[group], anon[group], group }
' "/proc/$pid/smaps" | sort -nr -k1,1 > "$report_dir/categories.tsv"

awk '
    /^[0-9a-f]+-[0-9a-f]+ / {
        if (header != "" && rss >= 8192 && name == "[anonymous]") print rss "\t" header
        header = $0; name = (NF >= 6 ? $6 : "[anonymous]"); rss = 0; next
    }
    /^Rss:/ { rss = $2 }
    END { if (header != "" && rss >= 8192 && name == "[anonymous]") print rss "\t" header }
' "/proc/$pid/smaps" | sort -nr > "$report_dir/large-anonymous-mappings.tsv"

printf '\nReport: %s\n' "$report_dir"
printf 'Largest categories (RSS KiB / PSS KiB / anonymous KiB):\n'
head -n 12 "$report_dir/categories.tsv"
