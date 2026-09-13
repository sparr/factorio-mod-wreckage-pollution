--- Somewhere to break things, on every kind of surface the game has.
---
--- The mod reacts to entities dying anywhere, and 2.0 gave the game four more planets and
--- a kind of surface that belongs to no planet at all, each with its own idea of what
--- pollution even is. So the fixtures run against all of them rather than against Nauvis
--- and a hope.
local world = {}

--- Each planet paired with a fluid it actually produces, so the spill prototype under
--- test is one that planet's own mod data contributed rather than a vanilla stand-in.
world.PLANET_FLUID = {
    nauvis = "crude-oil",
    vulcanus = "lava",
    gleba = "fluoroketone-hot",
    fulgora = "holmium-solution",
    aquilo = "ammonia",
}

--- Arenas are handed out in a row, far enough apart that one fixture's wreckage is never
--- inside another's, and far from the origin so nothing a scenario placed there is in the
--- way.
local ORIGIN = 512
local SPACING = 64
local RADIUS = 12

---Every surface worth testing on: the five planets, plus a space platform, which has no
---planet and no pollution of any kind.
---@return table<string, LuaSurface>
function world.surfaces()
    storage.test_surfaces = storage.test_surfaces or {}
    local found = {}
    for name in pairs(world.PLANET_FLUID) do
        local planet = game.planets[name]
        if planet then
            found[name] = planet.surface or planet.create_surface()
        end
    end
    local platform = world.platform()
    if platform then found.platform = platform end
    return found
end

---A space platform's surface, made the quick way: the game will hand one over as soon as
---the starter pack is applied, without waiting for a rocket to carry one up. The fixture
---that insists on a real launch is in rocket.lua.
---@return LuaSurface?
function world.platform()
    local force = game.forces.player
    if storage.test_platform then
        local existing = game.surfaces[storage.test_platform]
        if existing and existing.valid then return existing end
    end
    force.unlock_space_platforms()
    local platform = force.create_space_platform{
        name = "wp-tests", planet = "nauvis",
        starter_pack = "space-platform-starter-pack",
    }
    if not platform then return nil end
    platform.apply_starter_pack()
    local surface = platform.surface
    if surface then storage.test_platform = surface.name end
    return surface
end

---A cleared, paved square to work in. Every fixture gets its own, so nothing another
---fixture left behind can be mistaken for what this one made.
---
---A platform is left as it is: its foundation is the only place an entity can stand, and
---paving over it is neither possible nor wanted.
---@param surface LuaSurface
---@return {surface: LuaSurface, centre: MapPosition, radius: number}
function world.arena(surface)
    storage.test_arenas = storage.test_arenas or {}
    local taken = storage.test_arenas[surface.name] or 0
    storage.test_arenas[surface.name] = taken + 1
    local centre = { x = ORIGIN + taken * SPACING, y = ORIGIN }

    if surface.platform then
        -- the hub sits at the middle of the foundation, so work off to one side of it
        centre = { x = 3, y = 3 }
        return { surface = surface, centre = centre, radius = 2 }
    end

    surface.request_to_generate_chunks(centre, 2)
    surface.force_generate_chunk_requests()

    local area = {
        { centre.x - RADIUS, centre.y - RADIUS },
        { centre.x + RADIUS, centre.y + RADIUS },
    }
    for _, entity in pairs(surface.find_entities(area)) do
        if entity.valid and entity.type ~= "character" then entity.destroy() end
    end
    local tiles = {}
    for x = -RADIUS, RADIUS do
        for y = -RADIUS, RADIUS do
            tiles[#tiles + 1] = {
                name = "refined-concrete",
                position = { centre.x + x, centre.y + y },
            }
        end
    end
    surface.set_tiles(tiles)
    surface.clear_pollution()
    return { surface = surface, centre = centre, radius = RADIUS }
end

---A tank of the given fluid, standing in the arena.
---@param arena {surface: LuaSurface, centre: MapPosition}
---@param fluid string
---@param amount number
---@return LuaEntity
function world.tank(arena, fluid, amount)
    local tank = arena.surface.create_entity{
        name = "storage-tank", position = arena.centre, force = "player",
    }
    assert(tank, "could not place a storage tank on " .. arena.surface.name)
    tank.insert_fluid{ name = fluid, amount = amount }
    return tank
end

---A group of storage tanks joined into one fluid segment, corner to corner in a
---diagonal line. Each is asserted onto the same segment as the first, so a fixture
---failing here says the tanks did not connect rather than pretending the mod misbehaved.
---@param arena {surface: LuaSurface, centre: MapPosition}
---@param n number
---@return LuaEntity[]
function world.connected_tanks(arena, n)
    local c = arena.centre
    local tanks = {}
    for i = 0, n - 1 do
        local tank = arena.surface.create_entity{
            name = "storage-tank",
            position = { c.x - 5 + i * 3, c.y - 4 + i * 2 },
            force = "player",
        }
        assert(tank, "could not place tank " .. i + 1 .. " on " .. arena.surface.name)
        tanks[i + 1] = tank
    end
    local segment = tanks[1].get_fluid_segment_id(1)
    for i = 2, n do
        assert(segment == tanks[i].get_fluid_segment_id(1),
            "tank " .. i .. " did not join the segment")
    end
    return tanks
end

---Every spill entity in an arena, by prototype name.
---@param arena {surface: LuaSurface, centre: MapPosition, radius: number}
---@return table<string, number>
function world.spills(arena)
    local found = {}
    local r = arena.radius + 4
    for _, entity in pairs(arena.surface.find_entities_filtered{
        type = "simple-entity",
        area = {
            { arena.centre.x - r, arena.centre.y - r },
            { arena.centre.x + r, arena.centre.y + r },
        },
    }) do
        if entity.name:find("^chemical%-spill%-") or entity.name:find("^liquid%-spill%-") then
            found[entity.name] = (found[entity.name] or 0) + 1
        end
    end
    return found
end

---How many spills of any kind are in an arena.
---@param arena table
---@return number
function world.spill_count(arena)
    local total = 0
    for _, n in pairs(world.spills(arena)) do total = total + n end
    return total
end

return world
