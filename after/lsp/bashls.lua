-- bash-language-server: indexes the files matching `globPattern` for
-- cross-file definitions, references and workspace symbols (functions in a
-- sourced `lib/*.sh`). lspconfig narrows the upstream default to the root's
-- top level so a script opened straight in $HOME does not scan the whole
-- home; inside a real project, index the whole tree.
-- Diagnostics come from ShellCheck (its optional checks live in
-- ~/.config/shellcheckrc, shared with the CLI); formatting is conform + shfmt.

return {
    -- `settings` is the table the client serves to the server, so a nested
    -- field set here is what bash-language-server reads.
    before_init = function(_, config)
        local root = config.root_dir
        if root and root ~= vim.uv.os_homedir() then
            config.settings.bashIde.globPattern = "**/*@(.sh|.inc|.bash|.command)"
        end
    end,
}
