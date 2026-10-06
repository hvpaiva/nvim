-- vscode-json-language-server ships no schemas outside VS Code, where the
-- extensions provide them. SchemaStore.nvim brings the catalog yamlls already
-- uses, so package.json, tsconfig.json, .eslintrc and the rest validate. The
-- catalog loads when the server starts, not with the editor.

return {
    settings = {
        json = {
            schemas = {},
            validate = { enable = true },
        },
    },
    -- `settings` is the table the client serves, so assign into it.
    before_init = function(_, config)
        config.settings.json.schemas = require("schemastore").json.schemas()
    end,
}
