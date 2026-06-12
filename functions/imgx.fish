function imgx --wraps='kitten icat' --wraps=chafa --description 'view images in the terminal'
    if test (count $argv) -eq 0
        echo "usage: imgx IMAGE [IMAGE ...]" >&2
        return 2
    end

    # kitty-protocol terminals: kitten icat is the reference implementation
    # (pixel-perfect, cell-fitted placement)
    if command -q kitten; and string match -qir 'ghostty|kitty|wezterm' -- "$TERM_PROGRAM$TERM"
        command kitten icat $argv
        return
    end

    # chafa probes the terminal and picks the best protocol it speaks
    # (iterm, kitty, sixels), falling back to character art (ssh/tmux/pipes)
    if command -q chafa
        command chafa $argv
    else if command -q kitten
        command kitten icat $argv
    else if command -q kitty
        command kitty +kitten icat $argv
    else
        echo "imgx: install chafa or kitty" >&2
        return 127
    end
end
