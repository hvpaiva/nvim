-- ruby-lsp: run under the project's Ruby, tuned for mini.completion.
-- Formatting is owned by conform.nvim (lua/ruby_tools.lua picks Standard or
-- RuboCop per project); ruby-lsp is told to stay out of it.
local ruby = require("ruby_tools")

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
        -- Off by default upstream; shown only while `<Leader>oh` has them on.
        featuresConfiguration = {
            inlayHint = { implicitRescue = true, implicitHashValue = true },
        },
    },
    -- ruby-lsp only detects RuboCop on its own. Standard projects get the
    -- Standard add-on (it ships in the standard gem); projects whose bundle
    -- lacks their linter get none here and are linted by nvim-lint instead.
    before_init = function(params, config)
        if config.root_dir then
            local linters = ruby.lint_plan(config.root_dir .. "/Gemfile").linters
            if linters then
                params.initializationOptions.linters = linters
            end
        end
    end,
    -- Client-side commands behind ruby-lsp's test code lenses (`gl`).
    commands = {
        ["rubyLsp.runTest"] = ruby.run_test_lens,
        ["rubyLsp.runTestInTerminal"] = ruby.run_test_lens,
        ["rubyLsp.debugTest"] = ruby.debug_test_lens,
    },
}
