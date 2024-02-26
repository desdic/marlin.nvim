--- Marlin is a plugin for quickly navigating in buffers of interest

---@usage Example using the lazy plugin manager
---{
---    "desdic/marlin.nvim",
---    opts = {},
---    config = function(_, opts)
---        local marlin = require("marlin")
---        marlin.setup(opts)
---
---        local keymap = vim.keymap.set
---        keymap("n", "<Leader>fa", function() marlin.add() end, {  desc = "add file" })
---        keymap("n", "<Leader>fd", function() marlin.remove() end, {  desc = "remove file" })
---        keymap("n", "<Leader>fx", function() marlin.remove_all() end, {  desc = "remove all for current project" })
---        keymap("n", "<Leader>f]", function() marlin.move_up() end, {  desc = "move up" })
---        keymap("n", "<Leader>f[", function() marlin.move_down() end, {  desc = "move down" })
---        keymap("n", "<Leader>fs", function() marlin.sort() end, {  desc = "sort" })
---        keymap("n", "<Leader>0", function() marlin.open_all() end, {  desc = "open all" })
---
---        for index = 1,4 do
---            keymap("n", "<Leader>"..index, function() marlin.open(index) end, {  desc = "goto "..index })
---        end
---    end
---}

-- Module definition ==========================================================
---@class marlin.commands
---@field add fun(filename?: string): nil -- add file
---@field cur_index fun(): number -- get index of current file
---@field get_indexes fun(): marlin.file[] -- get indexes
---@field move fun(table: marlin.file[], direction: marlin.movefun): nil
---@field move_down fun(): nil -- move index down
---@field move_up fun(): nil -- move index up
---@field num_indexes fun(): number -- get number of indexes
---@field open fun(index: number, opts: any?): nil -- open index
---@field open_all fun(): nil
---@field remove fun(filename?: string): nil -- remove current file
---@field remove_all fun(): nil -- clear all indexes
---@field setup fun(opts: marlin.config): nil -- setup
---@field sort fun(sort_func?: fun(table: marlin.file[])): nil -- sorting
local marlin = {}

---@class marlin.file
---@field col number
---@field row number
---@field filename string

---@alias marlin.movefun fun(table: marlin.file[], cur_index: number, num_indexes: number)

local callbacks = require("marlin.callbacks")
local sorter = require("marlin.sorters")
local datafile = require("marlin.datafile")
local utils = require("marlin.utils")

---@class marlin.config
---@field patterns? string[] patterns to detect root of project
---@field datafile? string location of datafile
---@field open_callback? fun(bufnr: number, opts: any?) function to set current buffer
---@field sorter? fun(table: marlin.file[]) sort function
--- Default config
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
local default = {
    patterns = { ".git", ".svn" },
    datafile = vim.fn.stdpath("data") .. "/marlin.json",
    open_callback = callbacks.change_buffer,
    sorter = sorter.by_buffer,
    suppress = {
        missing_root = false,
    },
}
--minidoc_afterlines_end

local get_cursor = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    return cursor[1], cursor[2]
end

local save = function(m)
    vim.schedule(function()
        datafile.save_data(m.opts, m.project_path, m.project_files)
    end)
end

local update_location = function(m)
    local cur_filename = utils.get_cur_filename()
    if utils.is_empty(cur_filename) then
        return
    end

    if not m.project_files["files"] then
        m.project_files["files"] = {}
    end

    local row, col = get_cursor()
    for idx, data in ipairs(m.get_indexes()) do
        if data["filename"] == cur_filename then
            m.project_files["files"][idx]["col"] = col
            m.project_files["files"][idx]["row"] = row
            break
        end
    end

    save(m)
end

local search_for_project_path = function(patterns)
    for _, pattern in ipairs(patterns) do
        local match = utils.get_project_path(pattern)
        if match ~= nil then
            return match
        end
    end
    return nil
end

--- Add a file
---
---@param filename? string -- optional filename
---
---@usage `require('marlin').add()`
marlin.add = function(filename)
    filename = filename or utils.get_cur_filename()
    if utils.is_empty(filename) then
        return
    end

    if not marlin.project_files["files"] then
        marlin.project_files["files"] = {}
    end

    local row, col = get_cursor()
    for idx, data in ipairs(marlin.get_indexes()) do
        if data["filename"] == filename then
            marlin.project_files["files"][idx]["col"] = col
            marlin.project_files["files"][idx]["row"] = row
            return
        end
    end

    table.insert(marlin.project_files["files"], {
        filename = filename,
        col = col,
        row = row,
    })

    save(marlin)
end

--- Return index for current filename
---
---@return number retuns current index and 0 if not found
---
---@usage `require('marlin').cur_index()`
marlin.cur_index = function()
    local cur_filename = utils.get_cur_filename()
    if utils.is_empty(cur_filename) then
        return 0
    end

    if not marlin.project_files["files"] then
        marlin.project_files["files"] = {}
    end

    for idx, data in ipairs(marlin.project_files["files"]) do
        if data["filename"] == cur_filename then
            return idx
        end
    end
    return 0
end

--- Returns list of indexes
---
---@return marlin.file[] returns indexes
---
---@usage `require('marlin').get_indexes()`
marlin.get_indexes = function()
    if marlin.num_indexes() == 0 then
        return {}
    end

    return marlin.project_files["files"]
end

--- Generic move function for moving indexes
---
---@param table string[] index table
---@param direction marlin.movefun
marlin.move = function(table, direction)
    local indexes = marlin.num_indexes()
    if indexes < 2 then
        return
    end

    local cur_index = marlin.cur_index()
    direction(table, cur_index, indexes)
end

local up = function(table, cur_index, indexes)
    if cur_index == 1 then
        utils.swap(table, cur_index, indexes)
        return
    end

    utils.swap(table, cur_index, cur_index - 1)
end

local down = function(table, cur_index, indexes)
    if cur_index == indexes then
        utils.swap(table, 1, cur_index)
        return
    end

    utils.swap(marlin.project_files["files"], cur_index, cur_index + 1)
end

--- Move current index down
---
---@usage `require('marlin').move_down()`
marlin.move_down = function()
    marlin.move(marlin.project_files["files"], down)
end

--- Move current index up
---
---@usage `require('marlin').move_up()`
marlin.move_up = function()
    marlin.move(marlin.project_files["files"], up)
end

--- Return number of indexes for current project
---
---@return number returns number of indexes in current project
---
---@usage `require('marlin').num_indexes()`
marlin.num_indexes = function()
    if not marlin.project_files["files"] then
        return 0
    end

    return #marlin.project_files["files"]
end

--- Open index
---
---@param index number index to load
---@param opts any? optional options to open_callback
---
---@usage `require('marlin').open(<index>)`
marlin.open = function(index, opts)
    local idx = tonumber(index)
    if idx > marlin.num_indexes() then
        return
    end

    opts = opts or {}

    local cur_item = marlin.project_files["files"][idx]
    local bufnr, set_position = utils.load_buffer(cur_item.filename)

    marlin.opts.open_callback(bufnr, opts)

    if set_position then
        vim.api.nvim_win_set_cursor(0, {
            cur_item.row or 1,
            cur_item.col or 0,
        })
    end
end

--- Open all indexes
---
---@usage `require('marlin').open_all()`
marlin.open_all = function()
    for idx, _ in ipairs(marlin.get_indexes()) do
        marlin.open(idx)
    end
end

--- Remove index
---
---@param filename? string -- optional filename
---
---@usage `require('marlin').remove()`
marlin.remove = function(filename)
    filename = filename or utils.get_cur_filename()
    if utils.is_empty(filename) or not marlin.project_files["files"] then
        return
    end

    for idx, data in ipairs(marlin.project_files["files"]) do
        if data["filename"] == filename then
            table.remove(marlin.project_files["files"], idx)

            save(marlin)

            break
        end
    end
end

--- Remove all indexes for current project
---
---@usage `require('marlin').remove_all()`
marlin.remove_all = function()
    marlin.project_files["files"] = {}
end

--- Setup (required)
---
---@param opts? marlin.config
---
---@usage `require('marlin').setup()`
marlin.setup = function(opts)
    marlin.opts = vim.tbl_deep_extend("force", default, opts or {})

    -- Load project specific data
    marlin.project_path = search_for_project_path(marlin.opts.patterns)

    marlin.project_files = {}
    local data = datafile.read_config(marlin.opts.datafile)
    for key, value in pairs(data) do
        if key == marlin.project_path then
            marlin.project_files = value
            break
        end
    end

    local augroup = vim.api.nvim_create_augroup("marlin", {})
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave", "VimLeavePre" }, {
        group = augroup,
        pattern = "*",
        callback = function(_)
            update_location(marlin)
        end,
    })
end
--- Sort indexes
---
---@param sort_func? fun(table: marlin.file[]) optional sort function else default
---
---@usage `require('marlin').sort()`
marlin.sort = function(sort_func)
    sort_func = sort_func or marlin.opts.sorter

    if sort_func then
        sort_func(marlin.project_files["files"])
    end
end

return marlin
