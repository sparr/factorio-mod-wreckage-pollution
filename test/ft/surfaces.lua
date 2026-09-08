--- The same wreckage on every surface the game has.
---
--- 2.0 brought four more planets and the space platform, and they do not agree about what
--- pollution is: Nauvis has pollution, Gleba has spores, and Vulcanus, Fulgora, Aquilo and
--- every platform have no pollutant at all.
local world = require("test.ft.world")
local spill = require("lib.spill")

describe("wreckage on each planet", function()
    for planet, fluid in pairs(world.PLANET_FLUID) do
        it("leaves a spill of that planet's own fluid on " .. planet, function()
            local surface = game.planets[planet].surface or game.planets[planet].create_surface()
            local arena = world.arena(surface)
            world.tank(arena, fluid, 20000).die()
            assert.are.same({ [spill.entity_name(fluid, "large")] = 1 }, world.spills(arena),
                "no spill of " .. fluid .. " on " .. planet)
        end)

        it("survives destroying something with no fluid in it on " .. planet, function()
            local surface = game.planets[planet].surface or game.planets[planet].create_surface()
            local arena = world.arena(surface)
            local chest = arena.surface.create_entity{
                name = "steel-chest", position = arena.centre, force = "player" }
            assert.is_not_nil(chest, "could not place a chest on " .. planet)
            chest.insert{ name = "iron-plate", count = 50 }
            chest.die()
            assert.are.same({}, world.spills(arena))
        end)
    end
end)

describe("pollution follows what the surface actually has", function()
    it("puts pollution into Nauvis, which has some", function()
        local surface = game.surfaces.nauvis
        assert.is_not_nil(surface.pollutant_type, "Nauvis should have a pollutant")
        local arena = world.arena(surface)
        local furnace = arena.surface.create_entity{
            name = "steel-furnace", position = arena.centre, force = "player" }
        furnace.die()
        assert.is_true(arena.surface.get_pollution(arena.centre) > 0)
    end)

    -- Vulcanus, Fulgora and Aquilo have no pollutant type. pollute() is a no-op there
    -- rather than an error, which is the only reason the mod is safe on them at all.
    for _, planet in pairs{ "vulcanus", "fulgora", "aquilo" } do
        it("does not fail on " .. planet .. ", which has no pollutant", function()
            local surface = game.planets[planet].surface or game.planets[planet].create_surface()
            assert.is_nil(surface.pollutant_type,
                planet .. " was expected to have no pollutant")
            local arena = world.arena(surface)
            local furnace = arena.surface.create_entity{
                name = "steel-furnace", position = arena.centre, force = "player" }
            assert.is_not_nil(furnace, "could not place a furnace on " .. planet)
            furnace.die()
            assert.are.equal(0, arena.surface.get_pollution(arena.centre),
                "there is nothing on " .. planet .. " for pollution to go into")
        end)
    end

    it("puts spores into Gleba, which counts those instead", function()
        local surface = game.planets.gleba.surface or game.planets.gleba.create_surface()
        local pollutant = surface.pollutant_type
        assert.is_not_nil(pollutant, "Gleba should have a pollutant")
        assert.are.equal("spores", pollutant.name)
        local arena = world.arena(surface)
        local furnace = arena.surface.create_entity{
            name = "steel-furnace", position = arena.centre, force = "player" }
        furnace.die()
        -- the mod does not yet ask what the pollutant means, so a wreck on Gleba emits
        -- spores. Whether it should is a question for 2.1.2, not a crash.
        assert.is_true(arena.surface.get_pollution(arena.centre) > 0)
    end)
end)

describe("wreckage on a space platform", function()
    it("has a surface that belongs to no planet", function()
        local surface = world.platform()
        assert.is_not_nil(surface, "no platform surface was made")
        assert.is_not_nil(surface.platform)
        assert.is_nil(surface.pollutant_type)
    end)

    it("survives a tank of fluid being destroyed in orbit", function()
        local surface = world.platform()
        local arena = world.arena(surface)
        world.tank(arena, "water", 20000).die()
        assert.are.same({ ["liquid-spill-water-large"] = 1 }, world.spills(arena))
    end)

    it("survives a loaded chest being destroyed in orbit", function()
        local surface = world.platform()
        local arena = world.arena(surface)
        local chest = arena.surface.create_entity{
            name = "steel-chest", position = arena.centre, force = "player" }
        assert.is_not_nil(chest, "could not place a chest on the platform")
        chest.insert{ name = "steel-furnace", count = 10 }
        chest.die()
        assert.are.equal(0, arena.surface.get_pollution(arena.centre))
    end)
end)
