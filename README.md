# fish functions/conf.d

Putting this in here over my private dotfiles as its easier to manage this way with the fisher plugin manager.

Also often the fish dotfiles can get messed up from me editing/changing plugins and i dont remember what is personal and what is from a plugin and I do not want to go through and figure it out and separate them.


# functions

## plannotator-toggle

Enable/disable [plannotator](https://plannotator.ai/) across coding agents (Claude Code, Codex, OpenCode, Gemini, and Pi) without uninstalling. Plannotator's installer wires hooks and plugin/package entries into multiple agents but ships no built-in toggle.

```fish
plannotator-toggle                    # status
plannotator-toggle disable            # disable for all installed agents
plannotator-toggle enable             # re-enable
plannotator-toggle disable claude-code  # one agent
plannotator-toggle disable claude-code codex pi  # explicit list
```

Mechanics: surgical `jq` edits to `~/.claude/settings.json` (toggles `enabledPlugins["plannotator@plannotator"]`), `~/.codex/hooks.json` (canonical managed Stop hooks), `~/.config/opencode/opencode.json` (`@plannotator/opencode` plugin entry), `~/.gemini/settings.json` (the `exit_plan_mode` hook), and `~/.pi/agent/settings.json` (canonical Pi package entry). The toggle only manages known installer-shaped entries; custom Plannotator hooks/packages are reported and left untouched. For Pi, enabling plannotator also parks the old auto-discovered local `~/.pi/agent/extensions/plan-mode` directory under `~/.pi/agent/extensions.disabled/` so it does not conflict with Plannotator's own `--plan` flag. The plannotator binary, slash commands, skills, and policies are never deleted. Requires `jq`.

Tests:

```fish
fisher install jorgebucaran/fishtape
fishtape tests/*.fish
```


# completions


## supabase

supabase completion is generated with the following:

```fish
> echo -e "# `supabase` completion GENERATED FOR VERSION:\n# $(supabase --version)\n" > completions/supabase.fish && supabase completion fish >> completions/supabase.fish
```

- could integrate version with something like (not correct right now though):

```fish
function __supabase_completion_check_version
    if test "$(supabase --version)" = "1.207.9"
        return 0
    end
    return 1
end
```
