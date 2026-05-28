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
            diagnostics = {
                -- mini.* modules expose globals (MiniFiles, MiniMisc, etc.)
                -- that LuaLS otherwise reports as undefined when editing
                -- this config.
                globals = {
                    "vim",
                    "MiniBufremove",
                    "MiniClue",
                    "MiniCompletion",
                    "MiniDiff",
                    "MiniExtra",
                    "MiniFiles",
                    "MiniMisc",
                    "MiniNotify",
                    "MiniPick",
                    "MiniSessions",
                    "MiniSnippets",
                    "MiniVisits",
                },
            },
            workspace = {
                -- Skip submodules to avoid scanning vendored code.
                ignoreSubmodules = true,
                checkThirdParty = false,
                -- Make Neovim's runtime + installed plugins known to the
                -- server so hover and completion work on config code.
                library = vim.api.nvim_get_runtime_file("", true),
            },
        },
    },
}
