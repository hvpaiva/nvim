# nvim

My personal Neovim config.

The goal is to be complete in behavior but quiet in interface: no extra chrome, no noisy widgets, nothing that distracts from editing.

This is a keyboard-first setup built around native Neovim features, `mini.nvim`, native LSP, Tree-sitter, Fugitive, transparent Monokai Pro, persistent undo, and `mbbill/undotree`.

It is not a Neovim distribution. It is my daily config, published as-is.

## Screenshots

The UI is transparent. Background colors in these screenshots come from the terminal and wallpaper, not from Neovim itself.

![Code](imgs/code.png)

![LSP clue](imgs/lsp-clue.png)

![Dashboard](imgs/dasboard.png)

## Requirements

- Neovim 0.12+
- `git`
- `ripgrep`
- `diff`
- A C toolchain for Tree-sitter parsers
- Toolchains used by the install script: `go` (gopls, shfmt, docker-language-server), `rustup` (rust-analyzer), `mise` (ruby-lsp, standardrb, rubocop), `npm` (prettier and the YAML, JSON, shell, GitHub Actions and TypeScript servers)

## Install

Back up your current config first:

```bash
mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/hvpaiva/nvim ~/.config/nvim
nvim
```

Plugins are installed by Neovim through `vim.pack` on startup.

To install or refresh the external language tooling I use:

```bash
~/.config/nvim/scripts/nvim-lsp-install
```

This installs language servers (`rust-analyzer`, `gopls`, `lua-language-server`, `marksman`, `ruby-lsp`, `helm_ls`, `yaml-language-server`, `vscode-json-language-server`, `bash-language-server`, `gh-actions-language-server`, `docker-language-server`, `typescript-language-server`), the Lua formatter (`stylua`), the shell formatter (`shfmt`), the Markdown formatter (`prettier`, via `npm`), and the Ruby formatters (`standardrb`, `rubocop`, via `mise` gem backend). Conform picks up a project-local `node_modules/.bin/prettier` when present. Ruby formatters prefer an executable project binstub, then `bundle exec` when the formatter is in the lockfile, then the tool on `PATH`.

Ruby LSP leaves document formatting to Conform. Native LSP on-type formatting is enabled for every server that supports it, including Ruby's automatic `end` insertion.

The script also installs GHC and HLS through the `mise-ghcup` backend, plus Cabal, Stack, Ormolu, HLint, and `cabal-gild` through mise. It registers the backend, enables mise's experimental backend support, and selects `latest` for these Haskell tools.

HLS handles `.hs`, `.lhs`, and `.cabal` files. Tree-sitter highlights Haskell, and the existing `gq` and `gQ` mappings format `.hs` files with Ormolu. Use `gQ` to format Cabal files through HLS and `cabal-gild`.

HLint runs through `nvim-lint` when entering or saving `.hs` and `.lhs` buffers. Suggestions appear as diagnostics and respect the project's `.hlint.yaml`.

After installing parsers and language servers, sanity-check with:

```vim
:checkhealth nvim-treesitter
:checkhealth vim.lsp
```

## Structure

```text
init.lua             load order
lua/options.lua      editor defaults
lua/keymaps.lua      mappings
lua/plugins.lua      plugin list and non-mini setup
lua/mini.lua         mini.nvim modules
lua/training.lua     motion training tools and coaching toggles
lua/workflow.lua     test runners and source/test navigation
lua/debugging.lua    DAP adapters and shared debugging mappings
lua/ruby_tools.lua   project-aware Ruby formatter selection
lua/spell.lua        spell dictionaries and update commands
lua/theme.lua        colorscheme and highlights
lua/treesitter.lua   Tree-sitter setup
lua/lsp.lua          native LSP setup
.stylua.toml         Lua formatting policy
scripts/             helper scripts
snippets/            personal snippets
spell/               spell dictionaries
```

Most details are documented as comments next to the relevant config.

## Training

Training tools are installed but isolated behind `<Leader>p` so they can be kept
without making the normal editing path noisy. `hardtime.nvim` is the only active
coach by default; flip `training_enabled_by_default` in `lua/training.lua` when
that is no longer useful.

`<Leader>` is Space. Use `<Space>pp` to start training, `<Space>pS` to stop,
`<Space>pa` to analyse motions, `<Space>pb` for VimBeBetter, `<Space>pT` for
VimTeacher, `<Space>ph` for a movement hint, `<Space>pH` to toggle hints,
`<Space>pd` to toggle Hardtime, and `<Space>pr` for its report.

## Tests and navigation

The same mappings use vim-test's runner detection in every supported language.
Each test command runs from its project root through mise when available.
The test terminal is reused, and repeating a test preserves its original project.
Test frameworks remain project dependencies.

| Mapping | Action |
| --- | --- |
| `<Space>tt` | Run the nearest test |
| `<Space>tf` | Run the current test file, or the test alternate of a source file |
| `<Space>ts` | Run the test suite |
| `<Space>tl` | Repeat the last test |
| `<Space>tv` | Visit the last test |
| `<Space>ta` | Switch between source and test |
| `<Space>tA` | Open source/test alternate in a vertical split |

Default source/test conventions cover Ruby, Go, Rust, JavaScript, TypeScript,
Python, Haskell, Lua, and shell. A project's `.projections.json` can provide its
own layout. Rust unit tests inside the source file can be run directly.
Haskell selects Stack when `stack.yaml` exists, otherwise Cabal; test granularity
depends on the runner.

## Debugging

Install or refresh the adapters through mise:

```bash
~/.config/nvim/scripts/nvim-debug-install
```

This installs rdbg, Delve, debugpy, the JavaScript debug adapter, and CodeLLDB.
The configuration supports Ruby files and Minitest/RSpec, Go packages and tests,
Python, Node JavaScript/TypeScript, and compiled Rust/C/C++ executables.
Ruby uses Bundler when a Gemfile is present; bundled debugging requires the
`debug` gem in that bundle. Python prefers a project's `.venv`.
Rust/C/C++ prompt for a compiled executable with debug symbols.
Node projects that require a build step, a runtime loader, or browser debugging
can supply their own `.vscode/launch.json`, which nvim-dap loads automatically.

| Mapping | Action |
| --- | --- |
| `<Space>rr` | Start or continue |
| `<Space>rb` / `<Space>rB` | Toggle breakpoint / conditional breakpoint |
| `<Space>rn` / `<Space>ri` / `<Space>ro` | Step over / into / out |
| `<Space>re` / `<Space>rs` | Inspect value / scopes |
| `<Space>rc` | Toggle debug console |
| `<Space>rl` | Repeat the last session |
| `<Space>rq` | Stop debugging |

These mappings are global; adding a DAP adapter for another language reuses them.

## Verification

```bash
stylua --check .
shellcheck scripts/*
nvim --headless -u NONE -n -i NONE -l tests/workflow.lua
NVIM_DEBUG_TEST_LANGUAGE=ruby nvim --headless -u NONE -n -i NONE -l tests/debugging.lua
```

The workflow checks use temporary fixtures and capture commands without running
project tests. Debugging checks launch temporary programs and verify a breakpoint,
value inspection, and stepping. The debug selector also accepts `ruby_bundle`,
`go`, `rust`, `python`, `javascript`, and `typescript`; each requires its toolchain
and adapter.
