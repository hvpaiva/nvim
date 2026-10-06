-- basedpyright: types, completion and navigation for Python. Imports are
-- organized by ruff (after/lsp/ruff.lua), which also reports unused imports
-- and variables (F401, F841): basedpyright's copies are turned off so each
-- shows once.

return {
    settings = {
        basedpyright = {
            disableOrganizeImports = true,
            analysis = {
                diagnosticSeverityOverrides = {
                    reportUnusedImport = "none",
                    reportUnusedVariable = "none",
                },
            },
        },
    },
    -- Resolve imports against the project's virtualenv: Neovim's PATH holds
    -- whatever Python it was started with. The debugger does the same
    -- (lua/debugging.lua).
    before_init = function(_, config)
        local venv = config.root_dir and config.root_dir .. "/.venv/bin/python"
        if venv and vim.fn.executable(venv) == 1 then
            config.settings.python = vim.tbl_deep_extend("force", config.settings.python or {}, { pythonPath = venv })
        end
    end,
}
