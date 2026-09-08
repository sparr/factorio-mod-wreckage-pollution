-- local dx = 1
-- local function debug(...)
--   if game and game.players[1] then
--     game.players[1].print(dx .. " " .. ...)
--     dx = dx + 1
--   end
-- end

local spill = require("lib.spill")

local spill_sizes = spill.SIZES

---@class PollutionSource
---@field entity LuaEntity
---@field amount number
---@field size "small"|"medium"|"large"
---@field fluid string
---@field tick integer

---@class (exact) Storage
---@field pollution_sources PollutionSource[]
---@field pollution_index integer Which pollution source should be polled next?
---@type Storage
storage=storage

--- 2.0 renamed global to storage, and a mod may no longer set it up as its control file
--- is read: that has to wait for on_init, or for on_configuration_changed when the mod is
--- added to a game that already exists.
local function setUpStorage()
  storage.pollution_sources = storage.pollution_sources or {}
  storage.pollution_index = storage.pollution_index or #storage.pollution_sources
end

--- What this surface deals in, or nil if it deals in nothing. Vulcanus, Fulgora, Aquilo
--- and every space platform answer nil: pollute() there is a silent no-op, so a spill
--- would sit on the books being processed for nothing, for good.
---
--- Asked each time rather than remembered, because a mod can turn a surface's pollutant
--- on or off through override_pollution_type.
---@param surface LuaSurface
---@return string?
local function pollutant_of(surface)
  local pollutant = surface.pollutant_type
  return pollutant and pollutant.name or nil
end

local function onTick(event)
  if #storage.pollution_sources == 0 then return end

  -- bail early if it's too soon to process the next source
  if storage.pollution_sources[storage.pollution_index] and storage.pollution_sources[storage.pollution_index].tick > event.tick - 60 then
    return
  end
  -- process n sources per tick, each souce once per second, to spread out the load
  local n_sources = math.ceil(#storage.pollution_sources / 60)

  for _ = 1, n_sources do
    local source = storage.pollution_sources[storage.pollution_index]
    local removed = false
    if not source or not source.entity or not source.entity.valid then
      if storage.pollution_index > 0 and storage.pollution_index <= #storage.pollution_sources then
        table.remove(storage.pollution_sources, storage.pollution_index)
        removed = true
      end
    elseif not pollutant_of(source.entity.surface) then
      -- Nothing here evaporates a spill or takes its pollution, so leaving it on the
      -- books would leave it on the ground for good. Saves made before this rule can
      -- still be carrying some.
      source.entity.destroy()
      table.remove(storage.pollution_sources, storage.pollution_index)
      removed = true
    else
      if source.tick > event.tick - 60 then return end
      source.tick = event.tick
      local evap_amount = source.amount * settings.global['pollution_evaporation'].value
      local pollute_amount = evap_amount * settings.global['pollution_intensity'].value / 50.0

      local spill_type = spill.kind(source.fluid)
      -- Decide whether we want to create pollution
      if spill_type == 'chemical-spill' then
        -- debug("pollute! " .. source.entity.position.x .. "," .. source.entity.position.y .. " " .. source.fluid .. " " .. source.amount .. " " .. pollute_amount)
        -- Create pollution in proportion to the spill size
        source.entity.surface.pollute(source.entity.position, pollute_amount)
      end

      source.amount = source.amount - evap_amount
      source.entity.health = source.amount

      -- replace pollution source entities when they shrink below the size thresholds
      for size_n = 2, 3 do
        local this_size, smaller_size = spill_sizes[size_n], spill_sizes[size_n - 1]
        if source.size == this_size and source.amount < settings.startup[this_size .. '_spill_threshold'].value then
          -- debug("shrinking "..source.entity.name)
          local old_entity = source.entity
          local new_entity = old_entity.surface.create_entity{
            name = spill.entity_name(source.fluid, smaller_size),
            position = old_entity.position,
            force = old_entity.force,
          }
          if new_entity then
            -- minable is a computed property in 2.1 and no longer assignable. The spill
            -- prototype declares no minable properties, so it was never minable anyway.
            new_entity.destructible = false
            new_entity.health = source.amount
            source.entity = new_entity
            source.size = smaller_size
          else
            table.remove(storage.pollution_sources, storage.pollution_index)
            removed = true
          end
          old_entity.destroy()
        end
      end

      -- destroy pollution sources producing less than 0.1 per second
      if source.amount < 0.1 / settings.global['pollution_evaporation'].value then
        -- debug("destroying "..source.entity.name)
        source.entity.destroy()
        table.remove(storage.pollution_sources, storage.pollution_index)
        removed = true
      end
    end

    if #storage.pollution_sources > 0 then
      if not removed then
        storage.pollution_index = (storage.pollution_index - 2) % #storage.pollution_sources + 1
      end
    else
      storage.pollution_index = 0
    end
  end
end

--- How far from the wreck a spill may be thrown when a wreck makes more than one, by the
--- size of that spill. A bigger puddle spreads further from where the thing stood.
local SCATTER = { small = 0.5, medium = 1, large = 1.5 }

--- and a little further again for each spill past the first, so that a wreck letting go
--- of several does not pile them all in the same armful
local SCATTER_PER_EXTRA = 0.25

--- Put a spill on the ground and start watching it.
---@param surface LuaSurface
---@param position MapPosition
---@param force LuaForce|string
---@param what string a fluid, or a fruit
---@param amount number
---@param scatter number how far it may be thrown from the position given
local function createSpill(surface, position, force, what, amount, scatter)
  if spill.ignored(what) or amount <= 0 then return end
  local size = spill.size(amount,
    settings.startup['medium_spill_threshold'].value,
    settings.startup['large_spill_threshold'].value)
  local at = position
  if scatter and scatter > 0 then
    local room = (SCATTER[size] or 1) + scatter
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * room
    at = { x = position.x + math.cos(angle) * distance,
           y = position.y + math.sin(angle) * distance }
  end
  local entity = surface.create_entity{
    name = spill.entity_name(what, size), position = at, force = force,
    -- Belt and braces. A spill is placeable-off-grid and lands exactly where it is put
    -- with or without this; saying so out loud costs nothing and keeps the scatter safe
    -- if that ever stops being true.
    snap_to_grid = false }
  if not entity then return end
  entity.destructible = false
  entity.health = amount
  storage.pollution_sources[#storage.pollution_sources + 1] = {
    entity = entity, amount = amount, size = size, fluid = what, tick = game.tick }
end

--- Lay out everything one wreck spilled.
---
--- A single spill goes exactly where the wreck was. Several are thrown about a little, so
--- that a chest of oil and water barrels leaves two puddles lying over one another rather
--- than one neatly on the spot and the rest arranged around it.
---@param surface LuaSurface
---@param position MapPosition
---@param force LuaForce|string
---@param spills {what: string, amount: number}[]
local function placeSpills(surface, position, force, spills)
  local scatter = (#spills > 1) and (#spills - 1) * SCATTER_PER_EXTRA or 0
  for _, one in pairs(spills) do
    createSpill(surface, position, force, one.what, one.amount, scatter)
  end
end

--- Which items are containers, and what each holds. Worked out once, from recipes, which
--- cannot change while a game is running.
local containers = nil
local function heldFluids()
  containers = containers or spill.containers(prototypes.recipe)
  return containers
end

--- The fruit each plant gives up, and the set of items that counts as fruit. A felled
--- plant spills its fruit, and so does anything destroyed while holding some.
local by_plant, is_fruit = nil, nil
local function learnFruit()
  if by_plant then return end
  by_plant, is_fruit = {}, {}
  for _, plant in pairs(prototypes.get_entity_filtered{{filter = "type", type = "plant"}}) do
    local mineable = plant.mineable_properties
    local harvest = mineable and spill.harvest(mineable.products)
    if harvest then
      by_plant[plant.name] = harvest
      is_fruit[harvest.item] = true
    end
  end
end

---What this prototype yields if it is a plant, or nil if it is not one.
---@param prototype LuaEntityPrototype
---@return Harvest?
local function fruitOf(prototype)
  learnFruit()
  return by_plant[prototype.name]
end

---Whether this item is a fruit some plant gives up.
---@param item_name string
---@return boolean
local function isFruit(item_name)
  learnFruit()
  return is_fruit[item_name] == true
end

---Fluid held in an entity's tanks, which the game throws away whether the entity is
---destroyed or taken apart, so it is spilled either way.
---@param e LuaEntity
---@return {what: string, amount: number}[]
local function fluidsOf(e)
  local found = {}
  -- 2.1 removed LuaEntity.fluidbox. fluids_count answers for every entity, so a chest or
  -- a biter simply reports nothing and the loop does not run -- where reading .fluidbox
  -- off one was an error that took the mod down with it. It also counts fluid held
  -- outside a fluidbox proper, so a destroyed fluid wagon or fluid turret spills what it
  -- was carrying, which it never used to.
  for b = 1, e.fluids_count do
    local fluid = e.get_fluid(b)
    if fluid then found[#found + 1] = { what = fluid.name, amount = fluid.amount } end
  end
  return found
end

---Whether a plant has anything on it yet. An unripe one mines to nothing, so there is
---nothing to spill off it either.
---@param e LuaEntity
---@return boolean
local function isRipe(e)
  local grown = e.tick_grown
  return grown == nil or grown <= game.tick
end

---What an entity was carrying, which is lost only when it is destroyed. Somebody who
---takes a chest apart keeps what was in it, and somebody who fells a ripe plant keeps its
---fruit, so none of this is spilled when a thing is mined.
---@param e LuaEntity
---@return {what: string, amount: number}[]
local function contentsOf(e)
  local found = {}

  -- A plant taken any way other than by harvesting drops its fruit on the ground. An
  -- agricultural tower raises its own events, which this mod does not answer, so a picked
  -- crop is never also a spilled one.
  local harvest = fruitOf(e.prototype)
  if harvest and isRipe(e) then
    -- Destroying a ripe plant does what harvesting it would have done -- the game emits
    -- nothing for a plant that is destroyed rather than picked, so this is not on top of
    -- anything -- and then the fruit is on the ground as well. Twice a harvest in all.
    -- The burst is exactly what the game emits for a harvest, unscaled, because that is
    -- what it stands in for; the fruit on the ground is this mod's own and the intensity
    -- setting scales that as it scales everything else.
    local emissions = e.prototype.harvest_emissions
    local burst = emissions and emissions[pollutant_of(e.surface)]
    if burst and burst > 0 then e.surface.pollute(e.position, burst) end
    found[#found + 1] = { what = harvest.item, amount = harvest.amount * spill.FRUIT_UNITS }
  end

  -- and whatever was sitting inside it: barrels of fluid, and fruit. Gathered per thing
  -- so a chest of fifty barrels leaves one spill rather than fifty.
  local totals = {}
  for inv_num--[[@type defines.inventory]] = 1, e.get_max_inventory_index() do
    local inventory = e.get_inventory(inv_num)
    if inventory then
      for _, item in pairs(inventory.get_contents()) do
        local held = heldFluids()[item.name]
        if held then
          totals[held.fluid] = (totals[held.fluid] or 0) + held.amount * item.count
        elseif isFruit(item.name) then
          totals[item.name] = (totals[item.name] or 0) + item.count * spill.FRUIT_UNITS
        end
      end
    end
  end
  for what, amount in pairs(totals) do
    found[#found + 1] = { what = what, amount = amount }
  end
  return found
end

--- How much a destroyed thing puts into the air on a surface dealing in the named
--- pollutant. Zero means it contributes nothing at all.
---@param prototype LuaEntityPrototype
---@param pollutant string
---@return number
local function wreckEmission(prototype, pollutant)
  -- Somewhere that deals in something other than pollution, wreckage puts nothing into
  -- the air by itself. On Gleba the spores come from the plants, and an agricultural
  -- tower already answers for the ones it harvests; a felled plant leaves its fruit on
  -- the ground instead, and that gives off spores as it rots like any other spill.
  if pollutant ~= "pollution" then return 0 end

  -- Nothing a fight produces counts. Biter corpses were already spared; trees are spared
  -- now too, because biters knock them down in places nobody has been, and a forest is
  -- what takes pollution out of the air rather than what puts it in.
  if prototype.type == "unit" or prototype.type == "tree" then return 0 end

  if not prototype.corpses then return 0 end
  for _, corpse in pairs(prototype.corpses) do
    -- small remnants have size 1, medium 4, large 9
    return spill.bounding_box_area(corpse.selection_box)
      * settings.global['pollution_intensity'].value * 20
  end
  return 0
end

-- create one-time pollution based on the corpse/remnant definition of an entity
local function corpsesPollution(entity_name, surface, position, pollutant)
  local prototype = prototypes.entity[entity_name]
  if not prototype then return end
  local amount = wreckEmission(prototype, pollutant)
  if amount > 0 then surface.pollute(position, amount) end
end

---Create pollution for an entity dying and everything destroyed in its inventories
---@param e LuaEntity
local function remnantPollution(e)
  local pollutant = pollutant_of(e.surface)
  if not pollutant then return end
  corpsesPollution(e.name, e.surface, e.position, pollutant)
  -- create one-time pollution for anything inside the destroyed entity
  for inv_num--[[@type defines.inventory]] = 1, e.get_max_inventory_index() do
    local inventory = e.get_inventory(inv_num)
    if inventory then
      -- 2.0 changed get_contents from a name-to-count mapping into a list of
      -- {name, count, quality} records
      for _, item in pairs(inventory.get_contents()) do
        -- TODO handle items that don't have same name entities
        corpsesPollution(item.name, e.surface, e.position, pollutant)
      end
    end
  end
end

local function onEntityDied(event)
  local e = event.entity
  if pollutant_of(e.surface) then
    local spills = fluidsOf(e)
    for _, one in pairs(contentsOf(e)) do spills[#spills + 1] = one end
    placeSpills(e.surface, e.position, e.force, spills)
  end
  remnantPollution(e)
end

local function onEntityMined(event)
  local e = event.entity
  if not pollutant_of(e.surface) then return end
  placeSpills(e.surface, e.position, e.force, fluidsOf(e))
end

script.on_event(defines.events.on_entity_died, onEntityDied)
script.on_event(defines.events.on_pre_player_mined_item, onEntityMined)
script.on_event(defines.events.on_robot_pre_mined, onEntityMined)

script.on_event(defines.events.on_tick, onTick)

script.on_init(setUpStorage)
script.on_configuration_changed(setUpStorage)

--- wp-tests is never published, so this can never fire on a player's machine -- which
--- matters, because info.json keeps test/ out of the package.
if script.active_mods["factorio-test"] and script.active_mods["wp-tests"] then
  require("__factorio-test__/init")({
    "test.ft.spilling",
    "test.ft.evaporation",
    "test.ft.surfaces",
    "test.ft.planets",
    "test.ft.barrels",
    "test.ft.matrix",
    "test.ft.vanilla",
    "test.ft.rocket",
  }, {
    load_luassert = true,
    game_speed = 100,
  })
end
