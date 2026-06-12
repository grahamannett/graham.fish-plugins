# chafa completions, hand-written from `chafa --help` (chafa 1.18.2)

# General
complete -c chafa -l files -r -d "Read list of files to process from PATH (- for stdin)"
complete -c chafa -l files0 -r -d "Like --files, NUL-separated"
complete -c chafa -s h -l help -d "Show help"
complete -c chafa -l probe -x -a "auto on off" -d "Probe terminal capabilities (or max seconds to wait)"
complete -c chafa -l probe-mode -x -a "any ctty stdio" -d "How to probe the terminal"
complete -c chafa -l version -d "Show version"
complete -c chafa -s v -l verbose -d "Be verbose"

# Output encoding
complete -c chafa -s f -l format -x -a "iterm kitty sixels symbols" -d "Output format"
complete -c chafa -s O -l optimize -x -a "0 1 2 3 4 5 6 7 8 9" -d "Output compression level [0-9]"
complete -c chafa -l relative -x -a "on off" -d "Relative cursor positioning"
complete -c chafa -l passthrough -x -a "auto none screen tmux" -d "Graphics protocol passthrough for multiplexers"
complete -c chafa -l polite -x -a "on off" -d "Inhibit escape sequences that may confuse other programs"

# Size and layout
complete -c chafa -l align -x -d "Alignment, e.g. top,left or mid,mid"
complete -c chafa -l clear -d "Clear screen before processing each file"
complete -c chafa -l exact-size -x -a "auto on off" -d "Try to match the input's size exactly"
complete -c chafa -l fit-width -d "Fit images to view's width"
complete -c chafa -l font-ratio -x -d "Target font's width/height ratio (default 1/2)"
complete -c chafa -l grid -x -a auto -d "Lay out images in a CxR grid"
complete -c chafa -s g -d "Alias for --grid auto"
complete -c chafa -l label -x -a "on off" -d "Filenames below images"
complete -c chafa -s l -d "Alias for --label on"
complete -c chafa -l link -x -a "auto on off" -d "Turn labels into clickable hyperlinks"
complete -c chafa -l margin-bottom -x -d "Reserve at least NUM rows at the bottom"
complete -c chafa -l margin-right -x -d "Reserve at least NUM columns on the right"
complete -c chafa -l scale -x -a max -d "Scale image (real number or max)"
complete -c chafa -s s -l size -x -d "Max image dimensions WxH in cells"
complete -c chafa -l stretch -d "Stretch image to fit output; ignore aspect"
complete -c chafa -l view-size -x -d "View size WxH in cells"

# Animation and timing
complete -c chafa -l animate -x -a "on off" -d "Whether to allow animation"
complete -c chafa -s d -l duration -x -d "How long to show each file, in seconds"
complete -c chafa -l speed -x -d "Animation speed (multiplier or Nfps)"
complete -c chafa -l watch -d "Watch a single file, redisplaying on change"

# Colors and processing
complete -c chafa -l bg -x -d "Background color (name or hex)"
complete -c chafa -s c -l colors -x -a "none 2 8 16/8 16 240 256 full" -d "Output color mode"
complete -c chafa -l color-extractor -x -a "average median" -d "Method for extracting color from an area"
complete -c chafa -l color-space -x -a "rgb din99d" -d "Color space used for quantization"
complete -c chafa -l dither -x -a "none ordered diffusion noise" -d "Output dither mode"
complete -c chafa -l dither-grain -x -d "Dither grain dimensions WxH in 1/8 cells [1, 2, 4, 8]"
complete -c chafa -l dither-intensity -x -d "Multiplier for dither intensity"
complete -c chafa -l fg -x -d "Foreground color (name or hex)"
complete -c chafa -l invert -d "Swap --fg and --bg"
complete -c chafa -s p -l preprocess -x -a "on off" -d "Image preprocessing"
complete -c chafa -s t -l threshold -x -d "Lower threshold for full transparency [0.0-1.0]"

# Resource allocation
complete -c chafa -l threads -x -d "Maximum number of CPU threads"
complete -c chafa -s w -l work -x -a "1 2 3 4 5 6 7 8 9" -d "Work factor: 1 cheapest, 9 most accurate"

# Symbol encoding
complete -c chafa -l fg-only -d "Character-cell output using foreground colors only"
complete -c chafa -l fill -x -d "Character symbols for fill/gradients"
complete -c chafa -l glyph-file -r -d "Load glyph information from a font file"
complete -c chafa -l symbols -x -d "Symbol classes to employ, e.g. block+border-diagonal"
