--- What the game itself does when a plant is taken, with no help from here.
---
--- The rule this mod follows for plants rests on these three facts, so they are asserted
--- rather than assumed: picking a ripe plant already emits a harvest of spores, and
--- destroying one emits nothing at all. That is why destroying a plant is where this mod
--- adds a harvest of its own, and picking one is where it keeps out of the way.
local world = require("test.ft.world")

local function gleba()
    return game.planets.gleba.surface or game.planets.gleba.create_surface()
end

local function ripe_tree(arena)
    local tree = arena.surface.create_entity{
        name = "yumako-tree", position = arena.centre, force = "neutral" }
    tree.tick_grown = 1
    return tree
end

describe("what the game does by itself", function()
    it("emits a harvest of spores when a ripe plant is picked", function()
        local arena = world.arena(gleba())
        local tree = ripe_tree(arena)
        arena.surface.clear_pollution()
        local before = arena.surface.get_pollution(arena.centre)
        game.players[1].mine_entity(tree, true)
        local after = arena.surface.get_pollution(arena.centre)
        assert.are.equal(15, after - before,
            "the game emits harvest_emissions when a ripe plant is picked")
    end)

    it("emits nothing when a ripe plant is destroyed", function()
        local arena = world.arena(gleba())
        local tree = ripe_tree(arena)
        arena.surface.clear_pollution()
        local before = arena.surface.get_pollution(arena.centre)
        tree.die()
        local after = arena.surface.get_pollution(arena.centre)
        -- 15 of what is there now is this mod standing in for the harvest that did not
        -- happen; the game itself contributes nothing
        assert.are.equal(15, after - before)
    end)

    it("emits nothing when an unripe plant is picked", function()
        local arena = world.arena(gleba())
        local tree = arena.surface.create_entity{
            name = "yumako-tree", position = arena.centre, force = "neutral" }
        arena.surface.clear_pollution()
        local before = arena.surface.get_pollution(arena.centre)
        game.players[1].mine_entity(tree, true)
        local after = arena.surface.get_pollution(arena.centre)
        assert.are.equal(0, after - before, "an unripe plant has nothing to give up")
    end)
end)
