source functions/plannotator-toggle.fish

function __pt_fixture
    set -l root (mktemp -d)
    mkdir -p "$root/bin"
    printf '#!/bin/sh\nexit 0\n' >"$root/bin/plannotator"
    chmod +x "$root/bin/plannotator"
    echo "$root"
end

function __pt_jq
    jq -r "$argv[1]" "$argv[2]"
end

function __pt_claude_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.claude"
    printf '{"enabledPlugins":{"plannotator@plannotator":true,"other":true}}\n' >"$HOME/.claude/settings.json"

    plannotator-toggle disable claude-code >/dev/null
    set -l disabled (__pt_jq '.enabledPlugins["plannotator@plannotator"]' "$HOME/.claude/settings.json")
    set -l other_disabled (__pt_jq '.enabledPlugins.other' "$HOME/.claude/settings.json")

    plannotator-toggle enable claude-code >/dev/null
    set -l enabled (__pt_jq '.enabledPlugins["plannotator@plannotator"]' "$HOME/.claude/settings.json")
    set -l other_enabled (__pt_jq '.enabledPlugins.other' "$HOME/.claude/settings.json")

    echo "$disabled $enabled $other_disabled $other_enabled"
end

function __pt_codex_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.codex"
    printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/old/plannotator","timeout":345600},{"type":"command","command":"plannotator","timeout":1,"env":{"A":"B"}},{"type":"command","command":"other","timeout":2}]}]}}\n' >"$HOME/.codex/hooks.json"
    printf '[features]\nmemories = true\n' >"$HOME/.codex/config.toml"

    plannotator-toggle disable codex >/dev/null
    set -l disabled_count (__pt_jq '[.hooks.Stop[]?.hooks[]? | select(.type == "command" and ((.command // "") | split("/") | last == "plannotator") and .timeout == 345600 and ((keys_unsorted - ["type","command","timeout"]) | length == 0))] | length' "$HOME/.codex/hooks.json")
    set -l custom_after_disable (__pt_jq '[.hooks.Stop[]?.hooks[]? | select(((.command // "") | split("/") | last == "plannotator") and .env.A == "B")] | length' "$HOME/.codex/hooks.json")
    set -l other_after_disable (__pt_jq '[.hooks.Stop[]?.hooks[]? | select(.command == "other")] | length' "$HOME/.codex/hooks.json")

    plannotator-toggle enable codex >/dev/null
    plannotator-toggle enable codex >/dev/null
    set -l enabled_count (__pt_jq '[.hooks.Stop[]?.hooks[]? | select(.type == "command" and ((.command // "") | split("/") | last == "plannotator") and .timeout == 345600 and ((keys_unsorted - ["type","command","timeout"]) | length == 0))] | length' "$HOME/.codex/hooks.json")
    set -l command_path (__pt_jq '.hooks.Stop[]?.hooks[]? | select(.type == "command" and ((.command // "") | split("/") | last == "plannotator") and .timeout == 345600 and ((keys_unsorted - ["type","command","timeout"]) | length == 0)) | .command' "$HOME/.codex/hooks.json")
    set -l command_is_fixture (string match -q '*/bin/plannotator' "$command_path"; and echo yes; or echo no)
    set -l custom_after_enable (__pt_jq '[.hooks.Stop[]?.hooks[]? | select(((.command // "") | split("/") | last == "plannotator") and .env.A == "B")] | length' "$HOME/.codex/hooks.json")
    set -l other_after_enable (__pt_jq '[.hooks.Stop[]?.hooks[]? | select(.command == "other")] | length' "$HOME/.codex/hooks.json")
    set -l hooks_config (string match -q '*codex_hooks = true*' (string collect <"$HOME/.codex/config.toml"); and echo yes; or echo no)

    echo "$disabled_count $custom_after_disable $other_after_disable $enabled_count $command_is_fixture $custom_after_enable $other_after_enable $hooks_config"
end

function __pt_opencode_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.config/opencode"
    printf '{"plugin":["opencode-claude-auth","@plannotator/opencode-extra","@plannotator/opencode@latest"]}\n' >"$HOME/.config/opencode/opencode.json"

    plannotator-toggle disable opencode >/dev/null
    set -l disabled_count (__pt_jq '[.plugin[]? | select(test("^@plannotator/opencode(@.+)?$"; "i"))] | length' "$HOME/.config/opencode/opencode.json")
    set -l extra_after_disable (__pt_jq '[.plugin[]? | select(. == "@plannotator/opencode-extra")] | length' "$HOME/.config/opencode/opencode.json")
    set -l other_after_disable (__pt_jq '[.plugin[]? | select(. == "opencode-claude-auth")] | length' "$HOME/.config/opencode/opencode.json")

    plannotator-toggle enable opencode >/dev/null
    plannotator-toggle enable opencode >/dev/null
    set -l enabled_count (__pt_jq '[.plugin[]? | select(test("^@plannotator/opencode(@.+)?$"; "i"))] | length' "$HOME/.config/opencode/opencode.json")
    set -l extra_after_enable (__pt_jq '[.plugin[]? | select(. == "@plannotator/opencode-extra")] | length' "$HOME/.config/opencode/opencode.json")
    set -l other_after_enable (__pt_jq '[.plugin[]? | select(. == "opencode-claude-auth")] | length' "$HOME/.config/opencode/opencode.json")

    echo "$disabled_count $extra_after_disable $other_after_disable $enabled_count $extra_after_enable $other_after_enable"
end

function __pt_gemini_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.gemini"
    printf '{"hooks":{"BeforeTool":[{"matcher":"exit_plan_mode","hooks":[{"type":"command","command":"plannotator","timeout":1},{"type":"command","command":"other","timeout":2}]},{"matcher":"other","hooks":[{"type":"command","command":"plannotator"}]}]},"experimental":{"plan":true}}\n' >"$HOME/.gemini/settings.json"

    plannotator-toggle disable gemini >/dev/null
    set -l disabled_count (__pt_jq '[.hooks.BeforeTool[]? as $entry | $entry.hooks[]? | select(($entry.matcher // "") == "exit_plan_mode" and ((.command // "") | split("/") | last == "plannotator"))] | length' "$HOME/.gemini/settings.json")
    set -l other_hook (__pt_jq '[.hooks.BeforeTool[]? as $entry | $entry.hooks[]? | select(($entry.matcher // "") == "exit_plan_mode" and .command == "other")] | length' "$HOME/.gemini/settings.json")
    set -l other_matcher (__pt_jq '[.hooks.BeforeTool[]? as $entry | $entry.hooks[]? | select(($entry.matcher // "") == "other" and .command == "plannotator")] | length' "$HOME/.gemini/settings.json")

    plannotator-toggle enable gemini >/dev/null
    plannotator-toggle enable gemini >/dev/null
    set -l enabled_count (__pt_jq '[.hooks.BeforeTool[]? as $entry | $entry.hooks[]? | select(($entry.matcher // "") == "exit_plan_mode" and ((.command // "") | split("/") | last == "plannotator"))] | length' "$HOME/.gemini/settings.json")

    echo "$disabled_count $other_hook $other_matcher $enabled_count"
end

function __pt_pi_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.pi/agent/extensions/plan-mode"
    printf '// local plan mode\n' >"$HOME/.pi/agent/extensions/plan-mode/index.ts"
    printf '{"extensions":["+extensions/plan-mode/index.ts"],"packages":["other-package"]}\n' >"$HOME/.pi/agent/settings.json"

    plannotator-toggle enable pi >/dev/null
    plannotator-toggle enable pi >/dev/null
    set -l enabled_count (__pt_jq '[.packages[]? | select(((if type == "string" then . elif type == "object" then (.source // "") else "" end) | test("^(npm:)?@plannotator/pi-extension(@.*)?$")))] | length' "$HOME/.pi/agent/settings.json")
    set -l old_setting_count (__pt_jq '[.extensions[]? | select(. == "+extensions/plan-mode/index.ts")] | length' "$HOME/.pi/agent/settings.json")
    set -l other_package_count (__pt_jq '[.packages[]? | select(. == "other-package")] | length' "$HOME/.pi/agent/settings.json")
    set -l old_ext_exists no
    test -e "$HOME/.pi/agent/extensions/plan-mode"; and set old_ext_exists yes
    set -l parked_ext_exists no
    test -e "$HOME/.pi/agent/extensions.disabled/plan-mode-plannotator-conflict"; and set parked_ext_exists yes

    plannotator-toggle disable pi >/dev/null
    set -l disabled_count (__pt_jq '[.packages[]? | select(((if type == "string" then . elif type == "object" then (.source // "") else "" end) | test("^(npm:)?@plannotator/pi-extension(@.*)?$")))] | length' "$HOME/.pi/agent/settings.json")
    set -l restored_ext_exists no
    test -e "$HOME/.pi/agent/extensions/plan-mode"; and set restored_ext_exists yes

    echo "$enabled_count $old_setting_count $other_package_count $old_ext_exists $parked_ext_exists $disabled_count $restored_ext_exists"
end

function __pt_pi_custom_package_is_preserved
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.pi/agent/extensions/plan-mode"
    printf '// local plan mode\n' >"$HOME/.pi/agent/extensions/plan-mode/index.ts"
    printf '{"extensions":["+extensions/plan-mode/index.ts"],"packages":[{"source":"npm:@plannotator/pi-extension@1.2.3","skills":[]},{"source":"npm:@plannotator/pi-extension","skills":["custom"]}]}\n' >"$HOME/.pi/agent/settings.json"

    plannotator-toggle enable pi >/dev/null
    set -l managed_after_enable (__pt_jq '[.packages[]? | select(((type == "string" and (. == "npm:@plannotator/pi-extension" or . == "@plannotator/pi-extension")) or (type == "object" and ((.source // "") == "npm:@plannotator/pi-extension" or (.source // "") == "@plannotator/pi-extension") and ((has("skills") | not) or .skills == []) and ((keys_unsorted - ["source","skills"]) | length == 0))))] | length' "$HOME/.pi/agent/settings.json")
    set -l custom_after_enable (__pt_jq '[.packages[]? | select((.source // "") == "npm:@plannotator/pi-extension@1.2.3" or (.skills // []) == ["custom"])] | length' "$HOME/.pi/agent/settings.json")
    set -l old_setting_count (__pt_jq '[.extensions[]? | select(. == "+extensions/plan-mode/index.ts")] | length' "$HOME/.pi/agent/settings.json")
    set -l parked_ext_exists no
    test -e "$HOME/.pi/agent/extensions.disabled/plan-mode-plannotator-conflict"; and set parked_ext_exists yes

    plannotator-toggle disable pi >/dev/null
    set -l custom_after_disable (__pt_jq '[.packages[]? | select((.source // "") == "npm:@plannotator/pi-extension@1.2.3" or (.skills // []) == ["custom"])] | length' "$HOME/.pi/agent/settings.json")
    set -l restored_ext_exists no
    test -e "$HOME/.pi/agent/extensions/plan-mode"; and set restored_ext_exists yes

    echo "$managed_after_enable $custom_after_enable $old_setting_count $parked_ext_exists $custom_after_disable $restored_ext_exists"
end

@test "claude-code toggles plugin flag and preserves other plugin" (__pt_claude_round_trip) = "false true true true"
@test "codex manages only canonical Stop hook and preserves custom hook" (__pt_codex_round_trip) = "0 1 1 1 yes 1 1 yes"
@test "opencode toggles exact plugin entry and preserves adjacent package names" (__pt_opencode_round_trip) = "0 1 1 1 1 1"
@test "gemini toggles exit_plan_mode hook and preserves unrelated hooks" (__pt_gemini_round_trip) = "0 1 1 1"
@test "pi parks old plan-mode extension and toggles package entry" (__pt_pi_round_trip) = "1 0 1 no yes 0 yes"
@test "pi preserves pinned and custom package entries" (__pt_pi_custom_package_is_preserved) = "0 2 0 yes 2 no"
