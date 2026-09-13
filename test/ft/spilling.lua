--- What a destroyed thing leaves on the ground.
local world = require("test.ft.world")
local spill = require("lib.spill")

describe("destroying something full of fluid", function()
    it("leaves a spill of that fluid", function()
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, "crude-oil", 20000).die()
        assert.are.same({ ["chemical-spill-crude-oil-large"] = 1 }, world.spills(arena))
    end)

    it("sizes the spill by how much was in it", function()
        local medium = settings.startup["medium_spill_threshold"].value
        local large = settings.startup["large_spill_threshold"].value
        for amount, size in pairs{
            [medium - 1] = "small", [medium] = "medium", [large] = "large",
        } do
            local arena = world.arena(game.surfaces.nauvis)
            world.tank(arena, "crude-oil", amount).die()
            assert.are.same({ [spill.entity_name("crude-oil", size)] = 1 },
                world.spills(arena),
                ("%d units of oil should leave a %s spill"):format(amount, size))
        end
    end)

    it("leaves a plain puddle where the fluid does not pollute", function()
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, "water", 20000).die()
        assert.are.same({ ["liquid-spill-water-large"] = 1 }, world.spills(arena))
    end)

    it("leaves nothing where the fluid just vents away", function()
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, "steam", 20000).die()
        assert.are.same({}, world.spills(arena))
    end)

    it("leaves nothing behind an empty tank", function()
        local arena = world.arena(game.surfaces.nauvis)
        local tank = arena.surface.create_entity{
            name = "storage-tank", position = arena.centre, force = "player" }
        tank.die()
        assert.are.same({}, world.spills(arena))
    end)
end)

describe("destroying something that holds no fluid at all", function()
    -- 1.1 gave every entity a fluidbox, empty if it held nothing. 2.1 only puts fluid on
    -- what can hold it and errors on the rest, so this was every chest, belt and biter
    -- taking the game down as it died.
    it("does not fail, whatever it is", function()
        local arena = world.arena(game.surfaces.nauvis)
        for _, name in pairs{
            "steel-chest", "transport-belt", "small-electric-pole", "stone-furnace",
        } do
            local entity = arena.surface.create_entity{
                name = name, position = { arena.centre.x + 4, arena.centre.y }, force = "player" }
            assert.is_not_nil(entity, "could not place a " .. name)
            entity.die()
        end
        assert.are.same({}, world.spills(arena))
    end)

    it("does not fail for a biter either", function()
        local arena = world.arena(game.surfaces.nauvis)
        local biter = arena.surface.create_entity{
            name = "small-biter", position = { arena.centre.x + 4, arena.centre.y },
            force = "enemy" }
        assert.is_not_nil(biter)
        biter.die()
        assert.are.same({}, world.spills(arena))
    end)
end)

describe("taking one tank out of a connected group", function()
    -- 2.0 pools fluid across a connected segment. Removing one tank leaves the fluid in
    -- the segment up to what still fits, so only the overflow is really thrown away --
    -- and only the overflow should hit the ground.
    it("spills nothing while the rest of the group can hold the fluid", function()
        for _, how in pairs{ "mined", "destroyed" } do
            local arena = world.arena(game.surfaces.nauvis)
            local tanks = world.connected_tanks(arena, 4)
            tanks[1].insert_fluid{ name = "crude-oil", amount = 20000 }
            if how == "mined" then
                game.players[1].mine_entity(tanks[1], true)
            else
                tanks[1].die()
            end
            assert.are.same({}, world.spills(arena),
                "the fluid all fits in the other three tanks (" .. how .. ")")
        end
    end)

    it("spills exactly the overflow when the group was full", function()
        local arena = world.arena(game.surfaces.nauvis)
        local tanks = world.connected_tanks(arena, 4)
        tanks[1].insert_fluid{ name = "crude-oil", amount = 100000 }
        game.players[1].mine_entity(tanks[1], true)
        -- one tank's worth, 25000, has nowhere left to go: a large spill
        assert.are.same({ ["chemical-spill-crude-oil-large"] = 1 }, world.spills(arena))
    end)
end)

describe("a fluid wagon", function()
    -- a wagon's tank belongs to no segment, so what it carries is thrown away whole
    it("spills what it was carrying when destroyed", function()
        local arena = world.arena(game.surfaces.nauvis)
        for i = -2, 2 do
            arena.surface.create_entity{
                name = "straight-rail",
                position = { arena.centre.x + 1, arena.centre.y + i * 2 },
                force = "player" }
        end
        local wagon = arena.surface.create_entity{
            name = "fluid-wagon", position = { arena.centre.x + 1, arena.centre.y },
            force = "player" }
        assert.is_not_nil(wagon, "could not place a fluid wagon")
        wagon.insert_fluid{ name = "crude-oil", amount = 20000 }
        wagon.die()
        assert.are.same({ ["chemical-spill-crude-oil-large"] = 1 }, world.spills(arena))
    end)
end)

describe("mining something full of fluid", function()
    -- the mod listens for the pre-mined events as well as death, so a tank taken apart
    -- spills what was in it rather than swallowing it
    it("leaves a spill just as destroying it does", function()
        local arena = world.arena(game.surfaces.nauvis)
        local tank = world.tank(arena, "crude-oil", 20000)
        local player = game.players[1]
        player.mine_entity(tank, true)
        assert.are.same({ ["chemical-spill-crude-oil-large"] = 1 }, world.spills(arena))
    end)
end)
