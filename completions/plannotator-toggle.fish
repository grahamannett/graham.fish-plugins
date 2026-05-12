# Completions for plannotator-toggle.

complete -c plannotator-toggle -f

# First positional: verb. Suggest only when no verb has been given yet.
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable" \
    -a status -d "Show per-agent state"
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable" \
    -a enable -d "Enable plannotator for the listed agents (or all)"
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable" \
    -a disable -d "Disable plannotator for the listed agents (or all)"

# Subsequent positionals: agent names. Allow repetition.
complete -c plannotator-toggle -n "__fish_seen_subcommand_from status enable disable" \
    -a claude-code -d "Claude Code"
complete -c plannotator-toggle -n "__fish_seen_subcommand_from status enable disable" \
    -a codex -d "Codex CLI"
complete -c plannotator-toggle -n "__fish_seen_subcommand_from status enable disable" \
    -a opencode -d "OpenCode"
complete -c plannotator-toggle -n "__fish_seen_subcommand_from status enable disable" \
    -a gemini -d "Gemini CLI"
complete -c plannotator-toggle -n "__fish_seen_subcommand_from status enable disable" \
    -a pi -d "Pi coding agent"
