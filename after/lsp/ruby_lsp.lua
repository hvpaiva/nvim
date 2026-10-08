-- ruby-lsp: run under the project's Ruby, tuned for mini.completion.
-- Formatting is owned by conform.nvim (lua/ruby_tools.lua picks Standard or
-- RuboCop per project); ruby-lsp is told to stay out of it. Solargraph runs
-- next to it (after/lsp/solargraph.lua) and answers through it.
local ruby = require("ruby_tools")

return {
    root_dir = ruby.lsp_root,
    cmd = ruby.lsp_cmd("nvim-ruby-lsp"),
    on_init = function(client)
        ruby.merge_solargraph(client)
        ruby.complete_after_trigger(client)
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
        ruby.enable_on_type()
    end,
    init_options = {
        formatter = "none",
        -- Off by default upstream; shown only while `<Leader>oh` has them on.
        featuresConfiguration = {
            inlayHint = { implicitRescue = true, implicitHashValue = true },
        },
        -- In a workspace without subdirectories ruby-lsp's `{dirs}/**/*.rb`
        -- becomes `{}/**/*.rb`, which globs every top-level file a second
        -- time as `root//file.rb`; this drops those copies.
        indexing = { excludedPatterns = { "{}/**/*.rb" } },
        -- Test lenses for Minitest and test-unit with or without a bundle
        -- (see ruby_tools.lua).
        enabledFeatureFlags = { fullTestDiscovery = true },
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
