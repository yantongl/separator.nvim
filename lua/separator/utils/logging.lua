local M = {
    cur_line = 0,
    bufnr = nil
}
local LOG_OUTPUT_BUF_NAME = 'LOG_OUTPUT_BUF'

---Create a new buffer and name it with given name
---@return  bufnr   int Handle number
local function create_buf_with_name(name)
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(bufnr, name)
    return bufnr
end

---get buffer by name. Create a buffer if not exist.
---@param   name    string  Name of the buffer we want to find
---@return  bufnr   int     Handle number
local function find_buf_by_name(name)
    local bufs = vim.api.nvim_list_bufs()
    for _, bufnr in ipairs(bufs) do
        local filepath = vim.api.nvim_buf_get_name(bufnr)
        local bufname = filepath:match("^.+/(.+)$")
        if bufname == name then
            return bufnr
        end
    end
    -- failed to find buffer with given name.
    -- create a new buffer and set its name.
    return create_buf_with_name(name)
end

---Make sure the log buffer exist
---@return  bufnr   int     Handle number
local function find_log_buffer(bufnr)
    if bufnr == nil then
        bufnr = find_buf_by_name(LOG_OUTPUT_BUF_NAME)
    else
        local filepath = vim.api.nvim_buf_get_name(bufnr)
        filepath = filepath:gsub('\\', '/')      -- replace windows \\ to /
        local name = filepath:match("^.+/(.+)$") -- find only file name
        if name ~= LOG_OUTPUT_BUF_NAME then
            bufnr = create_buf_with_name(LOG_OUTPUT_BUF_NAME)
        end
    end
    return bufnr
end

function M.log(msg)
    M.log_text_array({ msg })
end

function M.log_text_array(txt_array)
    local end_line = M.cur_line + #txt_array
    M.bufnr = find_log_buffer(M.bufnr)
    -- print('M.bufnr=' .. tostring(M.bufnr))
    vim.api.nvim_buf_set_lines(M.bufnr, M.cur_line, end_line, false, txt_array)
    M.cur_line = end_line
end

function M.log_obj(obj)
    local texts = vim.split(vim.inspect(obj), "\n")
    M.log_text_array(texts)
end

function M.clear()
    M.bufnr = find_log_buffer(M.bufnr)
    M.cur_line = 0;
    vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, { "" })
end

return M
