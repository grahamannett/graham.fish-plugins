# Completions for plannotator-toggle.

complete -c plannotator-toggle -f

# First positional: verb. Suggest only when no verb has been given yet.
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable install uninstall" \
    -a status -d "Show per-agent state"
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable install uninstall" \
    -a enable -d "Enable plannotator for the listed agents (or all)"
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable install uninstall" \
    -a disable -d "Disable plannotator for the listed agents (or all)"
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable install uninstall" \
    -a install -d "Download and run the upstream Plannotator installer"
complete -c plannotator-toggle -n "not __fish_seen_subcommand_from status enable disable install uninstall" \
    -a uninstall -d "Disable everywhere and remove binary, skills, commands, policies"

# Subsequent positionals: agent names. Allow repetition (status/enable/disable only).
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

# -y/--yes flag for install/uninstall to skip confirmation prompt.
complete -c plannotator-toggle -n "__fish_seen_subcommand_from install uninstall" \
    -s y -l yes -d "Skip confirmation prompt"
