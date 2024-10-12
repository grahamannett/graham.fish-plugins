function ls --wraps='/opt/homebrew/bin/eza --group --header --group-directories-first' --description 'alias ls=/opt/homebrew/bin/eza --group --header --group-directories-first'
    # note: original command is /bin/ls
    # i think this is the quickest way to replace the `ls` command with `eza`
    # $EZA_STANDARD_OPTIONS is equivalent to: `--group --header --group-directories-first`
    /opt/homebrew/bin/eza $EZA_STANDARD_OPTIONS $argv
end
