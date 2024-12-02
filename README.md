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

        require("fzf-lua").fzf_exec(function(fzf_cb)
            for i, b in ipairs(results) do
                local entry = i .. ":" .. b.filename .. ":" .. b.row .. ":" .. b.col
                content[entry] = b
                fzf_cb(entry)
            end
            fzf_cb()
        end, {
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
                        print(vim.inspect(selected))

                        require("marlin").move_down(content[selected[1]].filename)
                    end,
                    reload = true,
                    silent = false,
                },
            },
        })
    end, { desc = "fzf marlin" })
```

### Why yet another ..

When I first saw harpoon I was immediately hooked but I missed a few key features.

 - I use splits and wanted to have it jump to the buffer and not replace the current one.
 - I wanted persistent jumps per project and not per directory.

Like anyone else missing a feature I created a patch but it seems that many other did the same.

### Issues/Feature request

[FAQ](FAQ.md) might have what you are looking, but pull request are also welcome.

### Credits

Credit goes to [ThePrimeagen](https://github.com/ThePrimeagen/harpoon/) for the idea.
