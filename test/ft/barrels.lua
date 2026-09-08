--- Barrels spill what is in them.
---
--- Reported on GitHub: destroying a chest full of barrels left nothing on the ground,
--- even though the game knows exactly how much of what each barrel holds.
local world = require("test.ft.world")

---A chest holding some barrels, destroyed
---@param arena table
---@param barrel string
---@param count number
local function wreck_a_chest_of(arena, barrel, count)
    local chest = arena.surface.create_entity{
        name = "steel-chest", position = arena.centre, force = "player" }
    assert.is_not_nil(chest, "could not place a chest")
    assert.are.equal(count, chest.insert{ name = barrel, count = count },
        "could not fill the chest with " .. barrel)
    chest.die()
end

describe("destroying barrels", function()
    it("spills what a barrel of oil was holding", function()
        local arena = world.arena(game.surfaces.nauvis)
        wreck_a_chest_of(arena, "crude-oil-barrel", 1)
        -- one barrel is fifty units, which is a small spill
        assert.are.same({ ["chemical-spill-crude-oil-small"] = 1 }, world.spills(arena))
    end)

    it("adds the barrels up into one spill rather than one each", function()
        local arena = world.arena(game.surfaces.nauvis)
        wreck_a_chest_of(arena, "crude-oil-barrel", 40)
        -- forty barrels is two thousand units, which is a medium spill
        assert.are.same({ ["chemical-spill-crude-oil-medium"] = 1 }, world.spills(arena))
    end)

    it("tells the fluids apart", function()
        local arena = world.arena(game.surfaces.nauvis)
        local chest = arena.surface.create_entity{
            name = "steel-chest", position = arena.centre, force = "player" }
        chest.insert{ name = "crude-oil-barrel", count = 5 }
        chest.insert{ name = "water-barrel", count = 5 }
        chest.die()
        assert.are.same({
            ["chemical-spill-crude-oil-small"] = 1,
            ["liquid-spill-water-small"] = 1,
        }, world.spills(arena))
    end)

    -- laid on the same tile they would cover each other exactly, and only one of the two
    -- could be seen
    it("does not lay two spills on top of one another", function()
        local arena = world.arena(game.surfaces.nauvis)
        local chest = arena.surface.create_entity{
            name = "steel-chest", position = arena.centre, force = "player" }
        chest.insert{ name = "crude-oil-barrel", count = 5 }
        chest.insert{ name = "water-barrel", count = 5 }
        chest.die()
        local found = {}
        local r = arena.radius + 4
        for _, entity in pairs(arena.surface.find_entities_filtered{
            type = "simple-entity",
            area = { { arena.centre.x - r, arena.centre.y - r },
                     { arena.centre.x + r, arena.centre.y + r } } }) do
            if entity.name:find("spill") then found[#found + 1] = entity end
        end
        assert.are.equal(2, #found, "expected one spill of each")
        local dx = found[1].position.x - found[2].position.x
        local dy = found[1].position.y - found[2].position.y
        local apart = math.sqrt(dx * dx + dy * dy)
        assert.is_true(apart > 0, "the two spills are on the same tile, one hiding the other")
        -- but only just: a small spill's sprite is two tiles across, so anything under
        -- that leaves them lying over one another with both still showing. Pushed the
        -- full width of the sprite they would read as two separate accidents.
        assert.is_true(apart < 2,
            ("the two spills ended up %.2f tiles apart, too far to read as one mess")
                :format(apart))
    end)

    it("leaves nothing for an empty barrel", function()
        local arena = world.arena(game.surfaces.nauvis)
        wreck_a_chest_of(arena, "barrel", 50)
        assert.are.same({}, world.spills(arena))
    end)

    -- ice melts into water by a recipe shaped just like an emptying one, but it hands
    -- back no container, so it is the thing itself rather than something holding a thing
    it("leaves nothing for a chest of ice", function()
        local arena = world.arena(game.surfaces.nauvis)
        wreck_a_chest_of(arena, "ice", 50)
        assert.are.same({}, world.spills(arena))
    end)

    it("spills barrels carried in a destroyed vehicle too", function()
        local arena = world.arena(game.surfaces.nauvis)
        local car = arena.surface.create_entity{
            name = "car", position = arena.centre, force = "player" }
        assert.is_not_nil(car)
        car.insert{ name = "crude-oil-barrel", count = 10 }
        car.die()
        assert.are.same({ ["chemical-spill-crude-oil-small"] = 1 }, world.spills(arena))
    end)

    it("leaves nothing on a surface that deals in no pollutant", function()
        local surface = game.planets.vulcanus.surface or game.planets.vulcanus.create_surface()
        local arena = world.arena(surface)
        wreck_a_chest_of(arena, "crude-oil-barrel", 40)
        assert.are.same({}, world.spills(arena))
    end)
end)
