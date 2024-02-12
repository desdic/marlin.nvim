describe("swap", function()
    local utils = require("marlin.utils")
    local eq = assert.equals

    local list = { "/tmp/bfile", "/tmp/afile" }

    utils.swap(list, 1, 2)

    eq(list[1], "/tmp/afile")
    eq(list[2], "/tmp/bfile")
end)
