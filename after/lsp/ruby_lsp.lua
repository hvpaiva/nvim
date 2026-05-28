-- ruby-lsp: tuned for editing Ruby with mini.completion.
-- Formatting is owned by conform.nvim (standardrb / rubocop fallback);
-- ruby-lsp itself is told to stay out of formatting to avoid ambiguity.

return {
    on_attach = function(client, _)
        -- Drop the noisy default trigger chars; keep the ones that actually
        -- mean "open menu" in Ruby:
        --   .   method call
        --   :   symbols and constants (`Foo::Bar`)
        --   (   call
        client.server_capabilities.completionProvider.triggerCharacters = { ".", ":", "(" }
    end,
    settings = {
        rubyLsp = { formatter = "none" },
    },
}
