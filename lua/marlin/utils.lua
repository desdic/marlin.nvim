local M = {}

M.get_cur_filename = function()
    return vim.fn.expand("%:p")
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

--- Return bufnr and if the position should be set
---
---@return number returns a bufnr
---@return boolean if the position should be set or not
M.load_buffer = function(filename)
    local abs_path = vim.fn.fnamemodify(filename, ":p")

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if vim.fn.fnamemodify(name, ":p") == abs_path then
                return bufnr, true
            end
        end
    end

    vim.cmd("edit " .. vim.fn.fnameescape(abs_path))
    return vim.api.nvim_get_current_buf(), false
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
