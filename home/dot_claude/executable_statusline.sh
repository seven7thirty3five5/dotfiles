#!/bin/sh
# Context capacity and account usage supplied by Claude Code on stdin.
exec jq -r '
  def percentage:
    if type == "number" then "\(floor)%" else "--" end;
  def capacity:
    if . >= 1000000 then "\(. / 1000000)M"
    elif . >= 1000 then "\(. / 1000)k"
    else tostring end;

  .context_window as $context |
  "Context \($context.used_percentage | percentage)" +
  (if ($context.context_window_size | type) == "number"
   then " / \($context.context_window_size | capacity)"
   else "" end) +
  " | 5h \(.rate_limits.five_hour.used_percentage | percentage)" +
  " | 7d \(.rate_limits.seven_day.used_percentage | percentage)"
'
