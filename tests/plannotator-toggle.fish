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

function __pt_claude_alias_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.claude"
    printf '{"enabledPlugins":{"plannotator@plannotator":true,"other":true}}\n' >"$HOME/.claude/settings.json"

    plannotator-toggle disable claude >/dev/null
    set -l disabled (__pt_jq '.enabledPlugins["plannotator@plannotator"]' "$HOME/.claude/settings.json")

    plannotator-toggle enable claude >/dev/null
    set -l enabled (__pt_jq '.enabledPlugins["plannotator@plannotator"]' "$HOME/.claude/settings.json")
    set -l other (__pt_jq '.enabledPlugins.other' "$HOME/.claude/settings.json")

    # both alias and canonical name on one line must not double-run the handler
    set -l dedupe_lines (plannotator-toggle disable claude claude-code | string match -e 'claude-code' | count)

    plannotator-toggle enable banana 2>/dev/null
    set -l unknown_rc $status

    echo "$disabled $enabled $other $dedupe_lines $unknown_rc"
end

function __pt_codex_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/.codex"
    printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/old/plannotator","timeout":345600},{"type":"command","command":"plannotator","timeout":1,"env":{"A":"B"}},{"type":"command","command":"other","timeout":2}]}]}}\n' >"$HOME/.codex/hooks.json"
    printf 'codex_hooks = true\n\n[features]\nmemories = true\n' >"$HOME/.codex/config.toml"

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
    set -l hooks_under_features yes
    awk '
      /^[[:space:]]*\[features\][[:space:]]*$/ { in_f=1; next }
      /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { in_f=0; next }
      in_f && /^[[:space:]]*hooks[[:space:]]*=[[:space:]]*true/ { found=1 }
      END { exit found ? 0 : 1 }
    ' "$HOME/.codex/config.toml"; or set hooks_under_features no
    set -l legacy_codex_hooks_present (grep -Eq '^[[:space:]]*codex_hooks[[:space:]]*=' "$HOME/.codex/config.toml"; and echo yes; or echo no)

    echo "$disabled_count $custom_after_disable $other_after_disable $enabled_count $command_is_fixture $custom_after_enable $other_after_enable $hooks_under_features $legacy_codex_hooks_present"
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

function __pt_install_runs_fetched_script
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    set -l fake (mktemp -t fake-plannotator-installer.XXXXXX.sh)
    printf '#!/bin/bash\ntouch "$HOME/.installer-ran"\n' >"$fake"
    chmod +x "$fake"
    set -lx PLANNOTATOR_INSTALL_URL "file://$fake"

    plannotator-toggle install --yes >/dev/null 2>&1
    set -l ran no
    test -f "$HOME/.installer-ran"; and set ran yes

    command rm -f "$fake"
    echo "$ran"
end

function __pt_uninstall_removes_artifacts
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH
    set -lx PLANNOTATOR_TOGGLE_NO_TRASH 1

    mkdir -p "$HOME/.local/bin" "$HOME/.claude/commands" \
        "$HOME/.claude/skills/plannotator-review" \
        "$HOME/.claude/plugins/marketplaces/plannotator/apps" \
        "$HOME/.codex/skills/plannotator-last" \
        "$HOME/.config/opencode/commands" \
        "$HOME/.gemini/commands" "$HOME/.gemini/policies" \
        "$HOME/.agents/skills/plannotator-compound"
    touch "$HOME/.local/bin/plannotator"
    chmod +x "$HOME/.local/bin/plannotator"
    touch "$HOME/.claude/commands/plannotator-review.md"
    touch "$HOME/.claude/commands/keep-me.md"
    touch "$HOME/.claude/skills/plannotator-review/SKILL.md"
    touch "$HOME/.codex/skills/plannotator-last/SKILL.md"
    touch "$HOME/.config/opencode/commands/plannotator-annotate.md"
    touch "$HOME/.gemini/commands/plannotator-review.toml"
    touch "$HOME/.gemini/policies/plannotator.toml"
    touch "$HOME/.agents/skills/plannotator-compound/SKILL.md"
    touch "$HOME/.claude/plugins/marketplaces/plannotator/apps/marker"

    printf '{"enabledPlugins":{"plannotator@plannotator":true}}\n' >"$HOME/.claude/settings.json"

    plannotator-toggle uninstall --yes >/dev/null 2>&1

    set -l bin_gone no
    test -e "$HOME/.local/bin/plannotator"; or set bin_gone yes
    set -l cmd_gone no
    test -e "$HOME/.claude/commands/plannotator-review.md"; or set cmd_gone yes
    set -l skill_gone no
    test -e "$HOME/.claude/skills/plannotator-review"; or set skill_gone yes
    set -l opencode_cmd_gone no
    test -e "$HOME/.config/opencode/commands/plannotator-annotate.md"; or set opencode_cmd_gone yes
    set -l policy_gone no
    test -e "$HOME/.gemini/policies/plannotator.toml"; or set policy_gone yes
    set -l marketplace_gone no
    test -e "$HOME/.claude/plugins/marketplaces/plannotator"; or set marketplace_gone yes
    set -l shared_skill_gone no
    test -e "$HOME/.agents/skills/plannotator-compound"; or set shared_skill_gone yes
    set -l unrelated_kept no
    test -e "$HOME/.claude/commands/keep-me.md"; and set unrelated_kept yes
    set -l plugin_disabled (__pt_jq '.enabledPlugins["plannotator@plannotator"]' "$HOME/.claude/settings.json")

    echo "$bin_gone $cmd_gone $skill_gone $opencode_cmd_gone $policy_gone $marketplace_gone $shared_skill_gone $unrelated_kept $plugin_disabled"
end

function __pt_claude_symlink_round_trip
    set -l root (__pt_fixture)
    set -lx HOME "$root"
    set -lx PATH "$root/bin" $PATH

    mkdir -p "$HOME/dotfiles/claude" "$HOME/.claude"
    printf '{"enabledPlugins":{"plannotator@plannotator":true,"other":true}}\n' \
        >"$HOME/dotfiles/claude/settings.json"
    ln -s "$HOME/dotfiles/claude/settings.json" "$HOME/.claude/settings.json"

    plannotator-toggle disable claude-code >/dev/null
    plannotator-toggle enable claude-code  >/dev/null
    plannotator-toggle disable claude-code >/dev/null

    set -l is_symlink no
    test -L "$HOME/.claude/settings.json"; and set is_symlink yes
    set -l link_value (__pt_jq '.enabledPlugins["plannotator@plannotator"]' "$HOME/.claude/settings.json")
    set -l dotfile_value (__pt_jq '.enabledPlugins["plannotator@plannotator"]' "$HOME/dotfiles/claude/settings.json")
    set -l same_inode no
    test (stat -L -f %i "$HOME/.claude/settings.json") = (stat -L -f %i "$HOME/dotfiles/claude/settings.json"); and set same_inode yes

    echo "$is_symlink $link_value $dotfile_value $same_inode"
end

function __pt_completion_dedupes_agents
    # Block autoloading of any installed copy so only the repo file is tested.
    set -l saved_path $fish_complete_path
    set fish_complete_path
    complete -c plannotator-toggle -e
    source completions/plannotator-toggle.fish

    set -l all (complete -C"plannotator-toggle enable " | string replace -r '\t.*' '')
    set -l after_pi (complete -C"plannotator-toggle enable pi " | string replace -r '\t.*' '')

    set -l pi_gone no
    contains -- pi $after_pi; or set pi_gone yes
    set -l codex_kept no
    contains -- codex $after_pi; and set codex_kept yes

    set fish_complete_path $saved_path
    echo (count $all)" "(count $after_pi)" $pi_gone $codex_kept"
end

@test "claude-code toggles plugin flag and preserves other plugin" (__pt_claude_round_trip) = "false true true true"
@test "claude alias targets claude-code, dedupes with canonical, rejects unknowns" (__pt_claude_alias_round_trip) = "false true true 1 1"
@test "claude-code preserves symlink and writes through to dotfile target" (__pt_claude_symlink_round_trip) = "yes false false yes"
@test "codex manages only canonical Stop hook and preserves custom hook" (__pt_codex_round_trip) = "0 1 1 1 yes 1 1 yes no"
@test "opencode toggles exact plugin entry and preserves adjacent package names" (__pt_opencode_round_trip) = "0 1 1 1 1 1"
@test "gemini toggles exit_plan_mode hook and preserves unrelated hooks" (__pt_gemini_round_trip) = "0 1 1 1"
@test "pi parks old plan-mode extension and toggles package entry" (__pt_pi_round_trip) = "1 0 1 no yes 0 yes"
@test "pi preserves pinned and custom package entries" (__pt_pi_custom_package_is_preserved) = "0 2 0 yes 2 no"
@test "install --yes runs the fetched installer" (__pt_install_runs_fetched_script) = "yes"
@test "uninstall --yes removes artifacts, leaves unrelated files, disables plugin" (__pt_uninstall_removes_artifacts) = "yes yes yes yes yes yes yes yes false"
@test "completions stop suggesting agents already on the line" (__pt_completion_dedupes_agents) = "5 4 yes yes"
