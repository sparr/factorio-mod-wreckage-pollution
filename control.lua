require "config"

local mod_version="0.13.0"
local mod_data_version="0.13.0"

-- local function debug(...)
--   if game and game.players[1] then
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
        -- debug("pollute! "..source.entity.position.x..","..source.entity.position.y.." "..source.amount * .005 * pollution_intensity)
        source.entity.surface.pollute(source.entity.position, source.amount * .005 * pollution_intensity)
        source.amount = source.amount*0.995

        if source.size == "large" and source.amount < large_spill_size then
          -- debug("shrinking "..source.entity.name)
          local old_entity = source.entity
          source.entity = old_entity.surface.create_entity{
            name='chemical-spill-'..source.fluid..'-'.."medium",
            position=old_entity.position,
            force=old_entity.force
          }
          source.size = "medium"
          old_entity.destroy()
        end
        
        if source.size == "medium" and source.amount < medium_spill_size then
          -- debug("shrinking "..source.entity.name)
          local old_entity = source.entity
          source.entity = old_entity.surface.create_entity{
            name='chemical-spill-'..source.fluid..'-'.."small",
            position=old_entity.position,
            force=old_entity.force
          }
          source.size = "small"
          old_entity.destroy()
        end

        if source.amount < 10 and event.tick >= source.expiration then
          -- debug("destroying "..source.entity.name)
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
          global.pollution_sources[#global.pollution_sources+1] = {
            entity = spill_entity,
            amount = spill_amount,
            size = spill_size,
            fluid = e.fluidbox[b].type,
            -- minimum time before disappearing
            -- 15 minutes for a full tank
            -- 66 seconds for a drop
            expiration = game.tick + spill_amount*20 + 4000 
          }
        end
      end
    end
  end
end

-- create one-time pollution based on the corpse/remnant definition of an entity
local function corpsesPollution(entity_name,surface,position)
  if game.entity_prototypes and game.entity_prototypes[entity_name] and game.entity_prototypes[entity_name].corpses then
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
    local inventory = e.get_inventory(inv_num)
    if inventory then
      for item_name,item_count in pairs(inventory.get_contents()) do
        corpsesPollution(item_name,e.surface,e.position)
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
      for k,v in pairs(global.pollution_sources) do
        -- debug("migrating "..v.entity.name)
        _,_,v.size = string.find(v.entity.name,"-([^-]*)$")
        v.amount = v.amount*100
        v.expiration = 0 -- old spills will expire when they are small enough
        _,_,v.fluid = string.find(v.entity.name,"^chemical%-spill%-(.*)%-[^-]*$")
        -- debug(v.size.." "..v.amount.." "..v.expiration)
      end
    end
  end
end

local function onInit()
  -- After these lines, we can no longer check for migration.
  global.version=mod_version
  global.data_version=mod_data_version

  if not global.pollution_sources then global.pollution_sources = {} end
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
script.on_event(defines.events.on_preplayer_mined_item, onEntityMined)
script.on_event(defines.events.on_robot_pre_mined, onEntityMined)

script.on_event(defines.events.on_tick, onTick)
