-- 'formatexpr' for every buffer. conform formats a range with the buffer's
-- formatters (or its language server) but never hands back to Vim's own text
-- formatting, so through conform alone `gq` would never wrap a comment or a
-- paragraph. Here `gq{motion}` wraps prose, comment-only ranges and buffers
-- nothing formats, and formats code everywhere else. `gQ` (keymaps.lua) always
-- runs the formatters on the whole buffer; `gw` always wraps.
local M = {}

M.option = "v:lua.require'formatexpr'.expr()"

local prose = { markdown = true, ["markdown.mdx"] = true, gitcommit = true, text = true, mail = true }

local function comment_leader()
    local leader = vim.bo.commentstring:match("^(.-)%%s")
    leader = leader and vim.trim(leader)
    return leader ~= "" and leader or nil
end

--- Whether every non-blank line from `first` to `last` is a line comment.
function M.only_comments(first, last)
    local leader = comment_leader()
    if not leader then
        return false
    end
    local pattern = "^%s*" .. vim.pesc(leader)
    local any = false
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, first - 1, last, false)) do
        if line:match("%S") then
            if not line:match(pattern) then
                return false
            end
            any = true
        end
    end
    return any
end

--- Returning 1 makes Vim format the lines itself (`:h 'formatexpr'`).
function M.expr()
    if vim.fn.mode():match("^[iR]") then
        return 1
    end
    local first = vim.v.lnum
    if prose[vim.bo.filetype] or M.only_comments(first, first + vim.v.count - 1) then
        return 1
    end
    local formatters, lsp = require("conform").list_formatters_to_run(0)
    if #formatters == 0 and not lsp then
        return 1
    end
    return require("conform").formatexpr()
end

return M
