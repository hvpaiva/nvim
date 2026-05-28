-- ============================================================================
-- Theme, palette, and mode-dependent highlights
-- ============================================================================
-- All theme-shaped state lives here: monokai-pro overrides, the post-colorscheme
-- transparency pass, and the per-mode `ModeMsg` palette consumed by the
-- `ModeChanged` autocmd below. Keeping it together means tuning a color does
-- not require hopping between `plugins.lua` and `autocmds.lua`.

local accent = "#DF782D"

-- monokai-pro ristretto filter. Minimal palette overrides:
--   EndOfBuffer dimmed so the trailing `~` does not draw attention
--   Directory in warm orange, no background
--   Float borders in warm orange so they survive the transparency layer below
--   Ruby keyword variants linked to @keyword for visual consistency
require("monokai-pro").setup({
    filter = "ristretto",
    override = function()
        return {
            EndOfBuffer = { fg = "#72696a" },
            Directory = { fg = accent, bg = "none" },
            CursorLineNr = { fg = accent, bold = true },
            -- Float borders and titles: warm orange, transparent bg. Most
            -- `Mini*Title` groups link to `FloatTitle`, so overriding it covers
            -- mini.notify, mini.clue, mini.cmdline-peek, mini.pick prompt, and
            -- the bare `nvim_open_win({title=...})` used by MiniMisc.zoom.
            -- mini.files defines its title directly (not via link), so it
            -- still needs explicit overrides.
            FloatBorder = { fg = accent, bg = "none" },
            FloatTitle = { fg = accent, bg = "none" },
            MiniFilesBorder = { fg = accent, bg = "none" },
            MiniFilesTitle = { fg = accent, bg = "none" },
            MiniFilesTitleFocused = { fg = accent, bg = "none", bold = true },
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

-- Transparent backgrounds: editor + floats. Lets the terminal background
-- (wallpaper, blur, etc.) show through. Re-applied on every colorscheme.
local function transparent()
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
        "MiniFilesNormal",
        "MiniFilesBorder",
        "MiniFilesTitle",
        "MiniFilesTitleFocused",
    }) do
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        hl.bg = "none"
        vim.api.nvim_set_hl(0, group, hl)
    end
end
transparent()
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("hvpaiva-transparency", { clear = true }),
    callback = transparent,
})

-- Colorize the `--MODE--` indicator in the cmdline (showmode) per mode.
-- The default `ModeMsg` highlight is a flat gray; we rewrite it on every
-- `ModeChanged` so Insert/Visual/Replace etc. each get a distinct color.
-- Palette picked to harmonize with the monokai-pro ristretto filter.
local mode_colors = {
    i = "#5AD4E6", -- Insert      → cyan
    v = "#948AE3", -- Visual      → magenta
    V = "#948AE3", -- Visual line → magenta
    ["\22"] = "#948AE3", -- Visual block (^V)
    R = "#F38BA8", -- Replace     → red/pink
    c = "#F9CC6C", -- Command     → orange
    t = "#7BD88F", -- Terminal    → green
    s = "#948AE3", -- Select
    S = "#948AE3",
    ["\19"] = "#948AE3", -- Select block (^S)
    o = "#FFD866", -- Operator-pending → yellow
}
vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("hvpaiva-modecolor", { clear = true }),
    desc = "Colorize --MODE-- per current mode",
    callback = function()
        local mode = vim.api.nvim_get_mode().mode
        local color = mode_colors[mode] or mode_colors[mode:sub(1, 1)] or "#FFF1F3"
        vim.api.nvim_set_hl(0, "ModeMsg", { fg = color, bold = true })
    end,
})
