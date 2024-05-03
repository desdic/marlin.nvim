local M = {}

local uv = vim.loop or vim.uv

M.read_config = function(datafile)
    local fd = uv.fs_open(datafile, "r", 438)
    if fd then
        local stat = uv.fs_fstat(fd)
        local data = uv.fs_read(fd, stat.size, 0)
        uv.fs_close(fd)
        return vim.fn.json_decode(data)
    end
    return {}
end

M.save_data = function(opts, project, localdata)
    if project == nil then
        if not opts.suppress.missing_root then
            vim.notify("project root not found, check FAQ")
        end
        return
    end

    local data = M.read_config(opts.datafile)
    data[project] = localdata

    -- If we have no more files we remove the project
    if #data[project]["files"] == 0 then
        data[project] = nil
    end

    local content = vim.fn.json_encode(data)

    local fd = uv.fs_open(opts.datafile, "w", 438)
    if not fd then
        vim.notify("Unable to open " .. opts.datafile .. " for write")
        return
    end

    uv.fs_write(fd, content)
    uv.fs_close(fd)
end

return M
