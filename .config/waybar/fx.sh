#!/bin/bash
# EUR→SEK for waybar, straight from the ECB's own reference-rate feed. The
# 90-day file is the only request: it carries the current rate, the previous
# close, the 7/30-day comparisons and the sparkline in one 70 KB download, so
# there is no third party between the bar and the bank, and nothing to break
# when someone else's API version gets retired.
#
# The ECB publishes once per working day around 16:00 CET, so the fetch is
# cached for an hour and the other ticks just re-render the cached file.
# Left-click forces a refresh (see on-click in config.jsonc).

set -u

BASE=EUR
QUOTE=SEK
FEED=https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-fx-${BASE}${QUOTE}.json"
TTL=3600

[ "${1:-}" = "--refresh" ] && TTL=0

mkdir -p "$(dirname "$CACHE")"

FRESH=0
if [ -f "$CACHE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE"))) -lt "$TTL" ]; then
    FRESH=1
fi

if [ "$FRESH" -eq 0 ]; then
    TMP=$(mktemp "$CACHE.XXXXXX")
    # Each day is one <Cube time="..."> line with the per-currency rates inline,
    # so awk pulls out the date and our quote without needing an XML parser.
    curl -sf --compressed --max-time 10 --max-filesize 4000000 "$FEED" 2>/dev/null |
        awk -v q="$QUOTE" '
            match($0, /<Cube time="[0-9-]+"/) {
                d = substr($0, RSTART + 12, RLENGTH - 13)
                if (match($0, "<Cube currency=\"" q "\" rate=\"[0-9.]+\"")) {
                    r = substr($0, RSTART, RLENGTH)
                    sub(/.*rate="/, "", r)
                    sub(/"$/, "", r)
                    print d, r
                }
            }' |
        jq -Rn --arg q "$QUOTE" '
            {rates: ([inputs | split(" ")]
                     | map({key: .[0], value: {($q): (.[1] | tonumber)}})
                     | from_entries)}' >"$TMP" 2>/dev/null

    # A handful of days is enough to tell a real feed from a redirect or an
    # error page; anything short of that leaves the previous cache in place.
    if jq -e '(.rates | length) >= 5' "$TMP" >/dev/null 2>&1; then
        mv "$TMP" "$CACHE"
    else
        rm -f "$TMP"
    fi
fi

if [ ! -s "$CACHE" ]; then
    jq -nc '{text: "€ —", tooltip: "No EUR/SEK rate yet — fetch failed", class: "error"}'
    exit 0
fi

# A rate older than four days means the fetch has been failing for longer than
# a weekend, so the module greys out instead of quietly showing a stale number.
AGE_LIMIT=$(date -d '-4 days' '+%Y-%m-%d')

jq -c --arg quote "$QUOTE" --arg limit "$AGE_LIMIT" \
    --arg d7 "$(date -d '-7 days' '+%Y-%m-%d')" \
    --arg d30 "$(date -d '-30 days' '+%Y-%m-%d')" \
    --arg d45 "$(date -d '-45 days' '+%Y-%m-%d')" '

def fixed($d):
    (pow(10; $d)) as $m
    | ((. * $m | round) | tostring) as $s
    | ($s | length) as $l
    | if $l <= $d
      then "0." + (($d - $l) as $z | if $z > 0 then "0" * $z else "" end) + $s
      else $s[0:$l-$d] + "." + $s[$l-$d:] end;

def lpad($n): tostring | (($n - length) as $z | if $z > 0 then " " * $z else "" end) + .;
def rpad($n): tostring | . + (($n - length) as $z | if $z > 0 then " " * $z else "" end);

# Signed percentage change, with the arrow the bar and the tooltip share.
def pct($from): (. - $from) / $from * 100;
def signed: (if . < 0 then "−" else "+" end) + (length | fixed(2)) + "%";
def arrow: if . > 0.02 then "▲" elif . < -0.02 then "▼" else "·" end;

# Eight block glyphs, scaled over the window the series actually covers.
def spark:
    (min) as $lo | (max) as $hi
    | (if $hi > $lo then $hi - $lo else 1 end) as $span
    | [.[] | 9601 + ((. - $lo) / $span * 7 | round)] | implode;

[.rates | to_entries | sort_by(.key)[] | {date: .key, rate: .value[$quote]}] as $series
| ($series | length) as $n
| $series[-1] as $now
| (if $n > 1 then $series[-2] else $now end) as $prev
| ([$series[] | select(.date <= $d7)]  | (if length > 0 then .[-1] else $series[0] end)) as $w
| ([$series[] | select(.date <= $d30)] | (if length > 0 then .[-1] else $series[0] end)) as $m
# The feed covers 90 days; the tooltip only draws the last 45 so the sparkline
# stays narrower than the lines above it.
| ([$series[] | select(.date >= $d45)] | (if length > 1 then . else $series end)) as $window
| ($now.rate | pct($prev.rate)) as $dp

| {
    text: ("€ " + ($now.rate | fixed(2)) + " " + ($dp | arrow)),
    class: (if $now.date < $limit then "stale" elif $dp > 0.02 then "up" elif $dp < -0.02 then "down" else "flat" end),
    tooltip: (
        "<b>1 € = " + ($now.rate | fixed(4)) + " kr</b>   (1 kr = " + (1 / $now.rate | fixed(5)) + " €)\n"
        + "ECB reference rate, " + ($now.date | @html)
        + (if $now.date < $limit then "  ⚠ stale" else "" end) + "\n\n"
        + ("prev close" | rpad(11)) + ($prev.rate | fixed(4) | lpad(8)) + "  " + ($now.rate | pct($prev.rate) | signed) + "\n"
        + ("7 days" | rpad(11)) + ($w.rate | fixed(4) | lpad(8)) + "  " + ($now.rate | pct($w.rate) | signed) + "\n"
        + ("30 days" | rpad(11)) + ($m.rate | fixed(4) | lpad(8)) + "  " + ($now.rate | pct($m.rate) | signed) + "\n\n"
        + ([$window[] | .rate] | spark) + "\n"
        + ($window[0].date | @html) + " → " + ($now.date | @html)
    ),
  }' "$CACHE"
