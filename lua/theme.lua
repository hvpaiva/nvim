-- ============================================================================
-- Theme, palette, and mode-dependent highlights
-- ============================================================================
-- All theme-shaped state lives here: monokai-pro overrides, the post-colorscheme
-- transparency pass, and the per-mode `ModeMsg` palette consumed by the
-- `ModeChanged` autocmd below. Keeping it together means tuning a color does
-- not require hopping between `plugins.lua` and `autocmds.lua`.

local accent = "#DF782D"

-- Follow the Omarchy desktop theme (lua/omarchy_theme.lua reads the current
-- theme's neovim.lua and applies its colorscheme). Set `follow_omarchy = false`
-- to go back to the monokai-pro setup below unconditionally; the original file
-- is kept as theme.lua.bak-omarchy.
local follow_omarchy = true
local omarchy_applied = follow_omarchy and require("omarchy_theme").load()

-- monokai-pro ristretto filter, used when no Omarchy theme applies. Minimal
-- palette overrides:
--   Directory in warm orange, no background
--   Float borders in warm orange so they survive the transparency layer below
--   Ruby keyword variants linked to @keyword for visual consistency
if not omarchy_applied then
    require("monokai-pro").setup({
        filter = "ristretto",
        override = function()
            return {
                Directory = { fg = accent, bg = "none" },
                CursorLineNr = { fg = accent, bold = true },
                -- Float borders and titles: warm orange, transparent bg. Most
                -- `Mini*Title` groups link to `FloatTitle`, so overriding it covers
                -- mini.notify, mini.clue, mini.cmdline-peek, mini.pick prompt, and
                -- the bare `nvim_open_win({title=...})` used by MiniMisc.zoom.
                FloatBorder = { fg = accent, bg = "none" },
                FloatTitle = { fg = accent, bg = "none" },
                MiniPickBorder = { fg = accent, bg = "none" },
                -- Highlight the characters in each result that the query matched.
                -- Default monokai-pro shade is too muted to pop on the ristretto bg.
                MiniPickMatchRanges = { fg = accent, bold = true },
                MiniPickMatchCurrent = { bg = "#403838", bold = true },
                MiniPickMatchMarked = { fg = "#FFD866", italic = true },
                MiniNotifyBorder = { fg = accent, bg = "none" },
                MiniClueBorder = { fg = accent, bg = "none" },
                ["@keyword.function.ruby"] = { link = "@keyword" },
                ["@keyword.type.ruby"] = { link = "@keyword" },
            }
        end,
    })
    vim.cmd.colorscheme("monokai-pro")
end

-- Transparent backgrounds: editor + floats. Lets the terminal background
-- (wallpaper, blur, etc.) show through. Re-applied on every colorscheme.
local function transparent()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local fg = vim.api.nvim_get_hl(0, { name = "LineNr", link = false }).fg or normal.fg or 0x808080
    local bg = normal.bg or (vim.o.background == "light" and 0xFFFFFF or 0x000000)
    local eob = 0
    for shift = 0, 16, 8 do
        local channel_fg = math.floor(fg / 2 ^ shift) % 256
        local channel_bg = math.floor(bg / 2 ^ shift) % 256
        eob = eob + math.floor(channel_bg + (channel_fg - channel_bg) * 0.55 + 0.5) * 2 ^ shift
    end

    for _, group in ipairs({
        "Normal",
        "NormalNC",
        "EndOfBuffer",
        "SignColumn",
        "LineNr",
        "CursorLineNr",
        "FoldColumn",
        "Folded",
        "NormalFloat",
        "FloatBorder",
        "Pmenu",
        -- Note: `PmenuSel` and `MiniPickMatchCurrent` are intentionally *not*
        -- listed; the current-row indicator needs a bg, otherwise the
        -- completion/picker selection is invisible.
        "MiniPickBorder",
        "MiniPickNormal",
        "MiniPickPrompt",
        "MiniNotifyNormal",
        "MiniNotifyBorder",
        "MiniNotifyTitle",
    }) do
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        hl.bg = "none"
        vim.api.nvim_set_hl(0, group, hl)
    end
    vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = eob })
end
transparent()
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("hvpaiva-transparency", { clear = true }),
    callback = transparent,
})

-- mini.snippets marks every tabstop with a double underline by default. Keep a
-- faint background on the current tabstop and clear the rest. The backgrounds
-- come from the colorscheme (Visual, DiffDelete for a pending replace), with the
-- ristretto values as the fallback. Reapplied on `ColorScheme` since
-- mini.snippets re-asserts its defaults there.
local function hl_bg(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false }).bg
end

local function snippet_hl()
    local visual = hl_bg("Visual")
    vim.api.nvim_set_hl(0, "MiniSnippetsCurrent", { bg = visual or "#403838" })
    vim.api.nvim_set_hl(0, "MiniSnippetsCurrentReplace", { bg = hl_bg("DiffDelete") or visual or "#4a3636" })
    vim.api.nvim_set_hl(0, "MiniSnippetsVisited", {})
    vim.api.nvim_set_hl(0, "MiniSnippetsUnvisited", {})
    vim.api.nvim_set_hl(0, "MiniSnippetsFinal", {})
end
snippet_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("hvpaiva-snippet-hl", { clear = true }),
    callback = snippet_hl,
})

-- Colorize the `--MODE--` indicator in the cmdline (showmode) per mode.
-- The default `ModeMsg` highlight is a flat gray; we rewrite it on every
-- `ModeChanged` so Insert/Visual/Replace etc. each get a distinct color.
-- Each mode takes a terminal palette slot, read from the colorscheme's
-- `terminal_color_N` so it follows the Omarchy theme. The hex values, picked for
-- the monokai-pro ristretto filter, cover schemes that set no terminal colors.
local mode_colors = {
    i = { 6, "#5AD4E6" }, -- Insert      → cyan
    v = { 5, "#948AE3" }, -- Visual      → magenta
    V = { 5, "#948AE3" }, -- Visual line → magenta
    ["\22"] = { 5, "#948AE3" }, -- Visual block (^V)
    R = { 1, "#F38BA8" }, -- Replace     → red
    c = { 3, "#F9CC6C" }, -- Command     → yellow
    t = { 2, "#7BD88F" }, -- Terminal    → green
    s = { 5, "#948AE3" }, -- Select
    S = { 5, "#948AE3" },
    ["\19"] = { 5, "#948AE3" }, -- Select block (^S)
    o = { 3, "#FFD866" }, -- Operator-pending → yellow
}
vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("hvpaiva-modecolor", { clear = true }),
    desc = "Colorize --MODE-- per current mode",
    callback = function()
        local mode = vim.api.nvim_get_mode().mode
        local entry = mode_colors[mode] or mode_colors[mode:sub(1, 1)]
        local color = entry and (vim.g["terminal_color_" .. entry[1]] or entry[2]) or "#FFF1F3"
        vim.api.nvim_set_hl(0, "ModeMsg", { fg = color, bold = true })
    end,
})
