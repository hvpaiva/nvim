-- ============================================================================
-- mini.nvim module setups
-- ============================================================================
-- All mini.* submodules are configured here. The bundle is loaded by
-- `vim.pack.add` in `plugins.lua`; this file only calls each `setup()`.
-- Keymaps for these modules live in `lua/keymaps.lua`.

-- mini.files: tree-style file explorer in floating panes. Icons disabled,
-- preview enabled and widened, dotfiles hidden by default (`g.` toggles).
local show_dotfiles = false
local filter_hide = function(fs_entry)
    return not vim.startswith(fs_entry.name, ".")
end
local filter_show = function()
    return true
end
local toggle_dotfiles = function()
    show_dotfiles = not show_dotfiles
    MiniFiles.refresh({ content = { filter = show_dotfiles and filter_show or filter_hide } })
end

require("mini.files").setup({
    content = {
        prefix = function()
            return ""
        end,
        filter = filter_hide,
    },
    windows = {
        preview = true,
        width_focus = 35,
        width_preview = 50,
    },
    mappings = {
        go_in = "L", -- open file/dir, keep explorer open
        go_in_plus = "<CR>", -- open file and close explorer
        go_out = "-", -- go up one level, keep columns to the right
        go_out_plus = "_", -- go up one level and trim right columns
    },
})

-- Bookmarks: jump to common paths with `'<key>` inside the explorer (see `g?`).
vim.api.nvim_create_autocmd("User", {
    pattern = "MiniFilesExplorerOpen",
    callback = function()
        MiniFiles.set_bookmark("c", vim.fn.stdpath("config"), { desc = "Config" })
        MiniFiles.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
    end,
})

-- Bind `g.` inside the explorer buffer to toggle dotfile visibility (oil-style).
vim.api.nvim_create_autocmd("User", {
    pattern = "MiniFilesBufferCreate",
    callback = function(args)
        vim.keymap.set("n", "g.", toggle_dotfiles, { buffer = args.data.buf_id, desc = "Toggle dotfiles" })
    end,
})

-- mini.notify: show only the message body (no timestamp or level prefix).
-- The window grows to fit content; the floor below keeps short messages
-- from collapsing narrower than the "Notifications" history title.
require("mini.notify").setup({
    content = {
        format = function(notif)
            return notif.msg
        end,
    },
    window = {
        config = function(buf_id)
            local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
            local width = 20
            for _, line in ipairs(lines) do
                width = math.max(width, vim.fn.strdisplaywidth(line))
            end
            return { width = width + 2 }
        end,
    },
})

-- mini.cmdline: floating cmdline with completion, autocorrection (`:W`→`:w`,
-- `:lau`→`:lua`, etc.), and autopeek of cmdline ranges.
require("mini.cmdline").setup()

-- mini.comment: comment toggle (`gc{motion}`, `gcc`) overlapping the built-in
-- 0.10+ commenting, plus the `gc` text object (`dgc` deletes a comment block,
-- `vagc` selects one).
require("mini.comment").setup()

-- mini.jump: smarter `f`/`F`/`t`/`T`. Searches across lines, repeats with the
-- same key, and highlights all matches on the line until you commit a jump.
require("mini.jump").setup()

-- mini.jump2d: easymotion-style. `<CR>` labels every word start in the visible
-- window; type the label to teleport there. Replaces tedious chained motions
-- like `}j{w` for on-screen navigation.
require("mini.jump2d").setup()

-- mini.move: move lines (normal) and selections (visual) with `<M-h/j/k/l>`.
-- Up/down moves vertically; left/right adjusts indent (normal) or moves
-- selection (visual). Dot-repeats and preserves selection in visual mode.
require("mini.move").setup()

-- mini.splitjoin: `gS` toggles between joined/split forms of argument lists
-- inside brackets. Dot-repeatable.
require("mini.splitjoin").setup()

-- mini.surround: sa / sd / sr / sf / sF / sh / sn.
require("mini.surround").setup()

-- mini.pairs: auto-close brackets and quotes in insert mode.
require("mini.pairs").setup()

-- mini.bufremove: delete/wipeout a buffer while preserving windows.
-- Replaces vanilla `:bd`, which closes the window if it's the only one
-- showing the buffer.
require("mini.bufremove").setup()

-- mini.visits: track file visits per cwd, with frequency/recency ranking and
-- optional labels (manual bookmarks). Powers the `<leader>fv`/`fV` pickers.
require("mini.visits").setup()

-- mini.misc: small utilities (zoom_window, resize_window, etc.). Loaded for
-- the `<Leader>oz` zoom toggle, plus two side-effects:
--   * `setup_auto_root`     - cwd follows the file's project root (.git/Makefile)
--   * `setup_restore_cursor` - reopen a file with the cursor where you left it
require("mini.misc").setup()
MiniMisc.setup_auto_root()
MiniMisc.setup_restore_cursor()

-- mini.sessions: named session manager on top of `:mksession`. Persists open
-- buffers, splits, tabs, cursor positions across nvim restarts. Sessions live
-- in `~/.local/share/nvim/sessions/` by default.
require("mini.sessions").setup()

-- mini.pick + mini.extra: fuzzy finder for files, grep, help, etc.
require("mini.pick").setup()
require("mini.extra").setup()

-- mini.ai: smarter text objects. Custom adds:
--   * aB / iB - around / inside whole buffer (via mini.extra)
--   * aF / iF - around / inside function definition (via tree-sitter)
-- `search_method = "cover"` only matches text objects that cover the cursor;
-- use `n`/`l` (next/last) suffixes to jump to ones outside the cursor.
-- NOTE: depends on mini.extra being set up above (uses MiniExtra.gen_ai_spec).
local mini_ai = require("mini.ai")
mini_ai.setup({
    n_lines = 500,
    custom_textobjects = {
        B = MiniExtra.gen_ai_spec.buffer(),
        F = mini_ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
    },
    search_method = "cover",
})

-- mini.align: align text in columns. `ga{motion}{char}` aligns by char,
-- `gA{motion}` opens an interactive prompt with live preview. Useful mainly
-- for markdown tables and one-off column alignment.
require("mini.align").setup()

-- mini.bracketed: `[X` / `]X` family for navigating buffers, comments,
-- conflicts, diagnostics, file siblings, indent, jumps, location list,
-- oldfiles, quickfix, treesitter nodes, undo states, windows, and yanks.
-- vim-unimpaired-style. See `:h MiniBracketed-actions` for the full list.
require("mini.bracketed").setup()

-- mini.clue: which-key style popup. Hold a "trigger" key for ~1s and a window
-- lists the available continuations with descriptions. Pulls `desc` from each
-- mapping; the `clues` block below adds group headers (e.g. "+Find") that the
-- Leader namespace doesn't get for free.
local miniclue = require("mini.clue")
miniclue.setup({
    clues = {
        -- Group labels for the Leader namespace.
        { mode = "n", keys = "<Leader>b", desc = "+Buffer" },
        { mode = "n", keys = "<Leader>e", desc = "+Explore/Edit" },
        { mode = "n", keys = "<Leader>f", desc = "+Find" },
        { mode = "n", keys = "<Leader>g", desc = "+Git" },
        { mode = "n", keys = "<Leader>o", desc = "+Other" },
        { mode = "n", keys = "<Leader>s", desc = "+Session" },
        { mode = "n", keys = "<Leader>t", desc = "+Training" },
        { mode = "n", keys = "<Leader>v", desc = "+Visits" },
        { mode = "n", keys = "<Leader>y", desc = "+Yank (with cursor return)" },

        -- Built-in clue generators for native key families.
        miniclue.gen_clues.g(),
        miniclue.gen_clues.marks(),
        miniclue.gen_clues.registers(),
        miniclue.gen_clues.square_brackets(),
        miniclue.gen_clues.windows({ submode_resize = true }),
        miniclue.gen_clues.z(),
    },
    window = {
        -- Width fits the longest description up to 60 columns; beyond that
        -- a single very long entry would push the popup across half the screen.
        config = function(buf_id)
            local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
            local content = 0
            for _, line in ipairs(lines) do
                content = math.max(content, vim.fn.strdisplaywidth(line))
            end
            return { width = math.min(content + 1, 60) }
        end,
    },
    triggers = {
        { mode = "n", keys = "<Leader>" },
        { mode = "x", keys = "<Leader>" },
        { mode = "n", keys = "[" },
        { mode = "n", keys = "]" },
        { mode = "x", keys = "[" },
        { mode = "x", keys = "]" },
        { mode = "n", keys = "g" },
        { mode = "x", keys = "g" },
        { mode = "n", keys = "'" },
        { mode = "n", keys = "`" },
        { mode = "x", keys = "'" },
        { mode = "x", keys = "`" },
        { mode = "n", keys = '"' },
        { mode = "x", keys = '"' },
        { mode = "i", keys = "<C-r>" },
        { mode = "c", keys = "<C-r>" },
        { mode = "n", keys = "<C-w>" },
        { mode = "n", keys = "s" },
        { mode = "x", keys = "s" },
        { mode = "n", keys = "z" },
        { mode = "x", keys = "z" },
    },
})

-- mini.completion: LSP-aware popup completion. With LSP attached, shows
-- candidates from the server; falls back to keyword completion otherwise.
-- `process_items` strips noisy "Text" suggestions and pushes snippets last.
-- `auto_setup = false`: omnifunc is bound per-buffer on `LspAttach` (see
-- autocmds.lua), so completion only kicks in where it has something to do.
local process_items = function(items, base)
    return MiniCompletion.default_process_items(items, base, { kind_priority = { Text = -1, Snippet = 99 } })
end
require("mini.completion").setup({
    lsp_completion = {
        source_func = "omnifunc",
        auto_setup = false,
        process_items = process_items,
    },
})

-- mini.snippets: snippet engine; loads friendly-snippets bundled, plus a
-- personal `snippets/global.json` if present (always available, any filetype).
-- `markdown_inline` lang pattern lets markdown snippets work inside inline
-- code blocks where the tree-sitter injected filetype is `markdown_inline`.
-- `start_lsp_server()` exposes snippets as completion candidates in the
-- mini.completion popup.
local MiniSnippets = require("mini.snippets")
MiniSnippets.setup({
    snippets = {
        MiniSnippets.gen_loader.from_file(vim.fn.stdpath("config") .. "/snippets/global.json"),
        MiniSnippets.gen_loader.from_lang({
            lang_patterns = {
                markdown_inline = { "markdown.json" },
            },
        }),
    },
})
MiniSnippets.start_lsp_server()

-- mini.diff: sign-column hunk markers from git index.
local MiniDiff = require("mini.diff")
MiniDiff.setup({
    source = MiniDiff.gen_source.git({ index = false }),
})
