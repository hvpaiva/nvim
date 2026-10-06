-- terraform-ls: its "N references" code lenses run `client.showReferences`,
-- which the client implements (lspconfig declares the command id).

return {
    commands = {
        ["client.showReferences"] = require("lenses").show_references,
    },
}
