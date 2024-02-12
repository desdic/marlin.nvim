local M = {}

M.read_config = function(datafile)
    if vim.fn.filereadable(datafile) ~= 0 then
        local fd = io.open(datafile, "r")
        if fd then
            local content = fd:read("*a")
            io.close(fd)
            return vim.fn.json_decode(content)
        end
    end
    return {}
end

M.save_data = function(datafile, project, localdata)
    local data = M.read_config(datafile)
    data[project] = localdata

    -- If we have no more files we remove the project
    if #data[project]["files"] == 0 then
        data[project] = nil
    end

    local content = vim.fn.json_encode(data)
    local fd = io.open(datafile, "w")
    if not fd then
        vim.notify("Unable to open " .. datafile .. " for write")
        return
    end

    fd:write(content)
    io.close(fd)
end

return M
