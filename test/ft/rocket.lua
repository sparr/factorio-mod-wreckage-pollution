--- A space platform reached the way a player reaches one.
---
--- The other platform fixtures take the shortcut the API offers and apply the starter
--- pack directly. This one schedules a platform, builds a powered silo, puts a pack in the
--- rocket and waits for the game to fly it up, so the surface under test is one the game
--- assembled through its own machinery rather than one handed over by a script.
---
--- A launch takes about forty-four seconds of game time at the prototypes' own pace,
--- nearly all of it cinematics. wp-tests flattens those, which brings the platform in at
--- tick 120 and lets this run alongside everything else rather than sitting behind a
--- blacklisted tag. It keeps the tag so it can still be run on its own:
---   test/ft/run.sh --tag-whitelist rocket
local world = require("test.ft.world")

local SILO_AT = { x = -256, y = -256 }

---Silos need a lot of clear, flat ground
local function clearing(surface, centre, radius)
    surface.request_to_generate_chunks(centre, 3)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities{
        { centre.x - radius, centre.y - radius },
        { centre.x + radius, centre.y + radius } }) do
        if entity.valid and entity.type ~= "character" then entity.destroy() end
    end
    local tiles = {}
    for x = -radius, radius do
        for y = -radius, radius do
            tiles[#tiles + 1] = {
                name = "refined-concrete", position = { centre.x + x, centre.y + y } }
        end
    end
    surface.set_tiles(tiles)
end

tags("rocket")
describe("a platform put up by an actual rocket", function()
    it("arrives, and the mod works on it", function()
        local force = game.forces.player
        force.unlock_space_platforms()
        local surface = game.surfaces.nauvis
        clearing(surface, SILO_AT, 16)

        -- a platform waiting to be built. Its surface does not exist until a rocket
        -- delivers the pack, which is the whole point of this fixture.
        local platform = force.create_space_platform{
            name = "wp-launched", planet = "nauvis",
            starter_pack = "space-platform-starter-pack" }
        assert.is_not_nil(platform, "could not schedule a platform")
        assert.is_nil(platform.surface, "the platform should not exist yet")

        local silo = surface.create_entity{
            name = "rocket-silo", position = SILO_AT, force = force }
        assert.is_not_nil(silo, "could not place a rocket silo")

        -- a silo with no electricity does nothing at all, so give it its own supply
        local power = surface.create_entity{
            name = "electric-energy-interface", position = { SILO_AT.x + 12, SILO_AT.y },
            force = force }
        assert.is_not_nil(power, "could not place a power source")
        power.power_production = 1e9
        assert.is_not_nil(surface.create_entity{
            name = "substation", position = { SILO_AT.x + 8, SILO_AT.y }, force = force },
            "could not place a pole to carry the power")

        -- skip building the rocket part by part; this fixture is about the flight
        silo.rocket_parts = silo.prototype.rocket_parts_required

        -- One poll doing both jobs: put the pack in as soon as the silo has a rocket
        -- to put it in, then watch for the platform. Ten times a second, so the timings
        -- reported are the real ones rather than an artefact of how often it looked.
        local loaded_at, arrived_at
        for tick = 6, 10 * 60, 6 do
            after_ticks(tick, function()
                if not loaded_at then
                    local rocket = silo.get_inventory(defines.inventory.rocket_silo_rocket)
                    if rocket and rocket.insert{
                        name = "space-platform-starter-pack", count = 1 } == 1 then
                        loaded_at = tick
                    end
                elseif not arrived_at and platform.valid and platform.surface then
                    arrived_at = tick
                end
            end)
        end

        after_ticks(10 * 60 + 6, function()
            assert.is_not_nil(loaded_at, "never got a starter pack into the rocket")
            assert.is_true(platform.valid, "the platform stopped existing")
            local built = platform.surface
            assert.is_not_nil(built,
                "no platform surface within ten seconds of the launch; silo status was " ..
                (silo.valid and tostring(silo.status) or "gone") ..
                ". If wp-tests has stopped flattening the launch timings, a real launch " ..
                "takes about forty-four seconds and this window is far too short.")
            print(("pack loaded at tick %d, platform arrived at tick %s")
                :format(loaded_at, tostring(arrived_at)))
            assert.is_nil(built.pollutant_type, "a platform should have no pollutant")

            -- and now the thing this whole fixture exists for: break something up there.
            -- A platform deals in no pollutant, so the mod leaves it alone; what is being
            -- checked is that it does so without falling over on a surface that arrived
            -- by rocket rather than by script.
            local arena = world.arena(built)
            world.tank(arena, "water", 20000).die()
            assert.are.same({}, world.spills(arena),
                "a platform deals in nothing, so nothing should be left behind")

            local chest = arena.surface.create_entity{
                name = "steel-chest", position = arena.centre, force = "player" }
            assert.is_not_nil(chest, "could not place a chest on the launched platform")
            chest.insert{ name = "steel-furnace", count = 10 }
            chest.die()
            assert.are.equal(0, arena.surface.get_pollution(arena.centre),
                "there is nothing on a platform for pollution to go into")
        end)
    end)
end)
