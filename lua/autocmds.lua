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
        if ev.data and ev.data.spec and ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
            require("nvim-treesitter").update()
        end
    end,
})

-- On LSP attach, set buffer-local options that depend on a server being
-- present. `omnifunc` points at mini.completion's LSP function so `<C-x><C-u>`
-- triggers LSP completion and `completefunc` stays free. `formatexpr` is
-- reasserted because the LSP defaults set it buffer-local to
-- `vim.lsp.formatexpr()`, which would bypass lua/formatexpr.lua.
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("hvpaiva-lsp-buffer-options", { clear = true }),
    desc = "Set buffer-local options on LSP attach",
    callback = function(ev)
        vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
        vim.bo[ev.buf].formatexpr = require("formatexpr").option
    end,
})

-- Code lenses only from servers whose lenses `gl` can act on: their commands
-- run on the server (gopls) or have a client-side handler here (ruby-lsp's
-- tests, rust-analyzer's runnables and references, terraform-ls' references).
-- Others (lua_ls, tsc) only add "N references" noise above every function.
-- `vim.lsp.codelens.enable` handles BufEnter / InsertLeave / BufWritePost
-- refresh internally.
local codelens_clients = { ruby_lsp = true, rust_analyzer = true, terraformls = true, gopls = true }

-- On-type formatting edits the line as you type in the server's own style;
-- lua_ls and tsc would fight stylua and prettier. Only servers whose edits
-- are the point: rust-analyzer adds `;` and the like. ruby-lsp's (`end`, `|`)
-- runs from ruby_tools.enable_on_type.
local on_type_clients = { rust_analyzer = true }

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("hvpaiva-lsp-codelens", { clear = true }),
    desc = "Enable code lenses and on-type formatting for chosen servers",
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client then
            return
        end
        if codelens_clients[client.name] and client:supports_method("textDocument/codeLens") then
            vim.lsp.codelens.enable(true, { bufnr = ev.buf })
        end
        if on_type_clients[client.name] and client:supports_method("textDocument/onTypeFormatting") then
            vim.lsp.on_type_formatting.enable(true, { client_id = client.id })
        end
    end,
})

-- A script is meant to run: make a file executable on its first save with a
-- shebang. `<Leader>oc` covers files without one.
vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("hvpaiva-shebang-exec", { clear = true }),
    desc = "Make files with a shebang executable",
    callback = function(ev)
        local path = vim.api.nvim_buf_get_name(ev.buf)
        local first = vim.api.nvim_buf_get_lines(ev.buf, 0, 1, false)[1] or ""
        if first:match("^#!") and vim.fn.executable(path) == 0 then
            local perm = vim.fn.getfperm(path)
            -- Add x wherever r is set, like `chmod +x` under a 022 umask.
            vim.fn.setfperm(path, (perm:gsub("r(.)%-", "r%1x")))
        end
    end,
})
