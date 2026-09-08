--- Nothing appears from nowhere, and nothing is had twice.
---
--- The mod spills what the game throws away, so for every way of taking a thing apart
--- there is exactly one right answer: if whoever did it keeps the contents, there is no
--- spill; if the contents are lost, there is one.
local world = require("test.ft.world")

local function held(player, item)
    local inventory = player.get_main_inventory()
    return inventory and inventory.get_item_count(item) or 0
end

---How much of `item` the player gained, and what was left on the ground
---@return number, table<string, number>
local function taking_apart(arena, item, take)
    local player = game.players[1]
    local before = held(player, item)
    take(player)
    return held(player, item) - before, world.spills(arena)
end

local function gleba()
    return game.planets.gleba.surface or game.planets.gleba.create_surface()
end

--- A plant made by script starts growing from nothing
local function plant_in(arena, name, ripe)
    local plant = arena.surface.create_entity{
        name = name, position = arena.centre, force = "neutral" }
    assert.is_not_nil(plant, "could not plant a " .. name)
    if ripe then plant.tick_grown = 1 end
    return plant
end

local function chest_in(arena, item, count)
    local chest = arena.surface.create_entity{
        name = "steel-chest", position = arena.centre, force = "player" }
    assert.is_not_nil(chest)
    chest.insert{ name = item, count = count }
    return chest
end

describe("a ripe fruit tree", function()
    it("gives its fruit to whoever fells it, and spills none", function()
        local arena = world.arena(gleba())
        local tree = plant_in(arena, "yumako-tree", true)
        local gained, spills = taking_apart(arena, "yumako", function(player)
            player.mine_entity(tree, true)
        end)
        assert.are.equal(50, gained, "felling a ripe tree should hand over its fruit")
        assert.are.same({}, spills, "and so there is nothing left to spill")
    end)

    it("spills its fruit when destroyed, since nobody catches it", function()
        local arena = world.arena(gleba())
        local tree = plant_in(arena, "yumako-tree", true)
        local gained, spills = taking_apart(arena, "yumako", function() tree.die() end)
        assert.are.equal(0, gained)
        assert.are.same({ ["chemical-spill-yumako-medium"] = 1 }, spills)
    end)
end)

describe("an unripe fruit tree", function()
    -- it has no fruit on it yet, so there is none to hand over and none to spill
    it("gives nothing and spills nothing, however it is taken", function()
        for _, how in pairs{ "mined", "destroyed" } do
            local arena = world.arena(gleba())
            local tree = plant_in(arena, "yumako-tree", false)
            local gained, spills = taking_apart(arena, "yumako", function(player)
                if how == "mined" then player.mine_entity(tree, true) else tree.die() end
            end)
            assert.are.equal(0, gained, "an unripe tree has no fruit to give (" .. how .. ")")
            assert.are.same({}, spills, "nor any to spill (" .. how .. ")")
        end
    end)
end)

describe("a container of fruit", function()
    it("hands its fruit to whoever takes it apart, and spills none", function()
        local arena = world.arena(gleba())
        local chest = chest_in(arena, "yumako", 100)
        local gained, spills = taking_apart(arena, "yumako", function(player)
            player.mine_entity(chest, true)
        end)
        assert.are.equal(100, gained)
        assert.are.same({}, spills)
    end)

    it("spills its fruit when destroyed", function()
        local arena = world.arena(gleba())
        local chest = chest_in(arena, "yumako", 100)
        local gained, spills = taking_apart(arena, "yumako", function() chest.die() end)
        assert.are.equal(0, gained)
        assert.are.same({ ["chemical-spill-yumako-medium"] = 1 }, spills)
    end)
end)

describe("a container of barrels", function()
    it("hands the barrels over when taken apart, and spills none", function()
        local arena = world.arena(game.surfaces.nauvis)
        local chest = chest_in(arena, "crude-oil-barrel", 40)
        local gained, spills = taking_apart(arena, "crude-oil-barrel", function(player)
            player.mine_entity(chest, true)
        end)
        assert.are.equal(40, gained)
        assert.are.same({}, spills)
    end)

    it("spills what was in them when destroyed", function()
        local arena = world.arena(game.surfaces.nauvis)
        local chest = chest_in(arena, "crude-oil-barrel", 40)
        local gained, spills = taking_apart(arena, "crude-oil-barrel", function()
            chest.die()
        end)
        assert.are.equal(0, gained)
        assert.are.same({ ["chemical-spill-crude-oil-medium"] = 1 }, spills)
    end)
end)

describe("a tank of fluid", function()
    -- the game throws the fluid away either way, so it is spilled either way
    it("spills when taken apart, because the fluid is lost either way", function()
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, "crude-oil", 20000)
        local tank = arena.surface.find_entities_filtered{
            name = "storage-tank",
            area = { { arena.centre.x - 2, arena.centre.y - 2 },
                     { arena.centre.x + 2, arena.centre.y + 2 } } }[1]
        game.players[1].mine_entity(tank, true)
        assert.are.same({ ["chemical-spill-crude-oil-large"] = 1 }, world.spills(arena))
    end)

    it("spills when destroyed", function()
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, "crude-oil", 20000).die()
        assert.are.same({ ["chemical-spill-crude-oil-large"] = 1 }, world.spills(arena))
    end)
end)
