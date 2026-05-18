function cpwd --description 'copy current dir path to clipboard, no trailing newline'
    # printf '%s' instead of `pwd | pbcopy` so there's no trailing \n in the clipboard
    # $PWD is the logical path (symlinks intact); use (pwd -P) if you want it resolved
    printf '%s' $PWD | pbcopy
end
