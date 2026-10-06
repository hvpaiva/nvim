-- Client-side commands shared by the code lenses `gl` runs (which servers
-- show lenses at all is decided in autocmds.lua).
local M = {}

--- Runs a shell line through vim-test's strategy and project transformation
--- from `root`, so it lands in the same sticky terminal as `<Leader>t`.
function M.run_in_test_terminal(command, root)
    local cwd = vim.fn.getcwd()
    vim.cmd.lcd(vim.fn.fnameescape(root))
    local ok, err = pcall(vim.fn["test#shell"], command, vim.g["test#strategy"] or "basic")
    vim.cmd.lcd(vim.fn.fnameescape(cwd))
    if not ok then
        vim.notify(tostring(err), vim.log.levels.ERROR)
    end
end

local function show_locations(locations, encoding)
    if type(locations) ~= "table" or vim.tbl_isempty(locations) then
        vim.notify("No references", vim.log.levels.INFO)
        return
    end
    local items = vim.lsp.util.locations_to_items(locations, encoding)
    vim.fn.setqflist({}, " ", { title = "References", items = items })
    vim.cmd("botright copen")
end

--- "N references" lenses. rust-analyzer sends the locations along
--- ({ uri, position, locations }); terraform-ls sends only the position
--- ({ position, context }) and expects the client to ask for them.
function M.show_references(cmd, ctx)
    local args = cmd.arguments or {}
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    if type(args[1]) == "string" then
        show_locations(args[3], client.offset_encoding)
        return
    end
    local params = {
        textDocument = vim.lsp.util.make_text_document_params(ctx.bufnr),
        position = args[1],
        context = { includeDeclaration = false },
    }
    client:request("textDocument/references", params, function(err, result)
        if err then
            vim.notify("references: " .. err.message, vim.log.levels.ERROR)
            return
        end
        show_locations(result, client.offset_encoding)
    end, ctx.bufnr)
end

return M
