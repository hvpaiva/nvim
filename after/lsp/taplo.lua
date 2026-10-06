-- taplo: TOML formatting (through conform) and validation. taplo 0.10 cannot
-- parse SchemaStore's current catalog format and validates nothing on its
-- own, so the TOML entries of SchemaStore.nvim's catalog (Cargo.toml,
-- pyproject.toml, ...) are handed to it as explicit associations. The catalog
-- loads when the server starts, not with the editor.

-- SchemaStore file globs to the regexes taplo matches against the file path.
local function glob_to_regex(glob)
    local regex = glob:gsub("^%*%*/", ""):gsub("[%^%$%(%)%.%[%]%+%{%}%|\\]", "\\%0")
    regex = regex:gsub("%*%*/", "\0"):gsub("%*", "[^/]*"):gsub("%?", "[^/]"):gsub("%z", "(.*/)?")
    return "(^|/)" .. regex .. "$"
end

return {
    settings = {
        evenBetterToml = {
            schema = { enabled = true, catalogs = {}, associations = {} },
        },
    },
    before_init = function(_, config)
        local associations = config.settings.evenBetterToml.schema.associations
        for _, schema in ipairs(require("schemastore").json.schemas()) do
            for _, glob in ipairs(schema.fileMatch or {}) do
                if glob:match("%.toml$") then
                    associations[glob_to_regex(glob)] = schema.url
                end
            end
        end
    end,
}
