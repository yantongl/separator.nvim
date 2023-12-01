local M = {}

function prettyprint(x)
    local text = vim.inspect(x)
    text = vim.split(text, '\n', {})
    print(text)
    -- vim.api.nvim_buf_set_lines(248, 0, 100, false, text)
end

function M.get_function_list(callback)
    function on_list(symbles)
        prettyprint(symbles)
        -- re-org symbles by types
        local symblesByType = {}
        for _, item in ipairs(symbles.items) do
            if symblesByType[item.kind] == nil then
                symblesByType[item.kind] = {}
            end
            table.insert(symblesByType[item.kind], item)
        end
        local func_list = {}
        for _, item in ipairs(symblesByType.Function) do
            local func_name = string.sub(item.text, #"[Function] ")
            table.insert(func_list, { item.lnum - 2, func_name })
        end
        callback(func_list)
    end

    vim.lsp.buf.document_symbol({ on_list = on_list })
end

return M
