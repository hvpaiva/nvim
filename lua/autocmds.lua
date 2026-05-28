-- Briefly highlight the region that was just yanked. The named augroup is
-- cleared on each load so re-sourcing this file does not duplicate callbacks.
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("hvpaiva-yank-highlight", { clear = true }),
    desc = "Highlight yanked text",
    callback = function()
        vim.hl.on_yank()
    end,
})

-- Strip `c` (auto-wrap comments) and `o` (continue comment leader on `o`/`O`)
-- per-buffer on every `FileType`, because most ftplugins re-add them after the
-- global `formatoptions` set in options.lua is applied.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("hvpaiva-formatopts", { clear = true }),
    desc = "Proper 'formatoptions'",
    callback = function()
        vim.opt_local.formatoptions:remove("c")
        vim.opt_local.formatoptions:remove("o")
    end,
})

-- Rebuild tree-sitter parsers after the `nvim-treesitter` plugin updates,
-- keeping parser ABI in sync with the plugin. On the `main` branch
-- `update()` (no args) rebuilds every installed parser; `install()` only
-- adds missing ones.
vim.api.nvim_create_autocmd("PackChanged", {
    group = vim.api.nvim_create_augroup("hvpaiva-ts-rebuild", { clear = true }),
    desc = "Rebuild TS parsers when nvim-treesitter updates",
    callback = function(ev)
        if
            ev.data
            and ev.data.spec
            and ev.data.spec.name == "nvim-treesitter"
            and ev.data.kind == "update"
        then
            require("nvim-treesitter").update()
        end
    end,
})

-- On LSP attach, set buffer-local options that depend on a server being
-- present. `omnifunc` points at mini.completion's LSP function so `<C-x><C-u>`
-- triggers LSP completion and `completefunc` stays free. `formatexpr` is
-- reasserted because the LSP defaults set it buffer-local to
-- `vim.lsp.formatexpr()`, which would route `gq{motion}` through the LSP
-- instead of Conform.
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("hvpaiva-lsp-buffer-options", { clear = true }),
    desc = "Set buffer-local options on LSP attach",
    callback = function(ev)
        vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
        vim.bo[ev.buf].formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
})

-- Enable auto-refreshing code lenses for clients that implement
-- textDocument/codeLens (rust-analyzer, ruby-lsp). `vim.lsp.codelens.enable`
-- handles BufEnter / InsertLeave / BufWritePost refresh internally.
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("hvpaiva-lsp-codelens", { clear = true }),
    desc = "Enable code lenses when supported",
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client or not client:supports_method("textDocument/codeLens") then
            return
        end
        vim.lsp.codelens.enable(true, { bufnr = ev.buf })
    end,
})
