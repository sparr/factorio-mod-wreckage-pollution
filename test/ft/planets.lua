--- Doing nothing where there is nothing to do, and the right thing where there is.
---
--- 2.0 gave the game surfaces that deal in no pollutant at all and one that deals in
--- spores rather than pollution. Neither wants what Nauvis wants.
local world = require("test.ft.world")

--- Every planet the game says has no pollutant, plus the platform
local NO_POLLUTANT = { "vulcanus", "fulgora", "aquilo" }

describe("a surface that deals in no pollutant", function()
    for _, planet in pairs(NO_POLLUTANT) do
        it("leaves no spill behind a wrecked tank on " .. planet, function()
            local surface = game.planets[planet].surface or game.planets[planet].create_surface()
            assert.is_nil(surface.pollutant_type)
            local arena = world.arena(surface)
            world.tank(arena, world.PLANET_FLUID[planet], 20000).die()
            assert.are.same({}, world.spills(arena),
                "a spill on " .. planet .. " would sit there being processed for nothing")
        end)
    end

    it("leaves no spill on a space platform either", function()
        local arena = world.arena(world.platform())
        world.tank(arena, "water", 20000).die()
        assert.are.same({}, world.spills(arena))
    end)

    -- a save made before this rule can still be carrying spills that nothing will ever
    -- evaporate, so they are cleared as they are come across
    it("clears away a spill left over from before", function()
        local surface = game.planets.vulcanus.surface or game.planets.vulcanus.create_surface()
        local arena = world.arena(surface)
        local leftover = surface.create_entity{
            name = "chemical-spill-lava-large", position = arena.centre, force = "neutral" }
        assert.is_not_nil(leftover)
        storage.pollution_sources[#storage.pollution_sources + 1] = {
            entity = leftover, amount = 20000, size = "large", fluid = "lava", tick = 0 }
        after_ticks(180, function()
            assert.are.same({}, world.spills(arena), "the stranded spill is still there")
        end)
    end)
end)

describe("Gleba, which deals in spores", function()
    local function gleba()
        return game.planets.gleba.surface or game.planets.gleba.create_surface()
    end

    it("counts a felled plant, which is what makes spores there", function()
        local surface = gleba()
        assert.are.equal("spores", surface.pollutant_type.name)
        local arena = world.arena(surface)
        local plant = surface.create_entity{
            name = "yumako-tree", position = arena.centre, force = "neutral" }
        assert.is_not_nil(plant, "could not plant a yumako tree")
        plant.die()
        assert.is_true(surface.get_pollution(arena.centre) > 0,
            "felling a yumako tree should give up its spores")
    end)

    -- an assembler is not what makes spores on Gleba, so wrecking one makes none
    it("does not count a wrecked machine", function()
        local surface = gleba()
        local arena = world.arena(surface)
        local machine = surface.create_entity{
            name = "steel-furnace", position = arena.centre, force = "player" }
        assert.is_not_nil(machine)
        machine.die()
        assert.are.equal(0, surface.get_pollution(arena.centre),
            "a furnace does not make spores, so wrecking one should not either")
    end)

    it("still leaves a spill of what was in a tank", function()
        local arena = world.arena(gleba())
        world.tank(arena, "fluoroketone-hot", 20000).die()
        assert.are.same({ ["chemical-spill-fluoroketone-hot-large"] = 1 },
            world.spills(arena))
    end)
end)

describe("Nauvis, which deals in pollution", function()
    -- reported on GitHub: biters knocking trees down in places nobody has been was
    -- putting pollution there, and a forest is what takes pollution out of the air
    it("does not count a felled tree", function()
        local arena = world.arena(game.surfaces.nauvis)
        local tree = arena.surface.create_entity{
            name = "tree-01", position = arena.centre, force = "neutral" }
        assert.is_not_nil(tree, "could not plant a tree")
        tree.die()
        assert.are.equal(0, arena.surface.get_pollution(arena.centre),
            "felling a tree should not pollute")
    end)

    it("still counts a wrecked machine", function()
        local arena = world.arena(game.surfaces.nauvis)
        local furnace = arena.surface.create_entity{
            name = "steel-furnace", position = arena.centre, force = "player" }
        furnace.die()
        assert.is_true(arena.surface.get_pollution(arena.centre) > 0)
    end)
end)
