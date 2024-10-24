# fish functions/conf.d

Putting this in here over my private dotfiles as its easier to manage this way with the fisher plugin manager.

Also often the fish dotfiles can get messed up from me editing/changing plugins and i dont remember what is personal and what is from a plugin and I do not want to go through and figure it out and separate them.


# completions


## supabase
    - supabase completion is generated with the following:

```fish
> echo -e "# `supabase` completion GENERATED FOR VERSION:\n# $(supabase --version)\n" > completions/supabase.fish && supabase completion fish >> completions/supabase.fish
```

    could integrate version with something like (not correct right now though):

    ```fish
    function __supabase_completion_check_version
        if test "$(supabase --version)" = "1.207.9"
            return 0
        end
        return 1
    end
    ```