-- Solargraph next to ruby-lsp, for the types it infers (see the merge in
-- lua/ruby_tools.lua). Neovim asks it for completion and type definition;
-- hover, definition, signature help, rename, references and workspace symbols
-- reach it through ruby-lsp. Diagnostics, formatting and the rest stay with
-- ruby-lsp, nvim-lint and conform.
local ruby = require("ruby_tools")

-- Read at startup and again from the settings Neovim sends right after,
-- which would otherwise carry nvim-lspconfig's `diagnostics = true`. The
-- requests ruby-lsp forwards are answered whatever these say.
local features = {
    completion = true,
    typeDefinitions = true,
    hover = false,
    definitions = false,
    references = false,
    rename = false,
    symbols = false,
    diagnostics = false,
    formatting = false,
    autoformat = false,
    folding = false,
    highlights = false,
}

return {
    root_dir = ruby.lsp_root,
    cmd = ruby.lsp_cmd("nvim-solargraph"),
    filetypes = { "ruby" },
    init_options = features,
    settings = { solargraph = features },
    on_init = function(client)
        ruby.limit_solargraph(client)
        ruby.complete_in_bytes(client)
    end,
    on_attach = function(client, _)
        -- The same menu triggers as ruby-lsp's, without `(`: Solargraph
        -- offers every name in scope there.
        if client.server_capabilities.completionProvider then
            client.server_capabilities.completionProvider.triggerCharacters = { ".", ":" }
        end
    end,
}
