#!/bin/bash
# Next calendar event for waybar, from khal (the su calendar, which pim-sync
# keeps in step with Exchange). Tooltip lists the coming week, click opens ikhal.

ICON=""   # nf-fa-calendar
NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')

# khal prints one JSON array per day, so slurp them back into a single list and
# drop whatever has already finished.
EVENTS=$(khal list --json start --json end --json title today 7d 2>/dev/null |
    jq -sc --arg now "$NOW" '[(add // [])[] | select(.end > $now)]')
COUNT=$(jq -r 'length' <<<"${EVENTS:-[]}")

if [ "${COUNT:-0}" -eq 0 ]; then
    jq -nc --arg text "$ICON" '{text: $text, tooltip: "Nothing in the next 7 days", class: "empty"}'
    exit 0
fi

# Today / Tomorrow / "Mon 28 Sep" for each day the tooltip can mention.
LABELS=$(for i in $(seq 0 7); do
    d=$(date -d "+$i day" '+%Y-%m-%d')
    case $i in
        0) l=Today ;;
        1) l=Tomorrow ;;
        *) l=$(date -d "$d" '+%a %-d %b') ;;
    esac
    printf '%s\t%s\n' "$d" "$l"
done | jq -Rn '[inputs | split("\t")] | map({key: .[0], value: .[1]}) | from_entries')

START=$(jq -r '.[0].start' <<<"$EVENTS")
DAY=${START%% *}
TIME=${START#* }
[ "$DAY" = "$START" ] && TIME="all day"

if [ "$DAY" = "$TODAY" ]; then
    WHEN="$TIME"
else
    WHEN="$(date -d "$DAY" '+%a') $TIME"
fi

CLASS="later"
if [ "$DAY" = "$TODAY" ]; then
    CLASS="today"
    [ "$START" \< "$(date -d '+30 minutes' '+%Y-%m-%d %H:%M')" ] && CLASS="soon"
fi

TOOLTIP=$(jq -r --argjson labels "$LABELS" '
    .[:10]
    | group_by(.start | split(" ")[0])
    | map(
        ( .[0].start | split(" ")[0] ) as $d
        | "<b>" + ($labels[$d] // $d) + "</b>\n"
          + ( map("  " + ((.start | split(" ")[1]) // "all day")
                  + "–" + ((.end | split(" ")[1]) // "")
                  + "  " + (.title | @html))
              | join("\n") )
      )
    | join("\n")' <<<"$EVENTS")
[ "$COUNT" -gt 10 ] && TOOLTIP="$TOOLTIP"$'\n'"…and $((COUNT - 10)) more"

# Only the time goes in the bar: titles are long enough to shove everything
# else around, and they are one hover away in the tooltip.
jq -nc --arg text "$ICON  $WHEN" --arg tooltip "$TOOLTIP" --arg class "$CLASS" \
    '{text: $text, tooltip: $tooltip, class: $class}'
