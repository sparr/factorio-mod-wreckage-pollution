require "config"

local mod_version="0.0.1"
local mod_data_version="0.0.1"

local function debug() end
-- local function debug(...)
--   if game.players[1] then
--     game.players[1].print(...)
--   end
-- end

-- local function pos2s(pos)
--   if pos.x then
--     return pos.x..','..pos.y
--   elseif pos[1] then
--     return pos[1]..','..pos[2]
--   end
--   return ''
-- end

local function onTick(event)
  -- pollute once per second
  if event.tick%60==41 then 
    for i=#global.pollution_sources,1,-1 do
      local source = global.pollution_sources[i]
      if not source.entity or not source.entity.valid then
        table.remove(global.pollution_sources,i)
      else
        -- debug(event.tick.." polluting at "..pos2s(source.entity.position).." amount "..source.amount)
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

local function onEntityDied(event)
  local e = event.entity
  -- create a chemical spill for non-water fluids being destroyed
  if #e.fluidbox>0 then
    local dirty_fluid = 0
    for b=1,#e.fluidbox do
      if e.fluidbox[b] and e.fluidbox[b].type ~= "water" then
        dirty_fluid = dirty_fluid + e.fluidbox[b].amount
      end
    end
    local entity_name
    if dirty_fluid<100 then
      entity_name = 'chemical-spill-small'
    elseif dirty_fluid<1000 then
      entity_name = 'chemical-spill-medium'
    else
      entity_name = 'chemical-spill-large'
    end
    -- debug("new spill at "..pos2s(e.position)..' en='..entity_name)
    spill_entity = e.surface.create_entity{name=entity_name, position=e.position, force=e.force}
    if spill_entity then
      -- debug("amount = "..dirty_fluid/100)
      global.pollution_sources[#global.pollution_sources+1] = {entity=spill_entity,amount=dirty_fluid/100}
    end
  end
  -- create one-time pollution for the destroyed entity itself
  for cn,cep in pairs(game.entity_prototypes[e.name].corpses) do
    -- debug(cn..' '..pos2s(cep.selection_box.left_top)..' - '..pos2s(cep.selection_box.right_bottom))
    -- small remnants have size 1, medium 4, large 9
    local corpse_size = bounding_box_area(cep.selection_box)
    -- debug(event.tick.." polluting at "..pos2s(e.position).." amount "..corpse_size*400)
    e.surface.pollute(e.position, corpse_size*corpse_size*100 * pollution_intensity)
    break
  end
  -- create one-time pollution for anything inside the destroyed entity
  for inv_num=1,8 do
    -- temporary workaround for lack of valid inventory index list in API
    local noerr,inventory = pcall(e.get_inventory,inv_num)
    if noerr then
      for item_name,item_count in pairs(inventory.get_contents()) do
        for cn,cep in pairs(game.entity_prototypes[item_name].corpses) do
          local corpse_size = bounding_box_area(cep.selection_box)
          e.surface.pollute(e.position, corpse_size*corpse_size*100 * pollution_intensity * item_count)
          break
        end
      end
    end
  end
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

script.on_event(defines.events.on_tick, onTick)
