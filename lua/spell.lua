-- ============================================================================
-- Spell-related commands
-- ============================================================================
-- vim-dirtytalk ships wordlists for programming jargon (languages, tooling,
-- acronyms). The plugin's own `:DirtytalkUpdate` calls
-- `spellfile#WritableSpellDir`, which Neovim 0.12 removed when porting
-- `spellfile.vim` to Lua. We override the command with a Lua reimplementation
-- that compiles `wordlists/*.words` straight into
-- `stdpath('data')/site/spell/programming.utf-8.spl`.
--
-- The override must run on `VimEnter`: `vim.pack.add` defers sourcing the
-- plugin's `plugin/dirtytalk.vim` until then, so anything registered inline can
-- be clobbered by the plugin's `command!` definition.
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("hvpaiva-dirtytalk", { clear = true }),
    callback = function()
        vim.schedule(function()
            vim.api.nvim_create_user_command("DirtytalkUpdate", function()
                local data_dir = vim.fn.stdpath("data")
                local plugin_dir = data_dir .. "/site/pack/core/opt/vim-dirtytalk"
                local files = vim.fn.glob(plugin_dir .. "/wordlists/*.words", true, true)
                local blacklist = vim.tbl_map(tostring, vim.g.dirtytalk_blacklist or {})
                local words = {}

                for _, file in ipairs(files) do
                    local name = vim.fn.fnamemodify(file, ":t:r")
                    if not vim.tbl_contains(blacklist, name) then
                        vim.list_extend(words, vim.fn.readfile(file))
                    end
                end

                local tmp = vim.fn.tempname()
                vim.fn.writefile(words, tmp)

                local spell_dir = data_dir .. "/site/spell"
                vim.fn.mkdir(spell_dir, "p")
                vim.cmd(
                    "mkspell! "
                        .. vim.fn.fnameescape(spell_dir .. "/programming")
                        .. " "
                        .. vim.fn.fnameescape(tmp)
                )
                vim.fn.delete(tmp)
            end, { desc = "Compile vim-dirtytalk wordlists into programming.utf-8.spl" })
        end)
    end,
})

-- :CustomSpellUpdate compiles `~/.config/nvim/spell/custom.words` (one word
-- per line, `#` comments) into `custom.utf-8.spl`. Run this after editing the
-- wordlist; the `custom` entry in `spelllang` (see `after/ftplugin/markdown.lua`)
-- then picks the result up on the next buffer reload.
vim.api.nvim_create_user_command("CustomSpellUpdate", function()
    local src = vim.fn.stdpath("config") .. "/spell/custom.words"
    if vim.fn.filereadable(src) == 0 then
        vim.notify("custom.words not found at " .. src, vim.log.levels.ERROR)
        return
    end

    local words = {}
    for _, line in ipairs(vim.fn.readfile(src)) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^#") then
            table.insert(words, trimmed)
        end
    end

    local tmp = vim.fn.tempname()
    vim.fn.writefile(words, tmp)

    local spell_dir = vim.fn.stdpath("data") .. "/site/spell"
    vim.fn.mkdir(spell_dir, "p")
    vim.cmd(
        "mkspell! " .. vim.fn.fnameescape(spell_dir .. "/custom") .. " " .. vim.fn.fnameescape(tmp)
    )
    vim.fn.delete(tmp)
end, { desc = "Compile ~/.config/nvim/spell/custom.words into custom.utf-8.spl" })
