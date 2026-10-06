-- ruff: lint, import sorting and formatting for Python (conform runs
-- `ruff_organize_imports` and `ruff_format`). Hover belongs to basedpyright.

return {
    on_attach = function(client, _)
        client.server_capabilities.hoverProvider = false
    end,
}
