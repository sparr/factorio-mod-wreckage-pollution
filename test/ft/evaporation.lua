--- What a spill does over the seconds after it appears.
local world = require("test.ft.world")

--- The default evaporation is half a percent a second, which would take a couple of
--- thousand ticks to shrink a full tank one size. The rate is a runtime setting, so the
--- fixtures turn it up and put it back rather than sitting through that.
local FAST = 0.5

local saved
local function hurry_evaporation()
    saved = settings.global["pollution_evaporation"].value
    settings.global["pollution_evaporation"] = { value = FAST }
end
local function restore_evaporation()
    if saved then settings.global["pollution_evaporation"] = { value = saved } end
    saved = nil
end

describe("a spill left alone", function()
    before_each(hurry_evaporation)
    after_each(restore_evaporation)

    it("shrinks down through the sizes and then goes away", function()
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, "crude-oil", 20000).die()
        assert.are.same({ ["chemical-spill-crude-oil-large"] = 1 }, world.spills(arena))

        local seen = {}
        for second = 1, 40 do
            after_ticks(second * 60, function()
                for name in pairs(world.spills(arena)) do seen[name] = true end
            end)
        end
        after_ticks(41 * 60, function()
            -- it passed through both smaller sizes on the way rather than jumping
            assert.is_true(seen["chemical-spill-crude-oil-medium"] == true,
                "never became a medium spill")
            assert.is_true(seen["chemical-spill-crude-oil-small"] == true,
                "never became a small spill")
            assert.are.same({}, world.spills(arena), "the spill never went away")
        end)
    end)

    it("keeps its health in step with how much is left", function()
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, "crude-oil", 20000).die()
        local first
        after_ticks(90, function()
            local found = arena.surface.find_entities_filtered{
                type = "simple-entity",
                area = { { arena.centre.x - 4, arena.centre.y - 4 },
                         { arena.centre.x + 4, arena.centre.y + 4 } } }
            assert.is_true(#found > 0, "the spill vanished too soon")
            first = found[1].health
            assert.is_true(first > 0, "a fresh spill should have health left")
        end)
        after_ticks(210, function()
            local found = arena.surface.find_entities_filtered{
                type = "simple-entity",
                area = { { arena.centre.x - 4, arena.centre.y - 4 },
                         { arena.centre.x + 4, arena.centre.y + 4 } } }
            if #found > 0 then
                assert.is_true(found[1].health < first,
                    ("health did not fall: %.1f then %.1f"):format(first, found[1].health))
            end
        end)
    end)
end)

describe("pollution from a spill", function()
    before_each(hurry_evaporation)
    after_each(restore_evaporation)

    --- Destroying the tank pollutes for the tank's own wreckage, all at once, before any
    --- spill has evaporated. So the question is not whether there is pollution but
    --- whether it goes on rising afterwards, which only the spill can do -- and the game
    --- is spreading and absorbing that cloud the whole time, so a chunk left alone loses
    --- pollution rather than holding still.
    ---@param fluid string
    ---@param done fun(first: number, later: number)
    local function pollution_growth(fluid, done)
        local arena = world.arena(game.surfaces.nauvis)
        world.tank(arena, fluid, 20000).die()
        local first
        after_ticks(2, function() first = arena.surface.get_pollution(arena.centre) end)
        after_ticks(300, function()
            done(first, arena.surface.get_pollution(arena.centre))
        end)
    end

    it("goes on rising while a chemical spill sits there", function()
        pollution_growth("crude-oil", function(first, later)
            assert.is_true(later > first,
                ("pollution was %.1f just after the wreck and %.1f later, so the spill "
                 .. "added nothing"):format(first, later))
        end)
    end)

    it("stops rising once a puddle of water is all that is left", function()
        pollution_growth("water", function(first, later)
            assert.is_true(later <= first,
                ("the cloud grew from %.1f to %.1f, and water should not be feeding it")
                    :format(first, later))
        end)
    end)
end)

describe("pollution from wreckage", function()
    it("rises when something with remnants is destroyed", function()
        local arena = world.arena(game.surfaces.nauvis)
        local furnace = arena.surface.create_entity{
            name = "steel-furnace", position = arena.centre, force = "player" }
        assert.is_not_nil(furnace)
        furnace.die()
        assert.is_true(arena.surface.get_pollution(arena.centre) > 0,
            "a destroyed furnace should pollute for its remnants")
    end)

    -- the mod deliberately spares biters, whose corpses would otherwise make defending
    -- yourself the biggest polluter on the map
    it("does not rise for a biter", function()
        local arena = world.arena(game.surfaces.nauvis)
        local biter = arena.surface.create_entity{
            name = "small-biter", position = arena.centre, force = "enemy" }
        assert.is_not_nil(biter)
        biter.die()
        assert.are.equal(0, arena.surface.get_pollution(arena.centre))
    end)

    it("rises for what was inside a destroyed chest, not just the chest", function()
        local bare = world.arena(game.surfaces.nauvis)
        local empty = bare.surface.create_entity{
            name = "steel-chest", position = bare.centre, force = "player" }
        empty.die()
        local without = bare.surface.get_pollution(bare.centre)

        local packed = world.arena(game.surfaces.nauvis)
        local full = packed.surface.create_entity{
            name = "steel-chest", position = packed.centre, force = "player" }
        full.insert{ name = "steel-furnace", count = 10 }
        full.die()
        local with = packed.surface.get_pollution(packed.centre)

        -- 2.0 changed get_contents out from under this, and the walk over a destroyed
        -- entity's inventories quietly stopped finding anything
        assert.is_true(with > without,
            ("a chest of furnaces polluted %.1f against an empty chest's %.1f")
                :format(with, without))
    end)
end)
