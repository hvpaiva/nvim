-- ruby-lsp: run under the project's Ruby, tuned for mini.completion.
-- Formatting is owned by conform.nvim (lua/ruby_tools.lua picks Standard or
-- RuboCop per project); ruby-lsp is told to stay out of it.
local launcher = vim.fn.stdpath("config") .. "/scripts/nvim-ruby-lsp"

return {
    -- Neovim's PATH holds the Ruby it was started with; Bundler refuses to run
    -- a project whose Gemfile pins another one, and ruby-lsp's C extensions
    -- only load in the Ruby they were built for. `mise x` resolves the Ruby
    -- from the project directory, and the launcher installs ruby-lsp into it
    -- when missing.
    cmd = function(dispatchers, config)
        local cwd = config.cmd_cwd or config.root_dir
        local argv = vim.fn.executable("mise") == 1 and { "mise", "x", "--", launcher } or { launcher }
        return vim.lsp.rpc.start(argv, dispatchers, cwd and { cwd = cwd } or nil)
    end,
    on_attach = function(client, _)
        -- Drop the noisy default trigger chars; keep the ones that actually
        -- mean "open menu" in Ruby:
        --   .   method call
        --   :   symbols and constants (`Foo::Bar`)
        --   (   call
        if client.server_capabilities.completionProvider then
            client.server_capabilities.completionProvider.triggerCharacters = { ".", ":", "(" }
        end
    end,
    init_options = {
        formatter = "none",
    },
}
