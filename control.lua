local mod_version = "1.1.1"
local mod_data_version = "0.13.0"

-- dx = 1
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

local function onTick(event)
  if #global.pollution_sources == 0 then return end

  -- bail early if it's too soon to process the next source
  if global.pollution_sources[global.pollution_index] and global.pollution_sources[global.pollution_index].tick > event.tick - 60 then
    return
  end

  -- process n sources per tick, to spread out the load
  local n_sources = math.ceil(#global.pollution_sources / 60)

  for n = 1, n_sources do
    local source = global.pollution_sources[global.pollution_index]
    if not source or not source.entity or not source.entity.valid then
      table.remove(global.pollution_sources, global.pollution_index)
      if #global.pollution_sources == 0 then return end
      if global.pollution_index > #global.pollution_sources then
        global.pollution_index = #global.pollution_sources
      end
    else
      if source.tick > event.tick - 60 then return end
      source.tick = event.tick
      local evap_amount = source.amount * settings.global['pollution_evaporation'].value
      local pollute_amount = evap_amount * settings.global['pollution_intensity'].value

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

      if source.size == "large" and source.amount < settings.global['large_spill_threshold'].value / 10.0 then
        -- debug("shrinking "..source.entity.name)
        local old_entity = source.entity
        source.entity = old_entity.surface.create_entity{
          name = spill_type..'-'..source.fluid..'-'.."medium",
          position = old_entity.position,
          force = old_entity.force
        }
        source.size = "medium"
        old_entity.destroy()
      end

      if source.size == "medium" and source.amount < settings.global['medium_spill_threshold'].value / 10.0 then
        -- debug("shrinking "..source.entity.name)
        local old_entity = source.entity
        source.entity = old_entity.surface.create_entity{
          name = spill_type..'-'..source.fluid..'-'.."small",
          position = old_entity.position,
          force = old_entity.force
        }
        source.size = "small"
        old_entity.destroy()
      end

      -- get rid of pollution sources producing less than 0.1 per second
      if source.amount < 0.1 / settings.global['pollution_evaporation'].value then
        -- debug("destroying "..source.entity.name)
        source.entity.destroy()
        table.remove(global.pollution_sources, global.pollution_index)
      end
    end

    if #global.pollution_sources > 0 then
      global.pollution_index = (global.pollution_index - 2) % #global.pollution_sources + 1
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

local function fluidSpill(e)
  -- create a chemical spill for non-water fluids being destroyed
  if #e.fluidbox > 0 then
    for b = 1, #e.fluidbox do
      if e.fluidbox[b] and IGNORED_FLUIDS[e.fluidbox[b].name] ~= true then
        local spill_amount = e.fluidbox[b].amount
        local spill_size
        if spill_amount < settings.global['medium_spill_threshold'].value then
          spill_size = 'small'
        elseif spill_amount < settings.global['large_spill_threshold'].value then
          spill_size = 'medium'
        else
          spill_size = 'large'
        end

        -- Figure out if its a pollutant
        local spill_type
        if NON_POLLUTANTS[e.fluidbox[b].name] ~= true then
          spill_type = 'chemical-spill'
        else
          spill_type = 'liquid-spill'
        end

        spill_entity = e.surface.create_entity{name = spill_type .. '-' .. e.fluidbox[b].name .. '-' .. spill_size, position = e.position, force = e.force}
        if spill_entity then
          -- debug(" create pollution source " .. spill_entity.position.x .. "," .. spill_entity.position.y .. " " .. spill_amount)
          global.pollution_sources[#global.pollution_sources + 1] = {
            entity = spill_entity,
            amount = spill_amount / 10.0, -- v0.15 multiplied fluid amounts by 10
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
        -- debug("pollute! " .. position.x .. "," .. position.y .. " " .. corpse_size * settings.global['pollution_intensity'].value * 100)
        surface.pollute(position, corpse_size * settings.global['pollution_intensity'].value * 100)
        break
      end
    end
  end
end

local function remnantPollution(e)
  corpsesPollution(e.name, e.surface, e.position)
  -- create one-time pollution for anything inside the destroyed entity
  for inv_num = 1, 8 do
    local inventory = e.get_inventory(inv_num)
    if inventory then
      for item_name, item_count in pairs(inventory.get_contents()) do
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

local function checkForMigration(old_version, new_version)
  -- TODO: when a migration is necessary, trigger it here or set a flag.
end

local function checkForDataMigration(old_data_version, new_data_version)
  -- TODO: when a migration is necessary, trigger it here or set a flag.
  if old_data_version == nil or old_data_version < "0.0.4" then
    if global.pollution_sources then
      for k, v in pairs(global.pollution_sources) do
        -- debug("migrating " .. v.entity.name)
        _, _, v.size = string.find(v.entity.name, "-([^-]*)$")
        v.amount = v.amount * 100
        _, _, v.fluid = string.find(v.entity.name, "^chemical%-spill%-(.*)%-[^-]*$")
        -- debug(v.size .. " " .. v.amount)
      end
    end
  end
end

local function onInit()
  -- After these lines, we can no longer check for migration.
  global.version = mod_version
  global.data_version = mod_data_version

  if not global.pollution_sources then global.pollution_sources = {} end
  if not global.pollution_index then global.pollution_index = #global.pollution_sources end
end

local function onConfigurationChanged()
  -- The only reason to have version/data_version is to trigger migrations, so do that here.
  checkForMigration(global.version, mod_version)
  checkForDataMigration(global.data_version, mod_data_version)

  onInit()
end

script.on_init(onInit)
script.on_configuration_changed(onConfigurationChanged)

script.on_event(defines.events.on_entity_died, onEntityDied)
script.on_event(defines.events.on_pre_player_mined_item, onEntityMined)
script.on_event(defines.events.on_robot_pre_mined, onEntityMined)

script.on_event(defines.events.on_tick, onTick)
