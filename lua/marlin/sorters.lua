--- Marlin sorters

-- Module definition ==========================================================
local sorters = {}

local utils = require("marlin.utils")

local vim_api_nvim_buf_get_name = vim.api.nvim_buf_get_name
local vim_fn_getbufinfo = vim.fn.getbufinfo
local utils_swap = utils.swap

--- Sort indexes by open buffers (Same order like bufferline shows them)
---
---@param filelist marlin.file[]
sorters.by_buffer = function(filelist)
    local index = 1
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim_fn_getbufinfo(bufnr)[1].listed == 1 then
            local filename = vim_api_nvim_buf_get_name(bufnr)

            for idx, row in ipairs(filelist) do
                if row.filename == filename then
                    if index ~= idx then
                        utils_swap(filelist, idx, index)
                    end
                    index = index + 1
                    break
                end
            end
        end
    end
end

--- Sort indexes by path + filename
---
---@param filelist marlin.file[]
sorters.by_name = function(filelist)
    table.sort(filelist, function(a, b)
        return a.filename > b.filename
    end)
end

return sorters
