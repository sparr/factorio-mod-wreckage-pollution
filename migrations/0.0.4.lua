---@type {version: string?, data_version: string?}
global = global
if global.data_version < "0.0.4" then
  if global.pollution_sources then
    for _, v in pairs(global.pollution_sources) do
      -- debug("migrating " .. v.entity.name)
      _, _, v.size = string.find(v.entity.name, "-([^-]*)$")
      v.amount = v.amount * 100
      _, _, v.fluid = string.find(v.entity.name, "^chemical%-spill%-(.*)%-[^-]*$")
      -- debug(v.size .. " " .. v.amount)
    end
  end
end
global.version = nil
global.data_version = nil