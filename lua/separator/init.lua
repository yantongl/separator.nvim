local logger = require('separator.utils.logging')

local backend = nil

local default_class_style = { fgColor = '#56d364', char = '=', width = 100, name = 'ClassSeparator' }
local default_func_style = { fgColor = '#f97583', char = '_', width = 100, name = 'FuncSeparator' }

local M = {
    BUFFER = 0, -- 0 means current buffer
    mark_ns = nil,
    config = {
        styles = {
            class = default_class_style,
            func = default_func_style,
            method = default_func_style,
        },
        -- backend = 'treesitter', -- backend name, treesitter or lsp
        backend = 'lsp', -- backend name, treesitter or lsp
        debug = false
    },
}

--------------------------------------------------------------------------------
-- row as the row number in nvim, 1-based index
function M.draw_separator(row, style)
    -- get the length of the line, then fill the line to configured column
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
    local line_length = line and string.len(line) or 0
    local txt = string.rep(style.char, style.width - 1 - line_length)

    -- set a extmark
    if M.config.debug then
        logger.log('extmark on lin ' .. tostring(row) .. ' with text ' .. line)
    end
    local mark_id = vim.api.nvim_buf_set_extmark(M.BUFFER, M.mark_ns, row - 1, 0, {
        virt_text = {
            { txt, style.name }
        }
    })
end

function M.refresh()
    -- clear all namespaced objects (extmarks)
    vim.api.nvim_buf_clear_namespace(0, M.mark_ns, 0, -1)
    logger.clear()

    -- draw on each function
    backend.get_function_list(function(result)
        for _, item in ipairs(result) do
            local row = item.row
            -- local function_name = item.func_name
            local style = M.config.styles[item.type]
            logger.log('draw separator at line ' .. tostring(row))
            M.draw_separator(tonumber(row), style)
        end
    end, M.config)
end

function M.setup(opts)
    -- merge recursively, keep left map if a key is redefined
    opts = opts or {}
    M.config = vim.tbl_deep_extend('keep', opts, M.config)
    backend = require('separator.backend.' .. M.config.backend)

    -- create a namespace
    M.mark_ns = vim.api.nvim_create_namespace('separator.nvim')

    -- create highlights
    for _, style in pairs(M.config.styles) do
        local cmd = 'highlight ' .. style.name .. ' guifg=' .. style.fgColor
        vim.cmd(cmd)
    end

    -- set autocmd
    local group = vim.api.nvim_create_augroup("separator.nvim", { clear = true })
    local pattern = { '*.lua', '*.py', '*.cs', '*.js', '*.ts', '*.h', '*.cpp' }
    vim.api.nvim_create_autocmd(
        { 'BufEnter', 'BufWritePost' },
        {
            group = group,
            pattern = pattern,
            command = 'lua require("separator").refresh()'
        }
    )

    vim.cmd [[
    nmap <leader>vt :lua require('separator').setup({backend='treesitter', debug=true})
    nmap <leader>vl :lua require('separator').setup({backend='lsp', debug=true})
    ]]
end

return M
