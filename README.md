# marlin.nvim
##### Smooth sailing between buffers of interest

Persistent and extensible jumps across project buffers of interest with ease.

### Setup

Example using the lazy plugin manager

```lua
{
    "desdic/marlin.nvim",
    opts = {},
    config = function(_, opts)
        local marlin = require("marlin")
        marlin.setup(opts)

        local keymap = vim.keymap.set
        keymap("n", "<Leader>fa", function() marlin.add() end, {  desc = "add file" })
        keymap("n", "<Leader>fd", function() marlin.remove() end, {  desc = "remove file" })
        keymap("n", "<Leader>fx", function() marlin.remove_all() end, {  desc = "remove all for current project" })
        keymap("n", "<Leader>f]", function() marlin.move_up() end, {  desc = "move up" })
        keymap("n", "<Leader>f[", function() marlin.move_down() end, {  desc = "move down" })
        keymap("n", "<Leader>fs", function() marlin.sort() end, {  desc = "sort" })
        keymap("n", "<Leader>fn", function() marlin.next() end, {  desc = "open next index" })
        keymap("n", "<Leader>fp", function() marlin.prev() end, {  desc = "open previous index" })
        keymap("n", "<Leader><Leader>", function() marlin.toggle() end, {  desc = "toggle cur/last open index" })

        for index = 1,4 do
            keymap("n", "<Leader>"..index, function() marlin.open(index) end, {  desc = "goto "..index })
        end
    end
}
```

If you want to restore the 'session' it can be done via autocmd like

```lua
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("restore_marlin", { clear = true }),
    callback = function()
        -- If nvim has an argument like file(s) we skip the restore
        if next(vim.fn.argv()) ~= nil then
            return
        end
        require("marlin").open_all()
    end,
    nested = true,
})
```

### Default configuration

```lua
local default = {
    patterns = { ".git", ".svn" }, -- look for root of project
    datafile = vim.fn.stdpath("data") .. "/marlin.json", -- location of data file
    open_callback = callbacks.change_buffer -- default way to open buffer
    sorter = sorter.by_buffer -- sort by bufferid
    save_cursor_location = true
    suppress = {
        missing_root = false -- don't give warning on project root not found
    }
}
```

### Easy integration with most status lines

Example with [lualine](https://github.com/nvim-lualine/lualine.nvim)

```lua
return {
    "nvim-lualine/lualine.nvim",
    config = function()
        local marlin = require("marlin")

        local marlin_component = function()
            local indexes = marlin.num_indexes()
            if indexes == 0 then
                return ""
            end
            local cur_index = marlin.cur_index()

            return " " .. cur_index .. "/" .. indexes
        end

        require("lualine").setup({
            ...
            sections = {
                ...
                lualine_c = { marlin_component },
                ...
            },
        })
    end
```

### Extending behaviour

`marlin.callbacks` has a few options like

- change_buffer (which does what it says, default)
- use_split (if file is already open in a split switch to it)

But its possible to change the open_call function to get the behaviour you want. If you want to open new buffers in a vsplit you can

```lua
    open_callback = function(bufnr, _)
        vim.cmd("vsplit")
        vim.api.nvim_set_current_buf(bufnr)
    end,
```

Or if want to add an options to open_index that switches to the buffer if already open in a split

```lua
    open_callback = function(bufnr, opts)
        if opts.use_split then
            local wins = vim.api.nvim_tabpage_list_wins(0)
            for _, win in ipairs(wins) do
                local winbufnr = vim.api.nvim_win_get_buf(win)

                if winbufnr == bufnr then
                    vim.api.nvim_set_current_win(win)
                    return
                end
            end
        end

        vim.api.nvim_set_current_buf(bufnr)
    end,
```

Sorting also has a few options like

- by_buffer sorts by buffer id (The order they where opened in)
- by_name (Sorts by path+filename)

But they can also be change if you want to write your own sorter.

Choice is yours

### But there is no UI

Correct. I'm not planning on creating a UI but if you really want one you can easily create it.

Example using telescope

```lua
    local mindex = 0
    local generate_finder = function()
        mindex = 0
        return require("telescope.finders").new_table({
            results = require("marlin").get_indexes(),
            entry_maker = function(entry)
                mindex = mindex + 1
                return {
                    value = entry,
                    ordinal = mindex .. ":" .. entry.filename,
                    lnum = entry.row,
                    col = entry.col + 1,
                    filename = entry.filename,
                    display = mindex .. ":" .. entry.filename .. ":" .. entry.row .. ":" .. entry.col,
                }
            end,
        })
    end

    vim.keymap.set("n", "<Leader>fx", function()
        local conf = require("telescope.config").values
        local action_state = require("telescope.actions.state")

        require("telescope.pickers")
            .new({}, {
                prompt_title = "Marlin",
                finder = generate_finder(),
                previewer = conf.grep_previewer({}),
                sorter = conf.generic_sorter({}),
                attach_mappings = function(_, map)
                    map("i", "<c-d>", function(bufnr)
                        local current_picker = action_state.get_current_picker(bufnr)
                        current_picker:delete_selection(function(selection)
                            require("marlin").remove(selection.filename)
                        end)
                    end)
                    map("i", "+", function(bufnr)
                        local current_picker = action_state.get_current_picker(bufnr)
                        local selection = current_picker:get_selection()
                        require("marlin").move_up(selection.filename)
                        current_picker:refresh(generate_finder(), {})
                    end)
                    map("i", "-", function(bufnr)
                        local current_picker = action_state.get_current_picker(bufnr)
                        local selection = current_picker:get_selection()
                        require("marlin").move_down(selection.filename)
                        current_picker:refresh(generate_finder(), {})
                    end)
                    return true
                end,
            })
            :find()
    end, { desc = "Telescope marlin" })
```

Example using fzf-lua

```lua
    vim.keymap.set("n", "<Leader>fx", function()
        local results = require("marlin").get_indexes()
        local content = {}

        local fzf_lua = require("fzf-lua")
        local builtin = require("fzf-lua.previewer.builtin")
        local fzfpreview = builtin.buffer_or_file:extend()

        function fzfpreview:new(o, opts, fzf_win)
            fzfpreview.super.new(self, o, opts, fzf_win)
            setmetatable(self, fzfpreview)
            return self
        end

        function fzfpreview.parse_entry(_, entry_str)
            if entry_str == "" then
                return {}
            end

            local entry = content[entry_str]
            return {
                path = entry.filename,
                line = entry.row or 1,
                col = 1,
            }
        end

        fzf_lua.fzf_exec(function(fzf_cb)
            for i, b in ipairs(results) do
                local entry = i .. ":" .. b.filename .. ":" .. b.row

                content[entry] = b
                fzf_cb(entry)
            end
            fzf_cb()
        end, {
            previewer = fzfpreview,
            prompt = "Marlin> ",
            actions = {
                ["ctrl-d"] = {
                    fn = function(selected)
                        require("marlin").remove(content[selected[1]].filename)
                    end,
                    reload = true,
                    silent = true,
                },
                ["ctrl-k"] = {
                    fn = function(selected)
                        require("marlin").move_up(content[selected[1]].filename)
                    end,
                    reload = true,
                    silent = false,
                },
                ["ctrl-j"] = {
                    fn = function(selected)
                        require("marlin").move_down(content[selected[1]].filename)
                    end,
                    reload = true,
                    silent = false,
                },
            },
        })
    end, { desc = "fzf marlin" })
```

Example using snacks

```lua
    vim.keymap.set("n", "<leader>fx", function()
        local snacks = require("snacks")
        local lookup = {}

        local function get_choices()
            local results = require("marlin").get_indexes()

            local items = {}
            lookup = {}
            for idx, b in ipairs(results) do
                local text = b.filename .. ":" .. b.row

                table.insert(items, {
                    formatted = text,
                    file = b.filename,
                    text = text,
                    idx = idx,
                    pos = { tonumber(b.row), 0 },
                })

                lookup[text] = b
            end
            return items
        end

        snacks.picker.pick({
            source = "select",
            finder = get_choices,
            title = "Marlin",
            layout = { preview = true },
            actions = {
                marlin_up = function(picker, item)
                    require("marlin").move_up(lookup[item.text].filename)
                    picker:find({ refresh = true })
                end,
                marlin_down = function(picker, item)
                    require("marlin").move_down(lookup[item.text].filename)
                    picker:find({ refresh = true })
                end,
                marlin_delete = function(picker, item)
                    require("marlin").remove(lookup[item.text].filename)
                    picker:find({ refresh = true })
                end,
            },
            win = {
                input = {
                    keys = {
                        ["<C-k>"] = { "marlin_up", mode = { "n", "i" }, desc = "Move marlin up" },
                        ["<C-j>"] = { "marlin_down", mode = { "n", "i" }, desc = "Move marlin down" },
                        ["<C-d>"] = { "marlin_delete", mode = { "n", "i" }, desc = "Marlin delete" },
                    },
                },
            },
        })
    end, { desc = "marlin" })
```

### Why yet another ..

When I first saw harpoon I was immediately hooked but I missed a few key features.

 - I use splits and wanted to have it jump to the buffer and not replace the current one.
 - I wanted persistent jumps per project and not per directory.

### Issues/Feature request

[FAQ](FAQ.md) might have what you are looking, but pull request are also welcome.

### Credits

Credit goes to [ThePrimeagen](https://github.com/ThePrimeagen/harpoon/) for the idea.
