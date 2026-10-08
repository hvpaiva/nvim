-- Native LSP defaults in 0.11+ provide: K (hover), grn (rename),
-- gra (code action), grr (references), gri (implementation),
-- grt (type definition), gO (document symbol), <C-]>, <C-w>d
-- (diagnostic float). See `:h lsp-defaults`.

vim.diagnostic.config({
    severity_sort = true,
    virtual_text = false,
    float = { border = "rounded", source = "if_many" },
    underline = { severity = vim.diagnostic.severity.ERROR },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
        },
    },
})

local function inserts_before_replacements(text_edits)
    local ordered = {}
    for index, edit in ipairs(text_edits) do
        ordered[index] = { edit = edit, index = index }
    end
    local function is_insert(edit)
        return vim.deep_equal(edit.range.start, edit.range["end"])
    end
    table.sort(ordered, function(a, b)
        local sa, sb = a.edit.range.start, b.edit.range.start
        if sa.line ~= sb.line then
            return sa.line < sb.line
        end
        if sa.character ~= sb.character then
            return sa.character < sb.character
        end
        local ia, ib = is_insert(a.edit), is_insert(b.edit)
        if ia ~= ib then
            return ia
        end
        return a.index < b.index
    end)
    return vim.tbl_map(function(entry)
        return entry.edit
    end, ordered)
end

local apply_text_edits = vim.lsp.util.apply_text_edits
vim.lsp.util.apply_text_edits = function(text_edits, ...)
    return apply_text_edits(inserts_before_replacements(text_edits or {}), ...)
end

-- mini.completion already extends the default client capabilities with the
-- completion/signature features it implements, so use the result directly.
vim.lsp.config("*", { capabilities = require("mini.completion").get_lsp_capabilities() })

-- Per-server tuning lives in `after/lsp/<name>.lua` (see `after/lsp/lua_ls.lua`).
-- Code lenses and on-type formatting are enabled per server in autocmds.lua.

vim.lsp.enable({
    "lua_ls",
    "marksman",
    "gopls",
    "hls",
    "rust_analyzer",
    -- Ruby: Solargraph infers types ruby-lsp does not and answers through it
    -- (after/lsp/{ruby_lsp,solargraph}.lua).
    "ruby_lsp",
    "solargraph",
    "helm_ls",
    "yamlls",
    "jsonls",
    "bashls",
    "gh_actions_ls",
    "docker_language_server",
    -- TypeScript 7's native language server (`tsc --lsp`). ts_ls needs a
    -- TypeScript older than 7, which ships no tsserver anymore.
    "tsc",
    -- Attaches only where the project has an ESLint config.
    "eslint",
    -- Python: basedpyright for types, ruff for lint, imports and formatting
    -- (after/lsp/{basedpyright,ruff}.lua split the overlap).
    "basedpyright",
    "ruff",
    "terraformls",
    "tflint",
    "taplo",
})
