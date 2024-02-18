--- Marlin sorters

-- Module definition ==========================================================
local sorters = {}

local utils = require("marlin.utils")

--- Sort indexes by open buffers (Same order like bufferline shows them)
---
---@param filelist marlin.file[]
sorters.by_buffer = function(filelist)
    local index = 1
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.fn.getbufinfo(bufnr)[1].listed == 1 then
            local filename = vim.api.nvim_buf_get_name(bufnr)

            for idx, row in ipairs(filelist) do
                if row.filename == filename then
                    if index ~= idx then
                        utils.swap(filelist, idx, index)
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
