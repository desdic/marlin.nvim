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
---        keymap("n", "<Leader>fn", function() marlin.next() end, {  desc = "open next index" })
---        keymap("n", "<Leader>fp", function() marlin.prev() end, {  desc = "open previous index" })
---        keymap("n", "<Leader><Leader>", function() marlin.toggle() end, {  desc = "toggle cur/last open index" })
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
---@field move fun(table: marlin.file[], direction: marlin.movefun, filename?: string): nil
---@field move_down fun(filename?: string): nil -- move index down
---@field move_up fun(filename?: string): nil -- move index up
---@field num_indexes fun(): number -- get number of indexes
---@field open fun(index: number, opts: any?): nil -- open index
---@field next fun(opts: any?): nil -- open next
---@field prev fun(opts: any?): nil -- open previous
---@field toggle fun(opts: any?): nil -- toggle between cur and last opened index
---@field open_all fun(opts: any?): nil
---@field remove fun(filename?: string): nil -- remove current file
---@field remove_all fun(): nil -- clear all indexes
---@field setup fun(opts: marlin.config): nil -- setup
---@field sort fun(sort_func?: fun(table: marlin.file[])): nil -- sorting
---@field load_project_files fun(): nil -- load project files
---@field save fun(): nil -- force a save
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
    save_cursor_location = true,
    suppress = {
        missing_root = false,
    },
}
--minidoc_afterlines_end

local get_cursor = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    return cursor[1], cursor[2]
end

local update_location = function(m, event)
    local cur_filename = utils.get_cur_filename()
    if utils.is_empty(cur_filename) then
        return
    end

    local row, col = get_cursor()

    local project_files = m.project_files
    local save_cursor_location = m.opts.save_cursor_location

    for idx, data in ipairs(m.get_indexes()) do
        if data["filename"] == cur_filename then
            if event == "BufLeave" then
                m.last = idx
            end
            if save_cursor_location then
                project_files["files"][idx]["col"] = col
                project_files["files"][idx]["row"] = row
            end
            return
        end
    end
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

--- Force save (Save is normally done when quitting)
---
---@usage `require('marlin').save()`
marlin.save = function()
    datafile.save_data(marlin.opts, marlin.project_path, marlin.project_files)
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

    local row, col = get_cursor()

    for idx, data in ipairs(marlin.get_indexes()) do
        if data["filename"] == filename then
            marlin.project_files["files"][idx]["col"] = col
            marlin.project_files["files"][idx]["row"] = row
            return
        end
    end

    -- File wasn't previously added so we add it
    table.insert(marlin.project_files["files"], {
        filename = filename,
        col = col,
        row = row,
    })
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
    return marlin.project_files["files"]
end

--- Return index of a filename
---
---@param filename string
---
---@return number|nil returns index of file or nil
---
---@usage `require("marlin").get_fileindex("/full/path/to/filename")`
marlin.get_fileindex = function(filename)
    if filename then
        for idx, data in ipairs(marlin.project_files["files"]) do
            if data["filename"] == filename then
                return idx
            end
        end
    end
    return nil
end
--- Generic move function for moving indexes
---
---@param table string[] index table
---@param direction marlin.movefun
marlin.move = function(table, direction, filename)
    local indexes = marlin.num_indexes()
    if indexes < 2 then
        return
    end

    local cur_index = marlin.get_fileindex(filename) or marlin.cur_index()
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
marlin.move_down = function(filename)
    marlin.move(marlin.project_files["files"], down, filename)
end

--- Move current index up
---
---@usage `require('marlin').move_up()`
marlin.move_up = function(filename)
    marlin.move(marlin.project_files["files"], up, filename)
end

--- Return number of indexes for current project
---
---@return number returns number of indexes in current project
---
---@usage `require('marlin').num_indexes()`
marlin.num_indexes = function()
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
    if idx > marlin.num_indexes() or index < 1 then
        return
    end

    vim.schedule(function()
        local cur_item = marlin.project_files["files"][idx]
        local bufnr, set_position = utils.load_buffer(cur_item.filename)

        marlin.opts.open_callback(bufnr, opts or {})

        if not set_position then
            return
        end

        pcall(function()
            vim.api.nvim_win_set_cursor(0, {
                cur_item.row or 1,
                cur_item.col or 0,
            })
        end)
    end)
end

--- Toggle between current and last open index
---
---@param opts any? optional options to open_callback
---
---@usage `require('marlin').next()`
marlin.toggle = function(opts)
    marlin.open(marlin.last, opts)
end

--- Open next index
---
---@param opts any? optional options to open_callback
---
---@usage `require('marlin').next()`
marlin.next = function(opts)
    local index = marlin.cur_index() + 1
    if index > marlin.num_indexes() then
        index = 1
    end
    marlin.open(index, opts or {})
end

--- Open previous index
---
---@param opts any? optional options to open_callback
---
---@usage `require('marlin').prev()`
marlin.prev = function(opts)
    local index = marlin.cur_index() - 1

    local max = marlin.num_indexes()
    if index < 1 then
        index = max
    end
    marlin.open(index, opts or {})
end

--- Open all indexes
---
---@param opts any? optional options to open_callback
---
---@usage `require('marlin').open_all()`
marlin.open_all = function(opts)
    utils.delete_no_name_buffer()

    opts = opts or {}
    local marlinopen = marlin.open
    for idx, _ in ipairs(marlin.get_indexes()) do
        marlinopen(idx, opts)
    end
end

--- Remove index
---
---@param filename? string -- optional filename
---
---@usage `require('marlin').remove()`
marlin.remove = function(filename)
    filename = filename or utils.get_cur_filename()
    if utils.is_empty(filename) then
        return
    end

    for idx, data in ipairs(marlin.project_files["files"]) do
        if data["filename"] == filename then
            table.remove(marlin.project_files["files"], idx)

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

--- load project files
marlin.load_project_files = function()
    local project_path = search_for_project_path(marlin.opts.patterns)
    marlin.project_path = project_path
    marlin.project_files = {}
    marlin.project_files["files"] = {}
    local data = datafile.read_config(marlin.opts.datafile)

    local project_data = data[marlin.project_path]

    if project_data then
        marlin.project_files = project_data
    end
end

--- Setup (required)
---
---@param opts? marlin.config
---
---@usage `require('marlin').setup()`
marlin.setup = function(opts)
    marlin.opts = vim.tbl_deep_extend("force", default, opts or {})
    -- Load project specific data
    marlin.load_project_files()

    marlin.last = 1

    local augroup = vim.api.nvim_create_augroup("marlin", {})
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
        group = augroup,
        pattern = "*",
        callback = function(ev)
            update_location(marlin, ev.event)
        end,
    })

    vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
        group = augroup,
        pattern = "*",
        callback = function(_)
            marlin.save()
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
