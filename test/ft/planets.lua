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
