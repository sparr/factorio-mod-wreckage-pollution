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

describe("Gleba, where the spores come from the plants", function()
    local function gleba()
        return game.planets.gleba.surface or game.planets.gleba.create_surface()
    end

    --- A plant made by script starts growing from nothing, and an unripe one has no fruit
    --- on it to lose.
    local function ripe_plant(arena, name)
        local plant = arena.surface.create_entity{
            name = name, position = arena.centre, force = "neutral" }
        assert.is_not_nil(plant, "could not plant a " .. name)
        plant.tick_grown = 1
        return plant
    end

    -- An agricultural tower raises its own events when it picks a crop, and already puts
    -- the spores for that into the air. This mod answers none of those events, so a
    -- harvested plant is not also a spilled one.
    it("leaves a felled plant's fruit on the ground", function()
        local surface = gleba()
        assert.are.equal("spores", surface.pollutant_type.name)
        local arena = world.arena(surface)
        ripe_plant(arena, "yumako-tree").die()
        assert.are.same({ ["chemical-spill-yumako-small"] = 1 }, world.spills(arena),
            "felling a yumako tree should leave its fruit on the ground")
    end)

    it("does the same for a jellystem", function()
        local arena = world.arena(gleba())
        ripe_plant(arena, "jellystem").die()
        assert.are.same({ ["chemical-spill-jellynut-small"] = 1 }, world.spills(arena))
    end)

    it("spills the fruit out of a destroyed container", function()
        local arena = world.arena(gleba())
        local chest = arena.surface.create_entity{
            name = "steel-chest", position = arena.centre, force = "player" }
        assert.is_not_nil(chest)
        chest.insert{ name = "yumako", count = 100 }
        chest.die()
        assert.are.same({ ["chemical-spill-yumako-small"] = 1 }, world.spills(arena))
    end)

    -- the plants make the spores there, so nothing else does
    it("puts nothing into the air for a wrecked machine", function()
        local surface = gleba()
        local arena = world.arena(surface)
        local machine = surface.create_entity{
            name = "steel-furnace", position = arena.centre, force = "player" }
        assert.is_not_nil(machine)
        machine.die()
        assert.are.equal(0, surface.get_pollution(arena.centre),
            "a furnace does not make spores, so wrecking one should not either")
    end)

    -- but the fruit rotting does, the same way any other spill gives off what it is made
    -- of as it goes
    it("gives off spores as the spilled fruit goes", function()
        local arena = world.arena(gleba())
        ripe_plant(arena, "yumako-tree").die()
        local first
        after_ticks(2, function() first = arena.surface.get_pollution(arena.centre) end)
        after_ticks(300, function()
            assert.is_true(arena.surface.get_pollution(arena.centre) > first,
                "spilled fruit should be giving off spores as it rots")
        end)
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
