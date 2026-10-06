-- nvim-treesitter `main` branch: highlighting and folds are opt-in per buffer
-- via `vim.treesitter.start`. We do that on `FileType` for any filetype Neovim
-- can map to a parser, wrapped in `pcall` so unknown or uninstalled parsers
-- fail silent.
local treesitter = require("nvim-treesitter")

local ensure_installed = {
    "awk",
    "bash",
    "c",
    "css",
    "diff",
    "dockerfile",
    "dtd",
    "fish",
    "git_config",
    "git_rebase",
    "gitattributes",
    "gitcommit",
    "gitignore",
    "go",
    "gomod",
    "gosum",
    "gotmpl",
    "gowork",
    "haskell",
    "hcl",
    "helm",
    "html",
    "http",
    "hyprlang",
    "javascript",
    "jsdoc",
    "jq",
    "json",
    "json5",
    "just",
    "lua",
    "luadoc",
    "luap",
    "markdown",
    "markdown_inline",
    "nix",
    "printf",
    "python",
    "query",
    "rbs",
    "regex",
    "ron",
    "ruby",
    "rust",
    "sql",
    "terraform",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "xml",
    "yaml",
}

treesitter.install(ensure_installed)

-- Compound filetypes from options.lua: Helm values and Compose files are YAML,
-- Docker Bake files HCL.
vim.treesitter.language.register("yaml", { "yaml.helm-values", "yaml.docker-compose" })
vim.treesitter.language.register("hcl", "hcl.docker-bake")

local ts_foldexpr = "v:lua.vim.treesitter.foldexpr()"

-- Window-local fold options outlive the buffer that set them: a buffer without
-- a parser shown in a window that held one with a parser would keep the
-- tree-sitter foldexpr and get no folds at all.
local function default_folds(buf)
    vim.api.nvim_buf_call(buf, function()
        if vim.wo.foldexpr == ts_foldexpr then
            vim.opt_local.foldmethod = vim.go.foldmethod
            vim.opt_local.foldexpr = vim.go.foldexpr
        end
    end)
end

-- `vim.treesitter.start` clears 'syntax'. Vim's Ruby and shell indent scripts
-- read synID() to leave string and heredoc bodies alone, so without the regex
-- syntax underneath `=` reindents them and changes the string's value. These
-- filetypes keep it loaded; tree-sitter still owns the highlighting.
local regex_syntax_for_indent = { ruby = true, sh = true, bash = true }

vim.api.nvim_create_autocmd("FileType", {
    pattern = "*",
    callback = function(args)
        local buf = args.buf
        local ft = vim.bo[buf].filetype

        -- `language.add` returns nil (it does not raise) when no parser exists.
        local lang = vim.treesitter.language.get_lang(ft)
        local ok_add, added = pcall(vim.treesitter.language.add, lang or "")
        if not lang or not ok_add or not added then
            default_folds(buf)
            return
        end

        if pcall(vim.treesitter.start, buf, lang) and regex_syntax_for_indent[ft] then
            vim.bo[buf].syntax = "ON"
        end

        -- Tree-sitter folds wherever the parser is available; filetypes without
        -- one keep the global `indent` method (default_folds above). Markdown
        -- sets its own in after/ftplugin/markdown.lua.
        if ft ~= "markdown" then
            vim.api.nvim_buf_call(buf, function()
                vim.opt_local.foldmethod = "expr"
                vim.opt_local.foldexpr = ts_foldexpr
            end)
        end
    end,
})
