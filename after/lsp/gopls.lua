-- gopls: stricter formatting and analysis than its defaults. Imports are
-- organized by goimports before gopls formats (conform, plugins.lua).

return {
    settings = {
        gopls = {
            gofumpt = true,
            staticcheck = true,
            analyses = {
                unusedparams = true,
                unusedvariable = true,
            },
            -- Shown only while `<Leader>oh` has inlay hints on.
            hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                compositeLiteralTypes = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
            },
        },
    },
}
