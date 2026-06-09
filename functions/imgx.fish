function imgx --description 'view images in the terminal'
    if test (count $argv) -eq 0
        echo "usage: imgx IMAGE [IMAGE ...]" >&2
        return 2
    end

    if command -q viu
        command viu $argv
    else if command -q chafa
        command chafa $argv
    else if command -q kitten
        command kitten icat $argv
    else if command -q kitty
        command kitty +kitten icat $argv
    else
        echo "imgx: install viu, chafa, or kitty" >&2
        return 127
    end
end
