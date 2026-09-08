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
    it("throws two spills clear of one another without lining them up", function()
        local arena = world.arena(game.surfaces.nauvis)
        local chest = arena.surface.create_entity{
            name = "steel-chest", position = arena.centre, force = "player" }
        chest.insert{ name = "crude-oil-barrel", count = 5 }
        chest.insert{ name = "water-barrel", count = 5 }
        -- where the chest really stands, which is half a tile off the arena centre: a
        -- chest snaps to the grid even though a spill no longer does
        local wreck = chest.position
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

        local function from_wreck(entity)
            local ex = entity.position.x - wreck.x
            local ey = entity.position.y - wreck.y
            return math.sqrt(ex * ex + ey * ey)
        end
        -- both are small spills, thrown up to half a tile plus a quarter for the second
        local room = 0.5 + 0.25
        for _, entity in pairs(found) do
            assert.is_true(from_wreck(entity) <= room + 0.001,
                ("a spill landed %.2f tiles out, past the %.2f it is allowed")
                    :format(from_wreck(entity), room))
        end

        local dx = found[1].position.x - found[2].position.x
        local dy = found[1].position.y - found[2].position.y
        assert.is_true(math.sqrt(dx * dx + dy * dy) > 0,
            "the two spills are on the same spot, one hiding the other")
    end)

    -- Guards the scatter against being rounded away. Rounding the throw to whole tiles
    -- is what an earlier attempt at this did, back when the wreck's own position was
    -- mistaken for the spill's and the game looked as though it were snapping them.
    it("throws them to real positions rather than to tile centres", function()
        local off_grid = 0
        for _ = 1, 8 do
            local arena = world.arena(game.surfaces.nauvis)
            local chest = arena.surface.create_entity{
                name = "steel-chest", position = arena.centre, force = "player" }
            chest.insert{ name = "crude-oil-barrel", count = 5 }
            chest.insert{ name = "water-barrel", count = 5 }
            chest.die()
            local r = arena.radius + 4
            for _, entity in pairs(arena.surface.find_entities_filtered{
                type = "simple-entity",
                area = { { arena.centre.x - r, arena.centre.y - r },
                         { arena.centre.x + r, arena.centre.y + r } } }) do
                if entity.name:find("spill") then
                    local fx = math.abs(entity.position.x % 1 - 0.5)
                    local fy = math.abs(entity.position.y % 1 - 0.5)
                    if fx > 0.05 or fy > 0.05 then off_grid = off_grid + 1 end
                end
            end
        end
        assert.is_true(off_grid > 0,
            "every one of sixteen thrown spills landed on a tile centre, so the throw is "
            .. "being rounded and the scatter is lost")
    end)

    it("puts a lone spill exactly where the wreck was", function()
        local arena = world.arena(game.surfaces.nauvis)
        local chest = arena.surface.create_entity{
            name = "steel-chest", position = arena.centre, force = "player" }
        chest.insert{ name = "crude-oil-barrel", count = 5 }
        local wreck = chest.position
        chest.die()
        local found = arena.surface.find_entities_filtered{
            type = "simple-entity",
            area = { { arena.centre.x - 8, arena.centre.y - 8 },
                     { arena.centre.x + 8, arena.centre.y + 8 } } }
        assert.are.equal(1, #found)
        -- nothing was thrown anywhere, and snap_to_grid is off, so it is exactly there
        assert.are.equal(wreck.x, found[1].position.x)
        assert.are.equal(wreck.y, found[1].position.y)
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
