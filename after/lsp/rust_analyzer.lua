-- rust-analyzer: tuned for editing Rust with mini.completion.
local rust = require("rust_tools")

return {
    -- Client-side commands behind the code lenses (`gl`): run a test or binary
    -- in the test terminal, debug it with codelldb, list references.
    commands = {
        ["rust-analyzer.runSingle"] = rust.run,
        ["rust-analyzer.debugSingle"] = rust.debug,
        ["rust-analyzer.showReferences"] = require("lenses").show_references,
    },
    on_attach = function(client, _)
        -- Cut the default trigger list (which includes whitespace-ish chars)
        -- down to the ones that meaningfully indicate "open menu".
        --   .   method / field access
        --   :   path (`std::`) and turbofish prefix
        --   <   turbofish (`::<T>`) and generic bounds
        --   (   call
        client.server_capabilities.completionProvider.triggerCharacters = { ".", ":", "<", "(" }
    end,
    settings = {
        ["rust-analyzer"] = {
            -- Use clippy on save instead of `cargo check` so idiomatic lints
            -- show up as diagnostics in the buffer.
            check = { command = "clippy" },
        },
    },
}
