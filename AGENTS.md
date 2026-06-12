## Fisher Release Workflow

- This repo is released by annotated git tags such as `v0.2.0`; there is no separate manifest version to bump.
- Use `mise run rel` to release: guard checks, next patch tag, push, then local Fisher reinstall. Tasks live in `mise.toml`.
- For a non-patch version run the steps individually: `mise run rel:tag vX.Y.Z`, then `mise run rel:push`, then `mise run rel:install`. Each step re-derives its input as the highest local v-tag, so only run `rel:push`/`rel:install` right after tagging.
- The guard refuses a dirty tree (untracked files count), a non-`main` branch, or commits not pushed to `origin/main`. There are no override flags — handle exceptional cases manually.
- Fisher treats explicit tag specs as distinct plugins, so moving from `grahamannett/graham.fish-plugins@v0.2.0` to a newer explicit tag requires removing the old spec before installing the new one. `rel:install` handles that.
