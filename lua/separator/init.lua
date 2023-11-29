local ts_utils = require 'nvim-treesitter.ts_utils'

local default_class_style = { fgColor = '#56d364', char = '=', width = 80, name = 'ClassSeparator' }
local default_func_style = { fgColor = '#f97583', char = '_', width = 60, name = 'FuncSeparator' }

local M = {
    BUFFER = 0, -- 0 means current buffer
    -- mark_ids = {}
    mark_ns = nil,

    config = {
        class_style = default_class_style,
        func_style = default_func_style,
    },
}

local get_master_node = function()
    local node = ts_utils.get_node_at_cursor()
    if node == nil then
        error("No Treesitter parser found")
    end
end

-- row as the row number in nvim, 1-based index
M.draw_separator = function(row, style)
    -- get the length of the line, then fill the line to configured column
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local line_length = #line
    local txt = string.rep(style.char, style.width - 1 - line_length)

    -- set a extmark
    local mark_id = vim.api.nvim_buf_set_extmark(M.BUFFER, M.mark_ns, row - 1, 0, {
        virt_text = {
            { txt, style.name }
        }
    })

    -- mark_ids[#mark_ids + 1] = mark_id

    -- local mark = vim.api.nvim_buf_get_extmark_by_id(M.BUFFER, M.mark_ns, mark_id, {})
    -- vim.print(mark)
end

M.setup = function(opts)
    -- merge recursively, keep left map if a key is redefined
    M.config = vim.tbl_deep_extend('keep', opts, M.config)

    -- create a namespace
    M.mark_ns = vim.api.nvim_create_namespace('separator.nvim')
    -- clear all namespaced objects (extmarks)
    vim.api.nvim_buf_clear_namespace(0, M.mark_ns, 0, -1)

    for _, style in pairs(M.config) do
        local cmd = 'highlight ' .. style.name .. ' guifg=' .. style.fgColor
        vim.print(cmd)
        vim.cmd(cmd)
    end
end

-- Debug code
M.setup({})
M.draw_separator(16, M.config.class_style)
M.draw_separator(30, M.config.func_style)

return M
