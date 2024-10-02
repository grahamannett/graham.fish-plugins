## From:
## - https://github.com/nakulj/auto-venv/blob/369223d5db4cba4acbc85b266174f94855c413e8/conf.d/venv.fish
## which is based on:
## - https://gist.github.com/tommyip/cf9099fa6053e30247e5d0318de2fb9e
## - https://gist.github.com/bastibe/c0950e463ffdfdfada7adf149ae77c6f
##
## Changes:
## * Not based on cd, have user call avenv as tools like uv prefer to activate themselves
## * Update syntax to work with new versions of fish.


# Function to deactivate the current virtual environment
# function deactivate_virtualenv
#     if type deactivate >/dev/null 2>&1
#         deactivate
#     end
# end

function avenv --description "Activate/Deactivate virtualenv"
    status is-command-substitution && echo 'early exit' && return

    # Searched directories are the current directory, and the root of the current git repo if applicable
    set __cdirs (pwd)
    if git rev-parse --show-toplevel &>/dev/null
        set -a __cdirs (realpath (git rev-parse --show-toplevel))
    end

    # Scan directories for a fish-compatible virtual environment
    set -l VENV_DIR_NAMES env .env venv .venv
    set -l found_venv ""
    for venv_dir in $__cdirs/$VENV_DIR_NAMES
        if test -e "$venv_dir/bin/activate.fish"
            set found_venv $venv_dir
            break
        end
    end

    # Activate the found virtual environment if it's different from the current one
    if test -n "$found_venv"
        if test "$VIRTUAL_ENV" != "$found_venv"
            # Deactivate the current virtual environment before activating a new one
            if test -n "$VIRTUAL_ENV"
                deactivate
            end
            # echo "Activating virtualenv at $found_venv"
            # Source the activate.fish script
            source "$found_venv/bin/activate.fish"
        else
            # echo "Virtualenv at $found_venv is already active"
        end
    else
        # Deactivate if a virtual environment is currently active but no env found
        if test -n "$VIRTUAL_ENV"
            deactivate
        end
    end
end
