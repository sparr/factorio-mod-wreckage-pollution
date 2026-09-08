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

--- Put a spill on the ground and start watching it.
---@param surface LuaSurface
---@param position MapPosition
---@param force LuaForce|string
---@param fluid_name string
---@param amount number
local function createSpill(surface, position, force, fluid_name, amount)
  if spill.ignored(fluid_name) or amount <= 0 then return end
  local size = spill.size(amount,
    settings.startup['medium_spill_threshold'].value,
    settings.startup['large_spill_threshold'].value)
  local entity = surface.create_entity{
    name = spill.entity_name(fluid_name, size), position = position, force = force }
  if not entity then return end
  entity.destructible = false
  entity.health = amount
  storage.pollution_sources[#storage.pollution_sources + 1] = {
    entity = entity, amount = amount, size = size, fluid = fluid_name, tick = game.tick }
end

--- Which items are containers, and what each holds. Worked out once, from recipes, which
--- cannot change while a game is running.
local containers = nil
local function heldFluids()
  containers = containers or spill.containers(prototypes.recipe)
  return containers
end

---@param e LuaEntity
local function fluidSpill(e)
  -- 2.1 removed LuaEntity.fluidbox. fluids_count answers for every entity, so a chest or
  -- a biter simply reports nothing and the loop does not run -- where reading .fluidbox
  -- off one was an error that took the mod down with it. It also counts fluid held
  -- outside a fluidbox proper, so a destroyed fluid wagon or fluid turret now spills what
  -- it was carrying, which it never used to.
  if not pollutant_of(e.surface) then return end
  for b = 1, e.fluids_count do
    local fluid = e.get_fluid(b)
    if fluid then
      createSpill(e.surface, e.position, e.force, fluid.name, fluid.amount)
    end
  end

  -- and whatever was sitting in barrels inside it, gathered per fluid so a chest of
  -- fifty barrels leaves one spill rather than fifty
  local from_containers = {}
  for inv_num--[[@type defines.inventory]] = 1, e.get_max_inventory_index() do
    local inventory = e.get_inventory(inv_num)
    if inventory then
      for _, item in pairs(inventory.get_contents()) do
        local held = heldFluids()[item.name]
        if held then
          from_containers[held.fluid] =
            (from_containers[held.fluid] or 0) + held.amount * item.count
        end
      end
    end
  end
  for fluid_name, amount in pairs(from_containers) do
    createSpill(e.surface, e.position, e.force, fluid_name, amount)
  end
end

--- How much a destroyed thing puts into the air on a surface dealing in the named
--- pollutant. Zero means it contributes nothing at all.
---@param prototype LuaEntityPrototype
---@param pollutant string
---@return number
local function wreckEmission(prototype, pollutant)
  -- A plant is judged by what harvesting it releases, which is the whole of the answer
  -- somewhere like Gleba: felling a yumako tree gives up its spores, and a wrecked
  -- assembler gives up none, because an assembler is not what makes spores there.
  local harvest = prototype.harvest_emissions
  if harvest then
    return (harvest[pollutant] or 0) * settings.global['pollution_intensity'].value
  end
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
  fluidSpill(event.entity)
  remnantPollution(event.entity)
end

local function onEntityMined(event)
  fluidSpill(event.entity)
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
    "test.ft.rocket",
  }, {
    load_luassert = true,
    game_speed = 100,
  })
end
