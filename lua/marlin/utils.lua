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

M.load_buffer = function(filename)
    local set_position = false
    -- Check if file already in a buffer
    local bufnr = vim.fn.bufnr(filename)
    if bufnr == -1 then
        -- else create a buffer for it
        bufnr = vim.fn.bufnr(filename, true)
        set_position = true
    end

    -- if the file is not loaded, load it and make it listed (visible)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        vim.fn.bufload(bufnr)
        vim.api.nvim_set_option_value("buflisted", true, {
            buf = bufnr,
        })
    end

    return bufnr, set_position
end

return M
