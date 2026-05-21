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
plannotator-toggle install            # download + run upstream installer (with prompt)
plannotator-toggle install -y         # same, skip confirmation prompt
plannotator-toggle uninstall          # disable everywhere + remove file artifacts
```

`install` downloads `https://plannotator.ai/install.sh` to a tempfile so you can `less` it before running, then prompts for confirmation (or pass `-y`) and re-prints status after. Set `PLANNOTATOR_INSTALL_URL` to override the source. `uninstall` first runs `disable` on every agent, then removes the binary, slash commands, skills, Gemini policy, and Claude plugin marketplace directory; uses `trash` if installed, falls back to `rm -rf` (set `PLANNOTATOR_TOGGLE_NO_TRASH=1` to always use `rm`).

Mechanics: surgical `jq` edits to `~/.claude/settings.json` (toggles `enabledPlugins["plannotator@plannotator"]`), `~/.codex/hooks.json` (canonical managed Stop hooks), `~/.config/opencode/opencode.json` (`@plannotator/opencode` plugin entry), `~/.gemini/settings.json` (the `exit_plan_mode` hook), and `~/.pi/agent/settings.json` (canonical Pi package entry). The toggle only manages known installer-shaped entries; custom Plannotator hooks/packages are reported and left untouched. For Pi, enabling plannotator also parks the old auto-discovered local `~/.pi/agent/extensions/plan-mode` directory under `~/.pi/agent/extensions.disabled/` so it does not conflict with Plannotator's own `--plan` flag. `disable` never touches the plannotator binary, slash commands, skills, or policies — `uninstall` is the verb that removes those. Requires `jq`.

Scope note: the `pi` agent above is the original Pi (`@earendil-works/pi-coding-agent`, settings at `~/.pi/agent/settings.json`). oh-my-pi (`omp`, settings at `~/.omp/agent/`) is a separate fork with a different config layout (YAML, JS/TS hook modules) and no Plannotator integration today — this toggle does not manage it. `plannotator-toggle status` prints a footer when `~/.omp/agent/` is present so the omission is visible.

If Plannotator's installer changes shape and this function stops matching the entries it writes, see [docs/plannotator-toggle.md](docs/plannotator-toggle.md) for the audit-and-repair runbook.

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
