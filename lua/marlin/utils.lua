local M = {}

local vim_fn_bufnr = vim.fn.bufnr
local vim_api_nvim_buf_is_loaded = vim.api.nvim_buf_is_loaded
local vim_fn_bufload = vim.fn.bufload
local vim_api_nvim_set_option_value = vim.api.nvim_set_option_value
local vim_fn_expand = vim.fn.expand

M.get_cur_filename = function()
    return vim_fn_expand("%:p")
end

M.get_project_path = function(patterns)
    return vim.fs.dirname(vim.fs.find(patterns, { upward = true })[1])
end

M.is_empty = function(s)
    return s == nil or s == ""
end

M.swap = function(table, index1, index2)
    table[index1], table[index2] = table[index2], table[index1]
    return table
end

M.load_buffer = function(filename)
    local set_position = false
    -- Check if file already in a buffer
    local bufnr = vim_fn_bufnr(filename)
    if bufnr == -1 then
        -- else create a buffer for it
        bufnr = vim_fn_bufnr(filename, true)
        set_position = true
    end

    -- if the file is not loaded, load it and make it listed (visible)
    if not vim_api_nvim_buf_is_loaded(bufnr) then
        vim_fn_bufload(bufnr)
        vim_api_nvim_set_option_value("buflisted", true, {
            buf = bufnr,
        })
    end

    return bufnr, set_position
end

M.is_no_name_buf = function(buf)
    local opts = { buf = buf }
    return vim.api.nvim_buf_is_loaded(buf)
        and vim.api.nvim_buf_get_name(buf) == ""
        and vim.api.nvim_get_option_value("buflisted", opts)
        and vim.api.nvim_get_option_value("buftype", opts) == ""
        and vim.api.nvim_get_option_value("filetype", opts) == ""
end

M.delete_no_name_buffer = function()
    local curbuffers = vim.api.nvim_list_bufs()

    if #curbuffers == 1 then
        local bufid = curbuffers[1]
        if M.is_no_name_buf(bufid) then
            vim.schedule(function()
                vim.api.nvim_buf_delete(bufid, { force = true })
            end)
        end
    end
end

return M
