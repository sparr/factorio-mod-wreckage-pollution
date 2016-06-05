require "config"

local mod_version="0.0.2"
local mod_data_version="0.0.1"

local function debug() end
-- local function debug(...)
--   if game.players[1] then
--     game.players[1].print(...)
--   end
-- end

local function onTick(event)
  -- pollute once per second
  if event.tick%60==41 then 
    for i=#global.pollution_sources,1,-1 do
      local source = global.pollution_sources[i]
      if not source.entity or not source.entity.valid then
        table.remove(global.pollution_sources,i)
      else
        source.entity.surface.pollute(source.entity.position, source.amount * pollution_intensity)
        source.amount = source.amount*0.995
        if source.amount < 1 then
          source.entity.destroy()
          table.remove(global.pollution_sources,i)
        end
      end
    end
  end
end

local function bounding_box_area(box) 
  if not box or not box.right_bottom or not box.right_bottom.x then
    return 0
  else
    return (box.right_bottom.x-box.left_top.x) * 
      (box.right_bottom.y-box.left_top.y)
  end
end

local function fluidSpill(e)
  -- create a chemical spill for non-water fluids being destroyed
  if #e.fluidbox>0 then
    local spill_amount = 0
    for b=1,#e.fluidbox do
      if e.fluidbox[b] and e.fluidbox[b].type ~= "water" then
        local spill_amount = e.fluidbox[b].amount
        local spill_size
        if spill_amount<100 then
          spill_size = 'small'
        elseif spill_amount<1000 then
          spill_size = 'medium'
        else
          spill_size = 'large'
        end
        spill_entity = e.surface.create_entity{name='chemical-spill-'..e.fluidbox[b].type..'-'..spill_size, position=e.position, force=e.force}
        if spill_entity then
          global.pollution_sources[#global.pollution_sources+1] = {entity=spill_entity,amount=spill_amount/100}
        end
      end
    end
  end
end

-- create one-time pollution based on the corpse/remnant definition of an entity
local function corpsesPollution(entity_name,surface,position)
  if game.entity_prototypes[entity_name].corpses then
    for cn,cep in pairs(game.entity_prototypes[entity_name].corpses) do
      -- small remnants have size 1, medium 4, large 9
      local corpse_size = bounding_box_area(cep.selection_box)
      surface.pollute(position, corpse_size*corpse_size*100 * pollution_intensity)
      break
    end
  end
end

local function remnantPollution(e)
  corpsesPollution(e.name,e.surface,e.position)
  -- create one-time pollution for anything inside the destroyed entity
  for inv_num=1,8 do
    -- temporary workaround for lack of valid inventory index list in API
    local noerr,inventory = pcall(e.get_inventory,inv_num)
    if noerr then
      for item_name,item_count in pairs(inventory.get_contents()) do
        corpsesPollution(item_name,e.surface,e.position)
      end
    end
  end
end

local function onEntityDied(event)
  local e = event.entity
  fluidSpill(e)
  remnantPollution(e)
end

local function onEntityMined(event)
  local e = event.entity
  fluidSpill(e)
end

local function checkForMigration(old_version, new_version)
  -- TODO: when a migration is necessary, trigger it here or set a flag.
end

local function checkForDataMigration(old_data_version, new_data_version)
  -- TODO: when a migration is necessary, trigger it here or set a flag.
end

local function onLoad()
  -- The only reason to have version/data_version is to trigger migrations, so do that here.
  checkForMigration(global.version, mod_version)
  checkForDataMigration(global.data_version, mod_data_version)

  -- After these lines, we can no longer check for migration.
  global.version=mod_version
  global.data_version=mod_data_version

  if not global.pollution_sources then global.pollution_sources = {} end
end

script.on_init(onLoad)
script.on_configuration_changed(onLoad)
script.on_load(onLoad)

script.on_event(defines.events.on_entity_died, onEntityDied)
script.on_event(defines.events.on_preplayer_mined_item, onEntityMined)
script.on_event(defines.events.on_robot_pre_mined, onEntityMined)

script.on_event(defines.events.on_tick, onTick)
