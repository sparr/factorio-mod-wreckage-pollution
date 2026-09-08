--- The same wreckage on every surface the game has, and nothing falling over anywhere.
---
--- What each surface should actually do about it is in planets.lua. This file is about
--- coverage: every planet, and a platform, with something destroyed on it.
local world = require("test.ft.world")
local spill = require("lib.spill")

--- The surfaces that deal in a pollutant, and so still get spills
local SPILLS_HERE = { nauvis = true, gleba = true }

local function surface_of(planet)
    return game.planets[planet].surface or game.planets[planet].create_surface()
end

describe("wreckage on each planet", function()
    for planet, fluid in pairs(world.PLANET_FLUID) do
        it("destroying a full tank on " .. planet .. " does not fail", function()
            local arena = world.arena(surface_of(planet))
            world.tank(arena, fluid, 20000).die()
            if SPILLS_HERE[planet] then
                assert.are.same({ [spill.entity_name(fluid, "large")] = 1 },
                    world.spills(arena), "no spill of " .. fluid .. " on " .. planet)
            else
                assert.are.same({}, world.spills(arena),
                    planet .. " deals in no pollutant, so nothing should be left behind")
            end
        end)

        it("destroying a loaded chest on " .. planet .. " does not fail", function()
            local arena = world.arena(surface_of(planet))
            local chest = arena.surface.create_entity{
                name = "steel-chest", position = arena.centre, force = "player" }
            assert.is_not_nil(chest, "could not place a chest on " .. planet)
            chest.insert{ name = "iron-plate", count = 50 }
            chest.die()
            assert.are.same({}, world.spills(arena))
        end)

        it("destroying something with no fluid at all on " .. planet .. " does not fail",
            function()
                local arena = world.arena(surface_of(planet))
                for _, name in pairs{ "transport-belt", "small-electric-pole" } do
                    local entity = arena.surface.create_entity{
                        name = name, position = arena.centre, force = "player" }
                    assert.is_not_nil(entity, "could not place a " .. name .. " on " .. planet)
                    entity.die()
                end
            end)
    end
end)

describe("what each surface says it deals in", function()
    it("has pollution on Nauvis", function()
        assert.are.equal("pollution", game.surfaces.nauvis.pollutant_type.name)
    end)

    it("has spores on Gleba", function()
        assert.are.equal("spores", surface_of("gleba").pollutant_type.name)
    end)

    for _, planet in pairs{ "vulcanus", "fulgora", "aquilo" } do
        it("has nothing on " .. planet, function()
            assert.is_nil(surface_of(planet).pollutant_type)
        end)
    end
end)

describe("wreckage on a space platform", function()
    it("has a surface that belongs to no planet and deals in nothing", function()
        local surface = world.platform()
        assert.is_not_nil(surface, "no platform surface was made")
        assert.is_not_nil(surface.platform)
        assert.is_nil(surface.pollutant_type)
    end)

    it("survives a tank of fluid being destroyed in orbit", function()
        local arena = world.arena(world.platform())
        world.tank(arena, "water", 20000).die()
        assert.are.same({}, world.spills(arena))
    end)

    it("survives a loaded chest being destroyed in orbit", function()
        local arena = world.arena(world.platform())
        local chest = arena.surface.create_entity{
            name = "steel-chest", position = arena.centre, force = "player" }
        assert.is_not_nil(chest, "could not place a chest on the platform")
        chest.insert{ name = "steel-furnace", count = 10 }
        chest.die()
        assert.are.equal(0, arena.surface.get_pollution(arena.centre))
    end)
end)
