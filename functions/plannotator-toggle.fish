# plannotator-toggle: enable/disable plannotator across coding agents.
#
# Plannotator (https://plannotator.ai/) installs hooks into Claude Code,
# Codex, and (eventually) OpenCode. This function flips those hooks on/off
# without uninstalling the binary, so re-enabling is a single command.
#
# Surfaces touched:
#   claude-code: ~/.claude/settings.json -> enabledPlugins["plannotator@plannotator"]
#   codex      : ~/.codex/hooks.json -> Stop hook entries with command basename "plannotator"
#   opencode   : ~/.config/opencode/opencode.json (detection-only today)
#
# State (created lazily on first disable):
#   ~/.plannotator/state/codex-stop-hooks.json   stashed entries restored on enable
#
# Usage:
#   plannotator-toggle                            # status (no args)
#   plannotator-toggle status [agent ...]
#   plannotator-toggle enable [agent ...]
#   plannotator-toggle disable [agent ...]
#
# Agents: claude-code, codex, opencode

function plannotator-toggle --description "Enable/disable plannotator across coding agents (claude-code, codex, opencode)"
    set -l known_agents claude-code codex opencode

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

    mkdir -p $HOME/.plannotator/state

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
        end
    end

    if test "$verb" = status
        echo
        __plannotator_toggle_usage
    end

    return $rc
end

function __plannotator_toggle_usage
    echo "Usage: plannotator-toggle [status|enable|disable] [claude-code codex opencode]"
end

# Print one status line. $argv: label, state-keyword, optional-extra-text...
# state-keyword: enabled | disabled | absent | unknown
function __plannotator_toggle_print
    set -l label $argv[1]
    set -l state $argv[2]

    # Filter out empty extras so callers can pass "" without producing stray spaces.
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

# ---------------------------------------------------------------------------
# claude-code
# ---------------------------------------------------------------------------

function __plannotator_toggle_claude_code
    set -l verb $argv[1]
    set -l f $HOME/.claude/settings.json
    set -l label claude-code

    if not test -f $f
        __plannotator_toggle_print $label absent
        return 0
    end

    # Use `tojson` rather than `// "missing"`: jq's // treats `false` as falsy,
    # which would conflate "value is false" with "key absent".
    set -l current (jq -r '(.enabledPlugins // {})["plannotator@plannotator"] | tojson' $f 2>/dev/null)
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
            if jq --argjson t $target '.enabledPlugins["plannotator@plannotator"] = $t' $f > $f.tmp 2>/dev/null
                mv $f.tmp $f
                __plannotator_toggle_print $label $target_state "(takes effect on next Claude Code launch)"
                return 0
            else
                rm -f $f.tmp
                __plannotator_toggle_print $label unknown "(failed to write $f)"
                return 1
            end
    end
end

# ---------------------------------------------------------------------------
# codex
# ---------------------------------------------------------------------------

function __plannotator_toggle_codex
    set -l verb $argv[1]
    set -l f $HOME/.codex/hooks.json
    set -l stash $HOME/.plannotator/state/codex-stop-hooks.json
    set -l label codex

    # Plannotator-hook predicate (jq snippet, reused below):
    #   (.command // "") | split("/") | last == "plannotator"

    set -l plannotator_count 0
    set -l other_count 0
    if test -f $f
        set plannotator_count (jq '[.hooks.Stop[]?.hooks[]? | select((.command // "") | split("/") | last == "plannotator")] | length' $f 2>/dev/null)
        set other_count (jq '[.hooks.Stop[]?.hooks[]? | select((.command // "") | split("/") | last != "plannotator")] | length' $f 2>/dev/null)
        test -z "$plannotator_count"; and set plannotator_count 0
        test -z "$other_count"; and set other_count 0
    end

    set -l warn ""
    if test "$other_count" -gt 0
        set warn "(also has $other_count non-plannotator Stop hook(s))"
    end

    switch $verb
        case status
            if not test -f $f
                __plannotator_toggle_print $label absent
                return 0
            end
            if test "$plannotator_count" -gt 0
                __plannotator_toggle_print $label enabled "($plannotator_count Stop hook)" $warn
            else
                set -l extra ""
                test -f $stash; and set extra "(stash: $stash)"
                __plannotator_toggle_print $label disabled $extra $warn
            end
            return 0

        case disable
            if not test -f $f; or test "$plannotator_count" -eq 0
                __plannotator_toggle_print $label disabled "(already disabled)" $warn
                return 0
            end

            # Stash plannotator entries.
            jq '[.hooks.Stop[]?.hooks[]? | select((.command // "") | split("/") | last == "plannotator")]' $f > $stash.tmp 2>/dev/null
            or begin
                rm -f $stash.tmp
                __plannotator_toggle_print $label unknown "(failed to read $f for stash)"
                return 1
            end
            mv $stash.tmp $stash

            # Remove plannotator entries; drop empty groups; drop empty Stop key.
            jq '
              if .hooks.Stop then
                .hooks.Stop |= map(.hooks |= map(select((.command // "") | split("/") | last != "plannotator")))
                | .hooks.Stop |= map(select((.hooks // []) | length > 0))
                | (if (.hooks.Stop // []) == [] then del(.hooks.Stop) else . end)
              else . end
            ' $f > $f.tmp 2>/dev/null
            or begin
                rm -f $f.tmp
                __plannotator_toggle_print $label unknown "(failed to rewrite $f)"
                return 1
            end
            mv $f.tmp $f
            __plannotator_toggle_print $label disabled "(stashed to $stash)" $warn
            return 0

        case enable
            if test "$plannotator_count" -gt 0
                __plannotator_toggle_print $label enabled "(already enabled)" $warn
                return 0
            end

            # Determine entries to insert.
            set -l entries
            if test -f $stash
                set entries (cat $stash)
            else
                set -l bin (command -v plannotator)
                if test -z "$bin"
                    __plannotator_toggle_print $label unknown "(no stash and plannotator not on PATH)"
                    return 1
                end
                set entries (jq -nc --arg b "$bin" '[{"type":"command","command":$b,"timeout":345600}]')
            end

            # Empty-stash guard.
            set -l n (echo $entries | jq 'length' 2>/dev/null)
            if test -z "$n"; or test "$n" -eq 0
                set -l bin (command -v plannotator)
                if test -z "$bin"
                    __plannotator_toggle_print $label unknown "(stash is empty and plannotator not on PATH)"
                    return 1
                end
                set entries (jq -nc --arg b "$bin" '[{"type":"command","command":$b,"timeout":345600}]')
            end

            # Ensure file exists.
            if not test -f $f
                echo '{}' > $f
            end

            jq --argjson e "$entries" '
              .hooks //= {} |
              .hooks.Stop //= [] |
              .hooks.Stop += [{"hooks": $e}]
            ' $f > $f.tmp 2>/dev/null
            or begin
                rm -f $f.tmp
                __plannotator_toggle_print $label unknown "(failed to write $f)"
                return 1
            end
            mv $f.tmp $f
            __plannotator_toggle_print $label enabled "(restored from stash)" $warn
            return 0
    end
end

# ---------------------------------------------------------------------------
# opencode (detection-only)
# ---------------------------------------------------------------------------

function __plannotator_toggle_opencode
    set -l verb $argv[1]
    set -l f $HOME/.config/opencode/opencode.json
    set -l label opencode

    if not test -f $f
        __plannotator_toggle_print $label absent
        return 0
    end

    set -l detected (jq -r 'tostring | test("plannotator"; "i")' $f 2>/dev/null)
    if test "$detected" != true
        __plannotator_toggle_print $label absent
        return 0
    end

    switch $verb
        case status
            __plannotator_toggle_print $label unknown "(plannotator references found; toggle not yet implemented for OpenCode)"
        case enable disable
            __plannotator_toggle_print $label unknown "(OpenCode toggle not yet implemented; skipping)"
    end
    return 0
end
