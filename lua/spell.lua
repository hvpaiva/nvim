-- ============================================================================
-- Spell files
-- ============================================================================
-- Markdown spell-checks against en, pt and two generated word lists (see
-- after/ftplugin/markdown.lua): `programming`, compiled from vim-dirtytalk's
-- jargon lists, and `custom`, from spell/custom.words in this repo. Neither
-- exists anywhere to download, so they are built here: before a markdown
-- buffer uses them, whenever one is missing or older than its sources
-- (M.ensure), and on demand (`:DirtytalkUpdate`, saving custom.words). Other
-- languages are downloaded from the Vim mirror without asking, so a fresh
-- machine needs no manual step.
local M = {}

local spell_dir = vim.fn.stdpath("data") .. "/site/spell"
local custom_words = vim.fn.stdpath("config") .. "/spell/custom.words"
local dirtytalk_lists = vim.fn.stdpath("data") .. "/site/pack/core/opt/vim-dirtytalk/wordlists"

local function compile(name, words)
    if #words == 0 then
        vim.notify("No words to compile into the " .. name .. " spell file", vim.log.levels.WARN)
        return
    end
    local tmp = vim.fn.tempname()
    vim.fn.writefile(words, tmp)
    vim.fn.mkdir(spell_dir, "p")
    vim.cmd("silent mkspell! " .. vim.fn.fnameescape(spell_dir .. "/" .. name) .. " " .. vim.fn.fnameescape(tmp))
    vim.fn.delete(tmp)
end

local build = {}
local sources = {
    programming = function()
        return vim.fn.glob(dirtytalk_lists .. "/*.words", true, true)
    end,
    custom = function()
        return { custom_words }
    end,
}

-- vim-dirtytalk's own :DirtytalkUpdate calls `spellfile#WritableSpellDir`,
-- which Neovim 0.12 removed when porting spellfile.vim to Lua.
function build.programming()
    local blacklist = vim.tbl_map(tostring, vim.g.dirtytalk_blacklist or {})
    local words = {}
    for _, file in ipairs(sources.programming()) do
        if not vim.tbl_contains(blacklist, vim.fn.fnamemodify(file, ":t:r")) then
            vim.list_extend(words, vim.fn.readfile(file))
        end
    end
    compile("programming", words)
end

-- One word per line; blank lines and `#` comments are skipped.
function build.custom()
    local words = {}
    for _, line in ipairs(vim.fn.readfile(custom_words)) do
        local word = vim.trim(line)
        if word ~= "" and not word:match("^#") then
            words[#words + 1] = word
        end
    end
    compile("custom", words)
end

--- Builds `name` ("programming" or "custom") when its spell file is missing or
--- older than its sources. SpellFileMissing alone is not enough: Vim also
--- loads spell/custom.utf-8.add.spl (the `zg` list in this repo), and then
--- treats `custom` as found.
function M.ensure(name)
    local built = vim.fn.getftime(spell_dir .. "/" .. name .. ".utf-8.spl")
    for _, source in ipairs(sources[name]()) do
        if vim.fn.getftime(source) > built then
            build[name]()
            return
        end
    end
end

-- Neovim's own handler (plugin/spellfile.lua, sourced after this file) would
-- offer to download `programming` and `custom` from the Vim mirror, which has
-- neither, on every session.
vim.g.loaded_spellfile_plugin = true
require("nvim.spellfile").config({ confirm = false })

vim.api.nvim_create_autocmd("SpellFileMissing", {
    group = vim.api.nvim_create_augroup("hvpaiva-spellfile", { clear = true }),
    desc = "Build the generated word lists, download the others",
    callback = function(ev)
        if build[ev.match] then
            build[ev.match]()
        else
            require("nvim.spellfile").get(ev.match)
        end
    end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("hvpaiva-custom-spell", { clear = true }),
    pattern = custom_words,
    desc = "Recompile the custom spell file",
    callback = build.custom,
})

vim.api.nvim_create_user_command("CustomSpellUpdate", build.custom, {
    desc = "Compile ~/.config/nvim/spell/custom.words into custom.utf-8.spl",
})

-- The plugin's `plugin/dirtytalk.vim` is sourced at VimEnter by vim.pack and
-- defines its own :DirtytalkUpdate; replace it afterwards.
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("hvpaiva-dirtytalk", { clear = true }),
    callback = function()
        vim.schedule(function()
            vim.api.nvim_create_user_command("DirtytalkUpdate", build.programming, {
                force = true,
                desc = "Compile vim-dirtytalk wordlists into programming.utf-8.spl",
            })
        end)
    end,
})

return M
