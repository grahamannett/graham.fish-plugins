## From:
## - https://github.com/nakulj/auto-venv/blob/369223d5db4cba4acbc85b266174f94855c413e8/conf.d/venv.fish
## which is based on:
## - https://gist.github.com/tommyip/cf9099fa6053e30247e5d0318de2fb9e
## - https://gist.github.com/bastibe/c0950e463ffdfdfada7adf149ae77c6f
##
## Changes:
## * Not based on cd, have user call avenv as tools like uv prefer to activate themselves
## * Update syntax to work with new versions of fish.



function avenv --description "Activate/Deactivate virtualenv"
    status is-command-substitution && return

    # Searched directories are the current directory, and the root of the current git repo if applicable
    set __cdirs (pwd)
    if git rev-parse --show-toplevel &>/dev/null
        set -a __cdirs (realpath (git rev-parse --show-toplevel))
    end

    # Scan directories for a fish-compatible virtual environment
    set -l activate_script "bin/activate.fish"
    set -l VENV_DIR_NAMES .venv venv .env env
    set -l found_venv ""
    for venv_dir in $__cdirs/$VENV_DIR_NAMES
        if test -e "$venv_dir/$activate_script"
            set found_venv $venv_dir
            break
        end
    end

    function __try_deactivate
        # alt is to use `test -n $VIRTUAL_ENV`
        if type -q deactivate
            deactivate
        end
    end

    # Activate the found virtual environment if it's different from the current one
    if test -n "$found_venv"
        if test "$VIRTUAL_ENV" != "$found_venv"
            # Deactivate the current virtual environment before activating a new one
            __try_deactivate
            source "$found_venv/$activate_script"
        else
            # here the current virtual_env is the same as the found one
            # in this case deactivate if deactivate is a cmd
            __try_deactivate
        end
    else
        # Deactivate if a virtual environment is currently active but no env found
        __try_deactivate
    end
end
