describe("config", function()
    local marlin = require("marlin")
    local eq = assert.equals

    local opts = {
        patterns = { "Makefile" },
    }

    marlin.setup(opts)

    eq(marlin.opts.patterns[1], "Makefile")
end)

describe("marlin", function()
    local eq = assert.equals
    local marlin = require("marlin")
    local opts = {
        datafile = "/tmp/marlin.tmp",
    }
    marlin.setup(opts)
    marlin.remove_all()

    vim.cmd("e /tmp/filea")
    marlin.add()
    eq(marlin.num_indexes(), 1)

    vim.cmd("e /tmp/fileb")
    marlin.add()
    eq(marlin.num_indexes(), 2)

    vim.cmd("e /tmp/filec")
    marlin.add()
    eq(marlin.num_indexes(), 3)

    vim.cmd("e /tmp/filed")
    marlin.add()
    eq(marlin.num_indexes(), 4)

    local indexes = marlin.get_indexes()
    eq(indexes[1].filename, "/tmp/filea")
    eq(indexes[2].filename, "/tmp/fileb")
    eq(indexes[3].filename, "/tmp/filec")
    eq(indexes[4].filename, "/tmp/filed")

    marlin.remove()
    eq(marlin.num_indexes(), 3)
    vim.cmd("bd")

    vim.cmd("bprev")
    marlin.move_up()

    indexes = marlin.get_indexes()
    eq(indexes[1].filename, "/tmp/fileb")
    eq(indexes[2].filename, "/tmp/filea")
    eq(indexes[3].filename, "/tmp/filec")

    marlin.sort()
    indexes = marlin.get_indexes()
    eq(indexes[1].filename, "/tmp/filea")
    eq(indexes[2].filename, "/tmp/fileb")
    eq(indexes[3].filename, "/tmp/filec")

    marlin.remove_all()
    eq(marlin.num_indexes(), 0)
end)
