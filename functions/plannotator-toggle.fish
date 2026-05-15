# plannotator-toggle: enable/disable plannotator across coding agents.
#
# Plannotator (https://plannotator.ai/) installs hooks, plugins, and packages
# into several coding agents. This function flips the active integration points
# on/off without uninstalling the binary, slash commands, policies, or skills.
#
# Surfaces touched:
#   claude-code: ~/.claude/settings.json -> enabledPlugins["plannotator@plannotator"]
#   codex      : ~/.codex/hooks.json Stop hooks + ~/.codex/config.toml codex_hooks
#   opencode   : ~/.config/opencode/opencode.json -> plugin[]
#   gemini     : ~/.gemini/settings.json -> hooks.BeforeTool exit_plan_mode hook
#   pi         : ~/.pi/agent/settings.json packages[] + old local plan-mode extension
#
# Usage:
#   plannotator-toggle                            # status (no args)
#   plannotator-toggle status [agent ...]
#   plannotator-toggle enable [agent ...]
#   plannotator-toggle disable [agent ...]
#
# Agents: claude-code, codex, opencode, gemini, pi

function plannotator-toggle --description "Enable/disable plannotator across coding agents"
    set -l known_agents claude-code codex opencode gemini pi

    if not command -q jq
        echo "plannotator-toggle: jq is required (brew install jq)" >&2
        return 1
    end

    set -l verb status
    set -l targets
    if test (count $argv) -ge 1
        set verb $argv[1]
        if test (count $argv) -ge 2
            set targets $argv[2..-1]
        end
    end
    if test (count $targets) -eq 0
        set targets $known_agents
    end

    if not contains -- $verb status enable disable
        echo "plannotator-toggle: unknown verb '$verb'" >&2
        __plannotator_toggle_usage >&2
        return 1
    end
    for t in $targets
        if not contains -- $t $known_agents
            echo "plannotator-toggle: unknown agent '$t' (valid: $known_agents)" >&2
            return 1
        end
    end

    if test "$verb" = status
        set -l bin (command -v plannotator)
        if test -n "$bin"
            echo "plannotator: $bin"
        else
            echo "plannotator: (binary not on PATH)"
        end
        echo
    end

    set -l rc 0
    for t in $targets
        switch $t
            case claude-code
                __plannotator_toggle_claude_code $verb; or set rc 1
            case codex
                __plannotator_toggle_codex $verb; or set rc 1
            case opencode
                __plannotator_toggle_opencode $verb; or set rc 1
            case gemini
                __plannotator_toggle_gemini $verb; or set rc 1
            case pi
                __plannotator_toggle_pi $verb; or set rc 1
        end
    end

    if test "$verb" = status
        echo
        __plannotator_toggle_usage
    end

    return $rc
end

function __plannotator_toggle_usage
    echo "Usage: plannotator-toggle [status|enable|disable] [claude-code codex opencode gemini pi]"
end

function __plannotator_toggle_ensure_parent
    mkdir -p (dirname "$argv[1]")
end

function __plannotator_toggle_ensure_json_file
    set -l f "$argv[1]"
    set -l initial "{}"
    if test (count $argv) -ge 2
        set initial "$argv[2]"
    end
    if not test -f "$f"
        __plannotator_toggle_ensure_parent "$f"
        printf "%s\n" "$initial" >"$f"
    end
end

# Print one status line. $argv: label, state-keyword, optional-extra-text...
# state-keyword: enabled | disabled | absent | unknown
function __plannotator_toggle_print
    set -l label $argv[1]
    set -l state $argv[2]

    set -l parts
    for arg in $argv[3..-1]
        test -n "$arg"; and set -a parts $arg
    end
    set -l extra (string join " " $parts)

    set -l color ""
    set -l reset ""
    if not set -q NO_COLOR
        switch $state
            case enabled
                set color (set_color green)
            case disabled
                set color (set_color red)
            case absent
                set color (set_color brblack)
            case '*'
                set color (set_color yellow)
        end
        set reset (set_color normal)
    end

    set -l word $state
    test "$state" = absent; and set word "not installed"

    if test -n "$extra"
        printf "  %-13s %s%s%s    %s\n" $label $color $word $reset $extra
    else
        printf "  %-13s %s%s%s\n" $label $color $word $reset
    end
end

function __plannotator_toggle_jq_count
    set -l filter "$argv[1]"
    set -l f "$argv[2]"

    if not test -f "$f"
        echo 0
        return 0
    end

    set -l count (jq "$filter" "$f" 2>/dev/null)
    if test -z "$count"
        echo 0
    else
        echo "$count"
    end
end

# ---------------------------------------------------------------------------
# claude-code
# ---------------------------------------------------------------------------

function __plannotator_toggle_claude_code
    set -l verb $argv[1]
    set -l f "$HOME/.claude/settings.json"
    set -l label claude-code

    if not test -f "$f"
        __plannotator_toggle_print $label absent
        return 0
    end

    # Use `tojson` rather than `// "missing"`: jq's // treats `false` as falsy,
    # which would conflate "value is false" with "key absent".
    set -l current (jq -r '(.enabledPlugins // {})["plannotator@plannotator"] | tojson' "$f" 2>/dev/null)
    if test -z "$current"
        __plannotator_toggle_print $label unknown "(failed to parse $f)"
        return 1
    end

    switch $verb
        case status
            switch $current
                case true
                    __plannotator_toggle_print $label enabled
                case false
                    __plannotator_toggle_print $label disabled
                case '*'
                    __plannotator_toggle_print $label absent
            end
            return 0
        case enable disable
            if test "$current" = null
                __plannotator_toggle_print $label absent "(no enabledPlugins entry; skipping)"
                return 0
            end
            set -l target true
            test "$verb" = disable; and set target false
            set -l target_state enabled
            test "$verb" = disable; and set target_state disabled
            if test "$current" = "$target"
                __plannotator_toggle_print $label $target_state "(already $target_state)"
                return 0
            end

            set -l tmp "$f.tmp.$fish_pid"
            if jq --argjson t $target '.enabledPlugins["plannotator@plannotator"] = $t' "$f" >"$tmp" 2>/dev/null
                mv "$tmp" "$f"
                __plannotator_toggle_print $label $target_state "(takes effect on next Claude Code launch)"
                return 0
            end

            __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
            return 1
    end
end

# ---------------------------------------------------------------------------
# codex
# ---------------------------------------------------------------------------

function __plannotator_toggle_codex_managed_count
    __plannotator_toggle_jq_count '
      def is_managed_plannotator:
        .type == "command"
        and ((.command // "") | split("/") | last == "plannotator")
        and .timeout == 345600
        and ((keys_unsorted - ["type", "command", "timeout"]) | length == 0);
      [.hooks.Stop[]?.hooks[]? | select(is_managed_plannotator)] | length
    ' "$argv[1]"
end

function __plannotator_toggle_codex_custom_count
    __plannotator_toggle_jq_count '
      def is_managed_plannotator:
        .type == "command"
        and ((.command // "") | split("/") | last == "plannotator")
        and .timeout == 345600
        and ((keys_unsorted - ["type", "command", "timeout"]) | length == 0);
      [.hooks.Stop[]?.hooks[]? | select(((.command // "") | split("/") | last == "plannotator") and (is_managed_plannotator | not))] | length
    ' "$argv[1]"
end

function __plannotator_toggle_codex_other_count
    __plannotator_toggle_jq_count '[.hooks.Stop[]?.hooks[]? | select((.command // "") | split("/") | last != "plannotator")] | length' "$argv[1]"
end

function __plannotator_toggle_enable_codex_hooks_config
    # Mirrors the awk in plannotator's install.sh enable_codex_hooks_config.
    # Codex deprecated the top-level `codex_hooks = true` flag in favour of
    # `[features] hooks = true`; an older version of this toggle wrote the
    # deprecated form, so we also strip stray top-level `codex_hooks` lines.
    set -l f "$HOME/.codex/config.toml"
    __plannotator_toggle_ensure_parent "$f"

    if not test -f "$f"
        printf "[features]\nhooks = true\n" >"$f"
        return 0
    end

    if grep -Eq '^[[:space:]]*features[[:space:]]*=' "$f" 2>/dev/null
        echo "plannotator-toggle: $f uses inline 'features = ...'; add '[features]' with 'hooks = true' manually" >&2
        return 1
    end

    set -l tmp "$f.tmp.$fish_pid"
    awk '
      function is_table(line) {
          return line ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/
      }
      BEGIN { in_features = 0; saw_features = 0; saw_hook = 0 }
      {
          if (is_table($0)) {
              if (in_features && !saw_hook) {
                  print "hooks = true"
                  saw_hook = 1
              }
              in_features = ($0 ~ /^[[:space:]]*\[features\][[:space:]]*$/)
              if (in_features) saw_features = 1
          }

          if (in_features && $0 ~ /^[[:space:]]*(codex_hooks|hooks)[[:space:]]*=/) {
              print "hooks = true"
              saw_hook = 1
              next
          }

          if (!in_features && $0 ~ /^[[:space:]]*codex_hooks[[:space:]]*=/) {
              next
          }

          print
      }
      END {
          if (saw_features && in_features && !saw_hook) {
              print "hooks = true"
          } else if (!saw_features) {
              print ""
              print "[features]"
              print "hooks = true"
          }
      }
    ' "$f" >"$tmp" 2>/dev/null
    or begin
        echo "plannotator-toggle: failed to rewrite $f; temp left at $tmp" >&2
        return 1
    end
    mv "$tmp" "$f"
end

function __plannotator_toggle_codex
    set -l verb $argv[1]
    set -l f "$HOME/.codex/hooks.json"
    set -l label codex

    set -l managed_count (__plannotator_toggle_codex_managed_count "$f")
    set -l custom_count (__plannotator_toggle_codex_custom_count "$f")
    set -l other_count (__plannotator_toggle_codex_other_count "$f")
    set -l warn ""
    if test "$other_count" -gt 0
        set warn "(also has $other_count non-plannotator Stop hook(s))"
    end
    set -l custom_warn ""
    if test "$custom_count" -gt 0
        set custom_warn "(also has $custom_count custom Plannotator Stop hook(s); left untouched)"
    end

    switch $verb
        case status
            if not test -f "$f"
                __plannotator_toggle_print $label absent
                return 0
            end
            if test "$managed_count" -gt 0
                __plannotator_toggle_print $label enabled "($managed_count managed Stop hook)" $warn $custom_warn
            else if test "$custom_count" -gt 0
                __plannotator_toggle_print $label unknown "(custom Plannotator Stop hook present; not managed)" $warn
            else
                __plannotator_toggle_print $label disabled $warn
            end
            return 0

        case disable
            if not test -f "$f"; or test "$managed_count" -eq 0
                if test "$custom_count" -gt 0
                    __plannotator_toggle_print $label unknown "(custom Plannotator Stop hook present; skipping)"
                    return 0
                end
                __plannotator_toggle_print $label disabled "(already disabled)" $warn
                return 0
            end

            set -l tmp "$f.tmp.$fish_pid"
            jq '
              def is_managed_plannotator:
                .type == "command"
                and ((.command // "") | split("/") | last == "plannotator")
                and .timeout == 345600
                and ((keys_unsorted - ["type", "command", "timeout"]) | length == 0);
              if .hooks.Stop then
                .hooks.Stop |= map(.hooks |= map(select(is_managed_plannotator | not)))
                | .hooks.Stop |= map(select((.hooks // []) | length > 0))
                | (if (.hooks.Stop // []) == [] then del(.hooks.Stop) else . end)
              else . end
            ' "$f" >"$tmp" 2>/dev/null
            or begin
                __plannotator_toggle_print $label unknown "(failed to rewrite $f; temp left at $tmp)"
                return 1
            end
            mv "$tmp" "$f"
            __plannotator_toggle_print $label disabled "(removed $managed_count managed Stop hook(s))" $warn $custom_warn
            return 0

        case enable
            set -l bin (command -v plannotator)
            if test -z "$bin"
                __plannotator_toggle_print $label unknown "(plannotator not on PATH)"
                return 1
            end

            __plannotator_toggle_ensure_json_file "$f"
            set -l tmp "$f.tmp.$fish_pid"
            jq --arg b "$bin" '
              def is_managed_plannotator:
                .type == "command"
                and ((.command // "") | split("/") | last == "plannotator")
                and .timeout == 345600
                and ((keys_unsorted - ["type", "command", "timeout"]) | length == 0);
              .hooks //= {}
              | .hooks.Stop //= []
              | .hooks.Stop |= map(.hooks |= map(select(is_managed_plannotator | not)))
              | .hooks.Stop |= map(select((.hooks // []) | length > 0))
              | .hooks.Stop += [{"hooks": [{"type": "command", "command": $b, "timeout": 345600}]}]
            ' "$f" >"$tmp" 2>/dev/null
            or begin
                __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                return 1
            end
            mv "$tmp" "$f"
            __plannotator_toggle_enable_codex_hooks_config

            if test "$managed_count" -gt 0
                __plannotator_toggle_print $label enabled "(refreshed managed hook)" $warn
            else
                __plannotator_toggle_print $label enabled "(added managed hook)" $warn $custom_warn
            end
            return 0
    end
end

# ---------------------------------------------------------------------------
# opencode
# ---------------------------------------------------------------------------

function __plannotator_toggle_opencode_count
    __plannotator_toggle_jq_count '[if (.plugin | type) == "array" then .plugin[] elif (.plugin | type) == "string" then .plugin else empty end | select(test("^@plannotator/opencode(@.+)?$"; "i"))] | length' "$argv[1]"
end

function __plannotator_toggle_opencode
    set -l verb $argv[1]
    set -l f "$HOME/.config/opencode/opencode.json"
    set -l label opencode
    set -l count (__plannotator_toggle_opencode_count "$f")

    switch $verb
        case status
            if not test -f "$f"
                __plannotator_toggle_print $label absent
            else if test "$count" -gt 0
                __plannotator_toggle_print $label enabled "($count plugin entry)"
            else
                __plannotator_toggle_print $label disabled "(no @plannotator/opencode plugin entry)"
            end
            return 0

        case disable
            if not test -f "$f"; or test "$count" -eq 0
                __plannotator_toggle_print $label disabled "(already disabled)"
                return 0
            end

            set -l tmp "$f.tmp.$fish_pid"
            jq '
              if (.plugin | type) == "array" then
                .plugin |= map(select(test("^@plannotator/opencode(@.+)?$"; "i") | not))
              elif (.plugin | type) == "string" and (.plugin | test("^@plannotator/opencode(@.+)?$"; "i")) then
                del(.plugin)
              else . end
            ' "$f" >"$tmp" 2>/dev/null
            or begin
                __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                return 1
            end
            mv "$tmp" "$f"
            __plannotator_toggle_print $label disabled
            return 0

        case enable
            __plannotator_toggle_ensure_json_file "$f"
            set -l tmp "$f.tmp.$fish_pid"
            jq '
              .plugin = (if (.plugin | type) == "array" then .plugin elif (.plugin | type) == "string" then [.plugin] else [] end)
              | if ([.plugin[]? | select(test("^@plannotator/opencode(@.+)?$"; "i"))] | length) == 0 then
                  .plugin += ["@plannotator/opencode@latest"]
                else . end
            ' "$f" >"$tmp" 2>/dev/null
            or begin
                __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                return 1
            end
            mv "$tmp" "$f"
            set -l state enabled
            test "$count" -gt 0; and set state "enabled"
            __plannotator_toggle_print $label $state "(plugin entry present)"
            return 0
    end
end

# ---------------------------------------------------------------------------
# gemini
# ---------------------------------------------------------------------------

function __plannotator_toggle_gemini_count
    __plannotator_toggle_jq_count '[.hooks.BeforeTool[]? as $entry | $entry.hooks[]? | select(($entry.matcher // "") == "exit_plan_mode" and ((.command // "") | split("/") | last == "plannotator"))] | length' "$argv[1]"
end

function __plannotator_toggle_gemini
    set -l verb $argv[1]
    set -l f "$HOME/.gemini/settings.json"
    set -l label gemini
    set -l count (__plannotator_toggle_gemini_count "$f")

    switch $verb
        case status
            if not test -f "$f"
                __plannotator_toggle_print $label absent
            else if test "$count" -gt 0
                __plannotator_toggle_print $label enabled "($count BeforeTool hook)"
            else
                __plannotator_toggle_print $label disabled "(no exit_plan_mode plannotator hook)"
            end
            return 0

        case disable
            if not test -f "$f"; or test "$count" -eq 0
                __plannotator_toggle_print $label disabled "(already disabled)"
                return 0
            end

            set -l tmp "$f.tmp.$fish_pid"
            jq '
              if .hooks.BeforeTool then
                .hooks.BeforeTool |= map(
                  if (.matcher // "") == "exit_plan_mode" then
                    .hooks |= map(select(((.command // "") | split("/") | last) != "plannotator"))
                  else . end
                )
                | .hooks.BeforeTool |= map(select((.hooks // []) | length > 0))
                | (if (.hooks.BeforeTool // []) == [] then del(.hooks.BeforeTool) else . end)
                | (if (.hooks // {}) == {} then del(.hooks) else . end)
              else . end
            ' "$f" >"$tmp" 2>/dev/null
            or begin
                __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                return 1
            end
            mv "$tmp" "$f"
            __plannotator_toggle_print $label disabled
            return 0

        case enable
            __plannotator_toggle_ensure_json_file "$f" '{"experimental":{"plan":true}}'
            set -l tmp "$f.tmp.$fish_pid"
            jq '
              .hooks //= {}
              | .hooks.BeforeTool //= []
              | if ([.hooks.BeforeTool[]? as $entry | $entry.hooks[]? | select(($entry.matcher // "") == "exit_plan_mode" and ((.command // "") | split("/") | last == "plannotator"))] | length) == 0 then
                  .hooks.BeforeTool += [{"matcher": "exit_plan_mode", "hooks": [{"type": "command", "command": "plannotator", "timeout": 345600}]}]
                else . end
            ' "$f" >"$tmp" 2>/dev/null
            or begin
                __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                return 1
            end
            mv "$tmp" "$f"
            __plannotator_toggle_print $label enabled "(BeforeTool hook present)"
            return 0
    end
end

# ---------------------------------------------------------------------------
# pi
# ---------------------------------------------------------------------------

function __plannotator_toggle_pi_managed_count
    __plannotator_toggle_jq_count '
      def is_managed_plannotator:
        if type == "string" then
          . == "npm:@plannotator/pi-extension" or . == "@plannotator/pi-extension"
        elif type == "object" then
          ((.source // "") == "npm:@plannotator/pi-extension" or (.source // "") == "@plannotator/pi-extension")
          and ((has("skills") | not) or .skills == [])
          and ((keys_unsorted - ["source", "skills"]) | length == 0)
        else false end;
      [.packages[]? | select(is_managed_plannotator)] | length
    ' "$argv[1]"
end

function __plannotator_toggle_pi_custom_count
    __plannotator_toggle_jq_count '
      def package_source:
        if type == "string" then . elif type == "object" then (.source // "") else "" end;
      def is_managed_plannotator:
        if type == "string" then
          . == "npm:@plannotator/pi-extension" or . == "@plannotator/pi-extension"
        elif type == "object" then
          ((.source // "") == "npm:@plannotator/pi-extension" or (.source // "") == "@plannotator/pi-extension")
          and ((has("skills") | not) or .skills == [])
          and ((keys_unsorted - ["source", "skills"]) | length == 0)
        else false end;
      [.packages[]? | select((package_source | test("^(npm:)?@plannotator/pi-extension(@.+)?$")) and (is_managed_plannotator | not))] | length
    ' "$argv[1]"
end

function __plannotator_toggle_pi
    set -l verb $argv[1]
    set -l f "$HOME/.pi/agent/settings.json"
    set -l label pi
    set -l old_ext "$HOME/.pi/agent/extensions/plan-mode"
    set -l disabled_dir "$HOME/.pi/agent/extensions.disabled"
    set -l disabled_ext "$disabled_dir/plan-mode-plannotator-conflict"
    set -l managed_count (__plannotator_toggle_pi_managed_count "$f")
    set -l custom_count (__plannotator_toggle_pi_custom_count "$f")
    set -l custom_warn ""
    if test "$custom_count" -gt 0
        set custom_warn "(also has $custom_count custom Plannotator package(s); left untouched)"
    end

    switch $verb
        case status
            if test "$managed_count" -gt 0; and test -e "$old_ext"
                __plannotator_toggle_print $label unknown "(plannotator package and old auto-discovered plan-mode extension both active)"
            else if test "$managed_count" -gt 0
                __plannotator_toggle_print $label enabled "($managed_count managed package entry)" $custom_warn
            else if test "$custom_count" -gt 0
                __plannotator_toggle_print $label unknown "(custom Plannotator package present; not managed)"
            else if test -e "$old_ext"
                __plannotator_toggle_print $label disabled "(old local plan-mode extension active)"
            else if test -e "$disabled_ext"
                __plannotator_toggle_print $label disabled "(old local plan-mode parked at $disabled_ext)"
            else if test -f "$f"
                __plannotator_toggle_print $label disabled "(no plannotator pi package)"
            else
                __plannotator_toggle_print $label absent
            end
            return 0

        case enable
            if test -e "$old_ext"
                if test -e "$disabled_ext"
                    __plannotator_toggle_print $label unknown "(both $old_ext and $disabled_ext exist; not moving either)"
                    return 1
                end
                mkdir -p "$disabled_dir"
                mv "$old_ext" "$disabled_ext"
            end

            __plannotator_toggle_ensure_json_file "$f"
            set -l tmp "$f.tmp.$fish_pid"
            if test "$custom_count" -gt 0; and test "$managed_count" -eq 0
                jq '
                  .extensions = ((.extensions // []) | map(select(. != "+extensions/plan-mode/index.ts")))
                ' "$f" >"$tmp" 2>/dev/null
                or begin
                    __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                    return 1
                end
                mv "$tmp" "$f"
                __plannotator_toggle_print $label unknown "(custom Plannotator package present; not adding managed package)"
                return 0
            end

            jq '
              def is_managed_plannotator:
                if type == "string" then
                  . == "npm:@plannotator/pi-extension" or . == "@plannotator/pi-extension"
                elif type == "object" then
                  ((.source // "") == "npm:@plannotator/pi-extension" or (.source // "") == "@plannotator/pi-extension")
                  and ((has("skills") | not) or .skills == [])
                  and ((keys_unsorted - ["source", "skills"]) | length == 0)
                else false end;
              .extensions = ((.extensions // []) | map(select(. != "+extensions/plan-mode/index.ts")))
              | .packages = (if (.packages | type) == "array" then .packages else [] end)
              | .packages |= map(select(is_managed_plannotator | not))
              | .packages += [{"source": "npm:@plannotator/pi-extension", "skills": []}]
            ' "$f" >"$tmp" 2>/dev/null
            or begin
                __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                return 1
            end
            mv "$tmp" "$f"
            __plannotator_toggle_print $label enabled "(plannotator package active; old plan-mode parked if present)"
            return 0

        case disable
            if not test -f "$f"; or test "$managed_count" -eq 0
                if test "$custom_count" -gt 0
                    __plannotator_toggle_print $label unknown "(custom Plannotator package present; skipping)"
                    return 0
                end
            else
                set -l tmp "$f.tmp.$fish_pid"
                jq '
                  def is_managed_plannotator:
                    if type == "string" then
                      . == "npm:@plannotator/pi-extension" or . == "@plannotator/pi-extension"
                    elif type == "object" then
                      ((.source // "") == "npm:@plannotator/pi-extension" or (.source // "") == "@plannotator/pi-extension")
                      and ((has("skills") | not) or .skills == [])
                      and ((keys_unsorted - ["source", "skills"]) | length == 0)
                    else false end;
                  if .packages then
                    .packages |= map(select(is_managed_plannotator | not))
                  else . end
                ' "$f" >"$tmp" 2>/dev/null
                or begin
                    __plannotator_toggle_print $label unknown "(failed to write $f; temp left at $tmp)"
                    return 1
                end
                mv "$tmp" "$f"
            end

            if test "$custom_count" -eq 0; and test -e "$disabled_ext"
                if test -e "$old_ext"
                    __plannotator_toggle_print $label unknown "(both $old_ext and $disabled_ext exist; not moving either)"
                    return 1
                end
                mkdir -p (dirname "$old_ext")
                mv "$disabled_ext" "$old_ext"
            end

            if test "$custom_count" -gt 0
                __plannotator_toggle_print $label unknown "(managed package inactive; custom package remains; old plan-mode left parked)"
            else
                __plannotator_toggle_print $label disabled "(plannotator package inactive; old plan-mode restored if available)"
            end
            return 0
    end
end
