# asdf-nub

[nub](https://nubjs.com) plugin for the [asdf](https://asdf-vm.com) version manager (and [mise](https://mise.jdx.dev)).

nub is an all-in-one Node.js toolkit in a single Rust binary: it runs TS/JS directly, runs package scripts, replaces npx, and installs dependencies against your existing lockfile. This plugin installs the official static binaries from [nub's GitHub releases](https://github.com/nubjs/nub/releases) (SHA-256 verified) and exposes both `nub` and `nubx`.

## Install

```bash
# asdf
asdf plugin add nub https://github.com/afonsojramos/asdf-nub.git
asdf install nub latest
asdf set -u nub latest

# mise
mise plugin install nub https://github.com/afonsojramos/asdf-nub.git
mise use -g nub@latest
```

Then pin per project via `.tool-versions`:

```
nub 0.4.11
```

## Platforms

macOS (arm64, x64) and Linux (arm64, x64, plus musl variants, auto-detected).

## License

MIT
