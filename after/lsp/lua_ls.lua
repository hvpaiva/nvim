-- Lua LSP (LuaLS) — tuned for editing Neovim config.
-- Source: https://github.com/LuaLS/lua-language-server

return {
    on_attach = function(client, _)
        -- LuaLS reports ~10 trigger characters by default; mini.completion
        -- reacts to each one, which makes the popup flicker on whitespace and
        -- quotes. Keep only the ones that meaningfully indicate "open menu".
        client.server_capabilities.completionProvider.triggerCharacters = { ".", ":", "#", "(" }
    end,
    settings = {
        Lua = {
            -- Neovim ships with LuaJIT, not stock Lua 5.x.
            runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
            workspace = {
                -- Skip submodules to avoid scanning vendored code.
                ignoreSubmodules = true,
                -- Make Neovim's runtime APIs (vim.api, vim.lsp, etc.) known to
                -- the server so hover and completion work on config code.
                library = { vim.env.VIMRUNTIME },
            },
        },
    },
}
