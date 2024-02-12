local M = {}

---@param bufnr number buffer id
M.change_buffer = function(bufnr, _)
    vim.api.nvim_set_current_buf(bufnr)
end

---@param bufnr number buffer id
M.use_split = function(bufnr, _)
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
        local winbufnr = vim.api.nvim_win_get_buf(win)

        if winbufnr == bufnr then
            vim.api.nvim_set_current_win(win)
            return
        end
    end

    vim.api.nvim_set_current_buf(bufnr)
end

return M
