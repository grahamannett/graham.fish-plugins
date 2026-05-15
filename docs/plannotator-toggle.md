# Maintaining `plannotator-toggle.fish`

Runbook for repairing `functions/plannotator-toggle.fish` after Plannotator's
installer drifts. Read this first if `plannotator-toggle status` reports a
state that disagrees with what the agent actually does (hook silently
inactive, deprecation warning at agent startup, new agent the toggle does
not know about).

The toggle is a *surgical* enable/disable for installer-shaped entries in
each agent's settings file. It does not install, uninstall, or move the
binary, slash commands, skills, or policies.

## Source of truth for what Plannotator writes

Plannotator's installer (`curl -fsSL https://plannotator.ai/install.sh | bash`)
is the canonical reference for which files Plannotator touches and what
shape it writes. To audit:

```fish
curl -fsSL https://plannotator.ai/install.sh -o /tmp/plannotator-install.sh
```

- Repo: <https://github.com/backnotprop/plannotator>
- Releases: `gh release list --repo backnotprop/plannotator`
- Per-app hooks files in the repo: `apps/*/hooks/hooks.json`

The installer is intentionally shell + a few inline `node -e` blocks. Most
mutations are easy to read line by line.

## Surfaces the toggle manages

| Agent | File | Managed entry | Identifying signature (the matcher must require this exact shape) |
| --- | --- | --- | --- |
| claude-code | `~/.claude/settings.json` | `enabledPlugins["plannotator@plannotator"] = true / false` | exact key |
| codex (hooks) | `~/.codex/hooks.json` | a `Stop[].hooks[]` element | `type=command`, `basename(command)=plannotator`, `timeout=345600`, *no other keys* |
| codex (config) | `~/.codex/config.toml` | `[features] hooks = true` | TOML table + key |
| opencode | `~/.config/opencode/opencode.json` | `plugin[]` entry | matches regex `^@plannotator/opencode(@.+)?$` |
| gemini | `~/.gemini/settings.json` | `hooks.BeforeTool[]` element | `matcher=exit_plan_mode` and inner hook with `basename(command)=plannotator` |
| pi | `~/.pi/agent/settings.json` | `packages[]` element | `source` is `npm:@plannotator/pi-extension` (with or without `npm:` prefix), `skills:[]`, no other keys |

Side effects the toggle also handles for `pi`:

- Parks `~/.pi/agent/extensions/plan-mode` to
  `~/.pi/agent/extensions.disabled/plan-mode-plannotator-conflict` on
  `enable`; restores it on `disable`. (Pi's old auto-discovered local
  plan-mode extension conflicts with Plannotator's `--plan` flag.)
- Strips `+extensions/plan-mode/index.ts` from `extensions[]`.

## Surfaces the installer writes that the toggle does NOT manage

This is a *deliberate* boundary. `disable` is a toggle, not an uninstall,
so these stay put even when every agent is disabled. Do not "helpfully"
expand the toggle to manage them — that would silently delete user-
installed assets.

- The `plannotator` binary at `~/.local/bin/plannotator`.
- Slash commands under `~/.claude/commands/`,
  `~/.config/opencode/command/`, `~/.gemini/commands/`.
- Skills under `~/.claude/skills/`, `~/.codex/skills/`, `~/.agents/skills/`.
- Gemini policy file `~/.gemini/policies/plannotator.toml`.
- Claude Code plugin hooks file
  `~/.claude/plugins/marketplaces/plannotator/apps/hook/hooks/hooks.json`.

If the user wants those gone they should re-run the installer or remove
them manually.

## Audit procedure

Run this whenever an agent reports the toggle is enabled but the hook is
not firing, or when an agent prints a deprecation warning about a key the
toggle wrote.

1. Re-fetch the install script:

   ```fish
   curl -fsSL https://plannotator.ai/install.sh -o /tmp/plannotator-install.sh
   ```

2. For the affected agent, locate the section of the installer that writes
   that surface. The installer uses obvious banner comments:
   `--- Codex CLI / Desktop app support ---`,
   `--- Gemini CLI support ---`, plus the
   `OPENCODE USERS` / `PI USERS` / `CLAUDE CODE USERS` echo blocks. Inline
   `node -e "..."` and `node - <<NODE` blocks contain the JSON merges.

3. Compare the JSON/TOML the installer writes against the
   `__plannotator_toggle_<agent>_*_count` jq filter in
   `functions/plannotator-toggle.fish`. The matcher must accept the exact
   shape the installer produces.

4. If the installer's signature has changed:
   - Update the matcher (`*_managed_count` and, if present,
     `*_custom_count`) so the toggle still recognises the new shape.
   - Update the writer in the corresponding `__plannotator_toggle_<agent>`
     `case enable` branch so the toggle produces the new shape.
   - Update the test fixture in `tests/plannotator-toggle.fish` to seed
     both the old and new shape, and assert the new shape after enable.

5. Run the tests:

   ```fish
   fisher install jorgebucaran/fishtape  # one-time
   fishtape tests/*.fish
   ```

## Per-agent contract (canonical shapes)

These are what the installer writes today. If any of these no longer
matches the installer, the matcher in the toggle is stale.

### claude-code

```json
{
  "enabledPlugins": {
    "plannotator@plannotator": true
  }
}
```

Matcher uses `tojson` (not `// "missing"`) on the value so `false` is not
conflated with "key absent".

### codex (hooks)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/<you>/.local/bin/plannotator",
            "timeout": 345600
          }
        ]
      }
    ]
  }
}
```

The matcher requires `type=command`, `timeout=345600`, basename of
`command` is `plannotator`, and *exactly* the keys `type`, `command`,
`timeout`. Anything with extra keys (like `env`) is treated as a custom
user hook and left alone.

The writer uses `command -v plannotator` (whatever is first on PATH), not
the installer's hardcoded `~/.local/bin/plannotator`. The matcher accepts
both bare `plannotator` and any absolute path whose basename is
`plannotator`, mirroring the installer's `isManagedPlannotatorCommand`
helper.

### codex (config)

```toml
[features]
hooks = true
```

The installer accepts both `codex_hooks = true` and `hooks = true` inside
`[features]` and rewrites either to `hooks = true`. The toggle migrates
old top-level `codex_hooks = true` lines (left behind by previous toggle
versions or older installers) into `[features] hooks = true` and removes
the top-level line. If the file uses inline `features = ...`, the toggle
bails with an "edit manually" message — same conservative behaviour as
the installer.

### opencode

```json
{
  "plugin": ["@plannotator/opencode@latest"]
}
```

Matcher accepts any version suffix (`@.+`) and is case-insensitive. The
opencode plugin install is *not* automated by the installer — the
installer just prints instructions. The toggle does the actual edit.

### gemini

```json
{
  "hooks": {
    "BeforeTool": [
      {
        "matcher": "exit_plan_mode",
        "hooks": [
          {
            "type": "command",
            "command": "plannotator",
            "timeout": 345600
          }
        ]
      }
    ]
  },
  "experimental": { "plan": true }
}
```

The toggle only manages the `exit_plan_mode` BeforeTool hook. It writes
`{"experimental":{"plan":true}}` if the file does not exist yet (so
`gemini` actually reaches plan mode).

### pi

```json
{
  "packages": [
    { "source": "npm:@plannotator/pi-extension", "skills": [] }
  ]
}
```

Matcher requires `skills:[]` (or no `skills` key) and *exactly* the keys
`source` and `skills`. Pinned versions like
`npm:@plannotator/pi-extension@1.2.3` or entries with custom `skills` are
treated as custom and left untouched. The toggle also strips
`+extensions/plan-mode/index.ts` from `extensions[]` and parks
`~/.pi/agent/extensions/plan-mode` to avoid conflicting with Plannotator's
`--plan` flag.

## Adding a new agent

When the installer adds support for a new agent and you want the toggle
to manage it:

1. Add `<name>` to `set -l known_agents` near the top of
   `plannotator-toggle`.
2. Implement `__plannotator_toggle_<name>` with a `switch $verb` that
   covers `status`, `enable`, and `disable`.
3. Add `__plannotator_toggle_<name>_managed_count` and (if user-customisable)
   `__plannotator_toggle_<name>_custom_count` jq helpers using the
   `__plannotator_toggle_jq_count` shared helper. The signature must be
   *narrow* — match exact key sets, exact timeouts, exact basenames — so
   user-customised entries are reported (`unknown` / `custom_count > 0`)
   and never overwritten.
4. Always write to `"$f.tmp.$fish_pid"` and `mv` only on jq success. Do
   not edit the live file in place.
5. Use `__plannotator_toggle_ensure_parent` and
   `__plannotator_toggle_ensure_json_file` for parent-dir + initial-file
   creation.
6. Add the agent to `completions/plannotator-toggle.fish` (both the verb
   and agent-name completion lines).
7. Add a `__pt_<name>_round_trip` test in `tests/plannotator-toggle.fish`
   that seeds a dirty fixture (managed entry + custom entry + an
   unrelated entry), calls disable then enable, and asserts the unrelated
   entry survives untouched.
8. Add a one-line bullet to the README's `plannotator-toggle` section.

## Anti-patterns

- **Do not widen the managed signature.** The exact-key-set matchers are
  load-bearing: they keep custom user hooks/packages reported as
  `unknown` / `custom_count > 0` and untouched. Loosening them turns the
  toggle into a footgun.
- **Do not delete files outside the managed config files.** `disable` is
  a toggle, not an uninstall. The binary, slash commands, skills, and
  policy file stay put.
- **Do not edit settings files in place.** Always go through
  `"$f.tmp.$fish_pid"` + `mv` on jq success. A failed jq run must leave
  the live file untouched.
- **Do not call `mkdir`/`mv` ad-hoc.** Use the
  `__plannotator_toggle_ensure_*` helpers so behaviour stays consistent.
- **Do not drop the bare-vs-absolute `plannotator` command leniency.**
  The matcher accepts both `plannotator` and any absolute path whose
  basename is `plannotator`. The installer does the same — see
  `isManagedPlannotatorCommand` in `install.sh`.
