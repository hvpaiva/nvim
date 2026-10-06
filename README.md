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
- Toolchains used by the install script: `go` (gopls, shfmt, docker-language-server), `rustup` (rust-analyzer), `mise` (Ruby, standardrb, rubocop, ShellCheck), `npm` (prettier and the YAML, JSON, shell, GitHub Actions and TypeScript servers)
- For Bash debugging, `bashdb` built for the running Bash (my [dotfiles](https://github.com/hvpaiva/dotfiles) build it into `~/.local`)

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

This installs language servers (`rust-analyzer`, `gopls`, `lua-language-server`, `marksman`, `helm_ls`, `yaml-language-server`, `vscode-json-language-server`, `bash-language-server`, `gh-actions-language-server`, `docker-language-server`, `typescript-language-server`), the Lua formatter (`stylua`), the shell formatter (`shfmt`) and linter (`shellcheck`), the Markdown formatter (`prettier`, via `npm`), and the Ruby formatters (`standardrb`, `rubocop`, via `mise` gem backend). It also installs `ruby-lsp` into every Ruby mise has (see below). Conform picks up a project-local `node_modules/.bin/prettier` when present.

Native LSP on-type formatting is enabled for every server that supports it, including Ruby's automatic `end` insertion.

The script also installs GHC and HLS through the `mise-ghcup` backend, plus Cabal, Stack, Ormolu, HLint, and `cabal-gild` through mise. It registers the backend, enables mise's experimental backend support, and selects `latest` for these Haskell tools.

HLS handles `.hs`, `.lhs`, and `.cabal` files. Tree-sitter highlights Haskell, and the existing `gq` and `gQ` mappings format `.hs` files with Ormolu. Use `gQ` to format Cabal files through HLS and `cabal-gild`.

HLint runs through `nvim-lint` when entering or saving `.hs` and `.lhs` buffers. Suggestions appear as diagnostics and respect the project's `.hlint.yaml`.

After installing parsers and language servers, sanity-check with:

```vim
:checkhealth nvim-treesitter
:checkhealth vim.lsp
```

## Ruby and shell

`ruby-lsp` runs under the project's Ruby: Neovim starts it through `mise x` from the project root, so `.ruby-version` or `mise.toml` decide, not the Ruby Neovim was started with (Bundler refuses a Ruby the Gemfile does not pin). Its C extensions are built for one Ruby ABI, so it lives inside each Ruby rather than being a mise tool: mise installs it with every new Ruby from `~/.config/mise/default-gems`, and `scripts/nvim-ruby-lsp` installs it into the active Ruby on first use when missing.

Each Ruby file follows one style, Standard or RuboCop: a `.standard.yml` or `.rubocop.yml` decides, then the bundle's direct dependencies, then Standard. Formatting (`gQ`, `gq`) always goes through Conform with that tool, preferring an executable project binstub, then `bundle exec` when the lockfile has the gem, then the tool on `PATH`. Linting follows the same choice: ruby-lsp lints when the bundle carries the tool (its RuboCop integration, or the Standard add-on), and nvim-lint runs it otherwise (scripts outside a bundle, bundles without a linter). RuboCop daemons started by `--server` are stopped when Neovim exits.

ruby-lsp's test code lenses work: `gl` on a test runs it in the same terminal as `<Space>t`, or debugs it. `<Space>rt` debugs the test around the cursor. Inlay hints (implicit `rescue`, hash shorthand values) show while `<Space>oh` has them on.

Vim's Ruby and shell indent scripts need the regex syntax to leave strings and heredocs alone, so those filetypes keep it loaded under tree-sitter; `=` never changes a string's value. For shell, `gQ` (shfmt) is still the better reindent.

Shell scripts get `bash-language-server` with ShellCheck diagnostics and quick fixes; its optional checks come from `~/.config/shellcheckrc`, shared with the CLI. Inside a project the server indexes the whole tree for cross-file definitions. `shfmt` follows a project's `.editorconfig`, and Google's style otherwise (`-ci -bn`, the buffer's indent). friendly-snippets' shell snippets load in `sh`, `bash` and `zsh` buffers.

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
lua/ruby_tools.lua   Ruby style, lint ownership, test lenses
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

This installs Delve, debugpy, the JavaScript debug adapter, CodeLLDB and the Bash
debug adapter. rdbg ships with every Ruby, and the project's own runs; bashdb comes
from the dotfiles (the adapter's bundled copy predates current Bash).
The configuration supports Ruby files, Minitest/RSpec and single tests, Go packages
and tests, Python, Node JavaScript/TypeScript, Bash scripts, and compiled
Rust/C/C++ executables.
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
| `<Space>rt` | Debug the test around the cursor (Ruby) |
| `<Space>rq` | Stop debugging |

These mappings are global; adding a DAP adapter for another language reuses them.

## Verification

```bash
stylua --check .
shellcheck scripts/*
nvim --headless -u NONE -n -i NONE -l tests/workflow.lua
NVIM_DEBUG_TEST_LANGUAGE=ruby nvim --headless -u NONE -n -i NONE -l tests/debugging.lua
nvim --headless -i NONE --cmd 'let g:minivisits_disable = v:true' -c 'luafile tests/languages.lua'
```

The workflow checks use temporary fixtures and capture commands without running
project tests. Debugging checks launch temporary programs and verify a breakpoint,
value inspection, and stepping. The debug selector also accepts `ruby_bundle`,
`go`, `rust`, `python`, `javascript`, `typescript`, and `bash`; each requires its
toolchain and adapter. The language checks load the full config against temporary
Ruby and shell fixtures: style and lint ownership, test lenses, ruby-lsp and bashls
settings, shfmt style, shell snippets, and indentation that keeps string bodies.
