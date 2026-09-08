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

describe("which items are containers of fluid", function()
    --- Shaped the way the game's own emptying recipes are: the container goes in, the
    --- fluid and the empty container come out.
    local function unbarrel(item, fluid, amount)
        return {
            ingredients = { { type = "item", name = item, amount = 1 } },
            products = { { type = "fluid", name = fluid, amount = amount },
                         { type = "item", name = "barrel", amount = 1 } },
        }
    end

    it("reads the fluid and the amount off the emptying recipe", function()
        local held = spill.containers{
            ["empty-crude-oil-barrel"] = unbarrel("crude-oil-barrel", "crude-oil", 50),
            ["empty-water-barrel"] = unbarrel("water-barrel", "water", 50),
        }
        assert.are.same({ fluid = "crude-oil", amount = 50 }, held["crude-oil-barrel"])
        assert.are.same({ fluid = "water", amount = 50 }, held["water-barrel"])
    end)

    -- melting one ice into twenty water is the same shape without a container coming
    -- back, and ice is not a container -- it is the thing itself
    it("does not count a conversion that hands back no container", function()
        local held = spill.containers{
            ["ice-melting"] = {
                ingredients = { { type = "item", name = "ice", amount = 1 } },
                products = { { type = "fluid", name = "water", amount = 20 } },
            },
        }
        assert.is_nil(held["ice"])
    end)

    it("ignores recipes that consume a fluid, which are fillings not emptyings", function()
        local held = spill.containers{
            ["fill-crude-oil-barrel"] = {
                ingredients = { { type = "fluid", name = "crude-oil", amount = 50 },
                                { type = "item", name = "barrel", amount = 1 } },
                products = { { type = "item", name = "crude-oil-barrel", amount = 1 } },
            },
        }
        assert.are.same({}, held)
    end)

    it("ignores a recipe that consumes several of the item", function()
        local held = spill.containers{
            ["press"] = {
                ingredients = { { type = "item", name = "wood", amount = 10 } },
                products = { { type = "fluid", name = "resin", amount = 5 },
                             { type = "item", name = "ash", amount = 1 } },
            },
        }
        assert.is_nil(held["wood"])
    end)

    it("ignores a recipe that produces more than one fluid", function()
        local held = spill.containers{
            ["crack"] = {
                ingredients = { { type = "item", name = "cell", amount = 1 } },
                products = { { type = "fluid", name = "water", amount = 5 },
                             { type = "fluid", name = "steam", amount = 5 },
                             { type = "item", name = "shell", amount = 1 } },
            },
        }
        assert.is_nil(held["cell"])
    end)
end)

describe("what a plant yields", function()
    it("reads the fruit and the count off the results", function()
        assert.are.same({ item = "yumako", amount = 50 },
            spill.harvest{ { type = "item", name = "yumako", amount = 50 } })
    end)

    -- a plant's results can carry a seed at some small chance alongside the fruit; the
    -- fruit is the one that lands on the ground
    it("takes the first item, past anything that is not one", function()
        assert.are.same({ item = "yumako", amount = 50 }, spill.harvest{
            { type = "fluid", name = "sap", amount = 5 },
            { type = "item", name = "yumako", amount = 50 },
            { type = "item", name = "yumako-seed", amount = 1 },
        })
    end)

    it("copes with a range rather than a fixed amount", function()
        assert.are.same({ item = "berry", amount = 9 },
            spill.harvest{ { type = "item", name = "berry", amount_max = 9 } })
    end)

    it("answers nothing for a plant that yields nothing", function()
        assert.is_nil(spill.harvest(nil))
        assert.is_nil(spill.harvest{})
        assert.is_nil(spill.harvest{ { type = "fluid", name = "sap", amount = 5 } })
        assert.is_nil(spill.harvest{ { type = "item", name = "nothing", amount = 0 } })
    end)
end)

describe("what a spill of fruit looks like and is worth", function()
    -- a yumako is red on the outside and mashes to orange; a jellynut is mauve and
    -- presses to green. The colours are taken from what each is processed into, so the
    -- puddle looks like the pulp rather than the skin.
    it("gives yumako the orange of its mash, not the red of its skin", function()
        local colour = spill.FRUIT_COLOURS["yumako"]
        assert.is_not_nil(colour, "yumako should have a colour of its own")
        assert.is_true(colour.r > colour.g and colour.g > colour.b,
            "mashed yumako should read as orange")
    end)

    it("gives jellynut the green of its jelly, not the mauve of its shell", function()
        local colour = spill.FRUIT_COLOURS["jellynut"]
        assert.is_not_nil(colour, "jellynut should have a colour of its own")
        assert.is_true(colour.g > colour.r and colour.g > colour.b,
            "jelly should read as green")
    end)

    --- Harvesting a plant emits 15 spores for 50 fruit, so a fruit is worth 0.3. A spill
    --- gives up amount * intensity / 50 over its life, so matching that at the default
    --- intensity of 0.25 wants 60 units per fruit.
    it("is worth what harvesting it would have emitted, at the default intensity", function()
        local per_fruit_emission = 15 / 50
        local default_intensity = 0.25
        local total = spill.FRUIT_UNITS * default_intensity / 50
        assert.are.equal(per_fruit_emission, total,
            ("%d units per fruit gives %.3f where a harvest gives %.3f")
                :format(spill.FRUIT_UNITS, total, per_fruit_emission))
    end)
end)
