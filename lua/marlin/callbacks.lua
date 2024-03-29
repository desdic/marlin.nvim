--- Marlin callbacks

-- Module definition ==========================================================
local callbacks = {}

local vim_api_nvim_tabpage_list_wins = vim.api.nvim_tabpage_list_wins
local vim_api_nvim_win_get_buf = vim.api.nvim_win_get_buf
local vim_api_nvim_set_current_win = vim.api.nvim_set_current_win
local vim_api_nvim_set_current_buf = vim.api.nvim_set_current_buf

---@param bufnr number buffer id
callbacks.change_buffer = function(bufnr, _)
    vim_api_nvim_set_current_buf(bufnr)
end

---@param bufnr number buffer id
callbacks.use_split = function(bufnr, _)
    local wins = vim_api_nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
        local winbufnr = vim_api_nvim_win_get_buf(win)

        if winbufnr == bufnr then
            vim_api_nvim_set_current_win(win)
            return
        end
    end

    vim_api_nvim_set_current_buf(bufnr)
end

return callbacks
