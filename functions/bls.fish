function bls --wraps=/bin/ls --description 'bash ls: for bypassing eza'
    # if not a function, can put this in config: alias bls=/bin/ls
    /bin/ls $argv
end
