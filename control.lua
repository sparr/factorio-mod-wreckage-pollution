global.pollution_sources = global.pollution_sources or {}
global.pollution_index = global.pollution_index or #global.pollution_sources

-- local dx = 1
-- local function debug(...)
--   if game and game.players[1] then
--     game.players[1].print(dx .. " " .. ...)
--     dx = dx + 1
--   end
-- end

-- Fluid types that will not make a spill
local IGNORED_FLUIDS = {
  ["steam"] = true,
}

-- Fluids types that create a puddle, but don't pollute
local NON_POLLUTANTS = {
  ["water"] = true,
}

local spill_sizes = {"small","medium","large"}

---@class PollutionSource
---@field entity LuaEntity
---@field amount number
---@field size "small"|"medium"|"large"
---@field fluid string
---@field tick integer

---@class (exact) Global
---@field pollution_sources PollutionSource[]
---@field pollution_index integer Which pollution source should be polled next?
---@type Global
global=global

local function onTick(event)
  if #global.pollution_sources == 0 then return end

  -- bail early if it's too soon to process the next source
  if global.pollution_sources[global.pollution_index] and global.pollution_sources[global.pollution_index].tick > event.tick - 60 then
    return
  end
  -- process n sources per tick, each souce once per second, to spread out the load
  local n_sources = math.ceil(#global.pollution_sources / 60)

  for _ = 1, n_sources do
    local source = global.pollution_sources[global.pollution_index]
    local removed = false
    if not source or not source.entity or not source.entity.valid then
      if global.pollution_index > 0 and global.pollution_index <= #global.pollution_sources then
        table.remove(global.pollution_sources, global.pollution_index)
        removed = true
      end
    else
      if source.tick > event.tick - 60 then return end
      source.tick = event.tick
      local evap_amount = source.amount * settings.global['pollution_evaporation'].value
      local pollute_amount = evap_amount * settings.global['pollution_intensity'].value / 50.0

      local spill_type = 'chemical-spill'
      -- Decide whether we want to create pollution
      if NON_POLLUTANTS[source.fluid] ~= true then
        -- debug("pollute! " .. source.entity.position.x .. "," .. source.entity.position.y .. " " .. source.fluid .. " " .. source.amount .. " " .. pollute_amount)
        -- Create pollution in proportion to the spill size
        source.entity.surface.pollute(source.entity.position, pollute_amount)
      else
        spill_type = 'liquid-spill'
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
            name = spill_type..'-'..source.fluid..'-'..smaller_size,
            position = old_entity.position,
            force = old_entity.force,
          }
          if new_entity then
            new_entity.destructible = false
            new_entity.minable = false
            new_entity.health = source.amount
            source.entity = new_entity
            source.size = smaller_size
          else
            table.remove(global.pollution_sources, global.pollution_index)
            removed = true
          end
          old_entity.destroy()
        end
      end

      -- destroy pollution sources producing less than 0.1 per second
      if source.amount < 0.1 / settings.global['pollution_evaporation'].value then
        -- debug("destroying "..source.entity.name)
        source.entity.destroy()
        table.remove(global.pollution_sources, global.pollution_index)
        removed = true
      end
    end

    if #global.pollution_sources > 0 then
      if not removed then
        global.pollution_index = (global.pollution_index - 2) % #global.pollution_sources + 1
      end
    else
      global.pollution_index = 0
    end
  end
end

local function bounding_box_area(box)
  if not box or not box.right_bottom or not box.right_bottom.x then
    return 0
  else
    return (box.right_bottom.x - box.left_top.x) *
           (box.right_bottom.y - box.left_top.y)
  end
end

---@param e LuaEntity
local function fluidSpill(e)
  -- create a chemical spill for non-water fluids being destroyed
  if #e.fluidbox > 0 then
    for b = 1, #e.fluidbox do
      if e.fluidbox[b] and IGNORED_FLUIDS[e.fluidbox[b].name] ~= true then
        local spill_amount = e.fluidbox[b].amount
        ---@type string
        local spill_size
        if spill_amount < settings.startup['medium_spill_threshold'].value then
          spill_size = 'small'
        elseif spill_amount < settings.startup['large_spill_threshold'].value then
          spill_size = 'medium'
        else
          spill_size = 'large'
        end

        ---Figure out if its a pollutant
        ---@type string
        local spill_type
        if NON_POLLUTANTS[e.fluidbox[b].name] ~= true then
          spill_type = 'chemical-spill'
        else
          spill_type = 'liquid-spill'
        end

        spill_entity = e.surface.create_entity{name = spill_type .. '-' .. e.fluidbox[b].name .. '-' .. spill_size, position = e.position, force = e.force}
        if spill_entity then
          spill_entity.destructible = false
          spill_entity.minable = false
          spill_entity.health = spill_amount
          -- debug(" create pollution source " .. spill_entity.position.x .. "," .. spill_entity.position.y .. " " .. spill_amount)
          global.pollution_sources[#global.pollution_sources + 1] = {
            entity = spill_entity,
            amount = spill_amount,
            size = spill_size,
            fluid = e.fluidbox[b].name,
            tick = game.tick
          }
        end
      end
    end
  end
end

-- create one-time pollution based on the corpse/remnant definition of an entity
local function corpsesPollution(entity_name, surface, position)
  if game.entity_prototypes and game.entity_prototypes[entity_name] and game.entity_prototypes[entity_name].corpses then
    -- pollute for everything except biter corpses
    if game.entity_prototypes[entity_name].type ~= "unit" then
      for cn, cep in pairs(game.entity_prototypes[entity_name].corpses) do
        -- small remnants have size 1, medium 4, large 9
        local corpse_size = bounding_box_area(cep.selection_box)
        -- debug("pollute! " .. cn .. " " .. position.x .. "," .. position.y .. " " .. corpse_size * settings.global['pollution_intensity'].value * 100)
        surface.pollute(position, corpse_size * settings.global['pollution_intensity'].value * 20)
        break
      end
    end
  end
end

---Create pollution for an entity dying and everything destroyed in its inventories
---@param e LuaEntity
local function remnantPollution(e)
  corpsesPollution(e.name, e.surface, e.position)
  -- create one-time pollution for anything inside the destroyed entity
  for inv_num--[[@type defines.inventory]] = 1, e.get_max_inventory_index() do
    local inventory = e.get_inventory(inv_num)
    if inventory then
      for item_name, item_count in pairs(inventory.get_contents()) do
        -- TODO handle items that don't have same name entities
        corpsesPollution(item_name, e.surface, e.position)
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
