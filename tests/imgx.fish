source functions/imgx.fish

function __imgx_stub_dir
    set -l dir (mktemp -d)
    for name in $argv
        printf '#!/bin/sh\necho %s "$@"\n' $name >"$dir/$name"
        chmod +x "$dir/$name"
    end
    echo $dir
end

# __imgx_select TERM_PROGRAM TERM stub-commands...
# Runs imgx with PATH reduced to a dir of stubs that echo their own invocation.
function __imgx_select
    set -l dir (__imgx_stub_dir $argv[3..])
    set -lx TERM_PROGRAM $argv[1]
    set -lx TERM $argv[2]
    set -lx PATH $dir
    imgx test.png
end

function __imgx_no_args
    imgx 2>/dev/null
    echo $status
end

function __imgx_no_backends
    set -l dir (mktemp -d)
    set -lx TERM_PROGRAM ''
    set -lx TERM xterm-256color
    set -lx PATH $dir
    imgx test.png 2>/dev/null
    echo $status
end

@test "no args prints usage and returns 2" (__imgx_no_args) = "2"
@test "ghostty prefers kitten icat" (__imgx_select ghostty xterm-ghostty kitten chafa kitty) = "kitten icat test.png"
@test "kitty TERM prefers kitten icat" (__imgx_select '' xterm-kitty kitten chafa) = "kitten icat test.png"
@test "iTerm2 uses chafa" (__imgx_select iTerm.app xterm-256color kitten chafa kitty) = "chafa test.png"
@test "kitty-protocol terminal without kitten falls through to chafa" (__imgx_select ghostty xterm-ghostty chafa kitty) = "chafa test.png"
@test "unknown terminal without chafa falls back to kitten icat" (__imgx_select '' xterm-256color kitten kitty) = "kitten icat test.png"
@test "kitty +kitten icat is the last resort" (__imgx_select '' xterm-256color kitty) = "kitty +kitten icat test.png"
@test "returns 127 when no backend installed" (__imgx_no_backends) = "127"
