return {
    filetypes = { "haskell", "lhaskell", "cabal" },
    settings = {
        haskell = {
            cabalFormattingProvider = "cabal-gild",
            -- HLS advertises semantic tokens but answers every request with
            -- "no plugins available" until its plugin is turned on.
            plugin = { semanticTokens = { globalOn = true } },
        },
    },
}
