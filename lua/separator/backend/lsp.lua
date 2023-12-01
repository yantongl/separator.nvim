local M = {}

local function convert_type(lsp_type)
    local type = "unknown"
    if vim.startswith(lsp_type, "Function") then
        type = 'func'
    elseif vim.startswith(lsp_type, "Class") then
        type = 'class'
    end
    return type
end

function M.get_function_list(callback, config)
    function on_list(symbles)
        if config.debug then
            print(vim.inspect(symbles))
        end
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
            table.insert(func_list, {
                type = convert_type(item.kind),
                row = item.lnum,
                func_name = func_name
            })
        end
        callback(func_list)
    end

    vim.lsp.buf.document_symbol({ on_list = on_list })
end

return M
