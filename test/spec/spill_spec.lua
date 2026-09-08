local spill = require("lib.spill")

--- The startup defaults, so the sizes here are the ones a player gets out of the box
local MEDIUM, LARGE = 1000, 10000

describe("what a fluid leaves behind", function()
    it("makes a chemical spill of anything that pollutes", function()
        assert.are.equal("chemical-spill", spill.kind("crude-oil"))
        assert.are.equal("chemical-spill", spill.kind("lava"))
        assert.are.equal("chemical-spill", spill.kind("holmium-solution"))
    end)

    it("makes a plain puddle of water", function()
        assert.are.equal("liquid-spill", spill.kind("water"))
    end)

    it("leaves nothing at all where steam vents away", function()
        assert.is_true(spill.ignored("steam"))
        assert.is_false(spill.ignored("water"))
        assert.is_false(spill.ignored("crude-oil"))
    end)

    -- the two lists were written out once per stage before, and could drift apart
    it("gives the data stage and the control stage the same answer", function()
        for _, fluid in pairs{"water", "crude-oil", "steam", "lava"} do
            assert.are.equal(spill.kind(fluid), spill.kind(fluid))
            assert.are.equal(spill.entity_name(fluid, "small"),
                             spill.kind(fluid) .. "-" .. fluid .. "-small")
        end
    end)
end)

describe("how big a spill is", function()
    it("is small below the medium threshold", function()
        assert.are.equal("small", spill.size(0, MEDIUM, LARGE))
        assert.are.equal("small", spill.size(999, MEDIUM, LARGE))
    end)

    it("is medium from the medium threshold up to the large one", function()
        assert.are.equal("medium", spill.size(MEDIUM, MEDIUM, LARGE))
        assert.are.equal("medium", spill.size(9999, MEDIUM, LARGE))
    end)

    it("is large from the large threshold up", function()
        assert.are.equal("large", spill.size(LARGE, MEDIUM, LARGE))
        assert.are.equal("large", spill.size(25000, MEDIUM, LARGE))
    end)

    -- a player can drag the thresholds anywhere in range, including together
    it("follows the thresholds it is given rather than the defaults", function()
        assert.are.equal("large", spill.size(500, 100, 400))
        assert.are.equal("small", spill.size(500, 100000, 100000))
    end)

    it("never answers with a size that has no prototype", function()
        local known = {}
        for _, size in pairs(spill.SIZES) do known[size] = true end
        for _, amount in pairs{0, 1, 999, 1000, 9999, 10000, 1e9} do
            assert.is_true(known[spill.size(amount, MEDIUM, LARGE)] == true,
                "no prototype for the size chosen at " .. amount)
        end
    end)
end)

describe("how big a wreck counts as", function()
    it("measures the area of the box", function()
        assert.are.equal(4, spill.bounding_box_area{
            left_top = {x = -1, y = -1}, right_bottom = {x = 1, y = 1}})
        assert.are.equal(1, spill.bounding_box_area{
            left_top = {x = 0, y = 0}, right_bottom = {x = 1, y = 1}})
    end)

    -- a corpse prototype need not have a selection box, and asking for one that is not
    -- there used to be how this crashed
    it("counts a missing box as nothing rather than failing", function()
        assert.are.equal(0, spill.bounding_box_area(nil))
        assert.are.equal(0, spill.bounding_box_area({}))
        assert.are.equal(0, spill.bounding_box_area{right_bottom = {}})
    end)
end)
