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

# Subsequent positionals: agent names (status/enable/disable only).
# Each agent is only suggested while it is not already on the command line.
complete -c plannotator-toggle \
    -n "__fish_seen_subcommand_from status enable disable; and not __fish_seen_subcommand_from claude-code" \
    -a claude-code -d "Claude Code"
complete -c plannotator-toggle \
    -n "__fish_seen_subcommand_from status enable disable; and not __fish_seen_subcommand_from codex" \
    -a codex -d "Codex CLI"
complete -c plannotator-toggle \
    -n "__fish_seen_subcommand_from status enable disable; and not __fish_seen_subcommand_from opencode" \
    -a opencode -d "OpenCode"
complete -c plannotator-toggle \
    -n "__fish_seen_subcommand_from status enable disable; and not __fish_seen_subcommand_from gemini" \
    -a gemini -d "Gemini CLI"
complete -c plannotator-toggle \
    -n "__fish_seen_subcommand_from status enable disable; and not __fish_seen_subcommand_from pi" \
    -a pi -d "Pi coding agent"

# -y/--yes flag for install/uninstall to skip confirmation prompt.
complete -c plannotator-toggle -n "__fish_seen_subcommand_from install uninstall" \
    -s y -l yes -d "Skip confirmation prompt"
