-- rust-analyzer — tuned for editing Rust with mini.completion.

return {
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
