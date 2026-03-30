function _atuin_suggest --description "Complete current command line from atuin history"
    set -l cmd (commandline --current-buffer)
    if test -z "$cmd"
        return
    end

    set -l result (atuin search --cmd-only --limit 1 --search-mode prefix -- "$cmd" 2>/dev/null)

    if test -n "$result"; and test "$result" != "$cmd"
        commandline --replace -- $result
        commandline --function end-of-line
    end
end
