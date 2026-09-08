---@type {version: string?, data_version: string?}
local data = storage
-- data_version was only ever set by versions old enough to predate this migration, so a
-- save without one is already past it. Comparing nil against a string is an error.
if data.data_version and data.data_version < "0.0.4" then
  if data.pollution_sources then
    for _, v in pairs(data.pollution_sources) do
      local size = string.match(v.entity.name, "-([^-]*)$")
      local fluid = string.match(v.entity.name, "^chemical%-spill%-(.*)%-[^-]*$")
      v.size = size
      v.fluid = fluid
      v.amount = v.amount * 100
    end
  end
end
data.version = nil
data.data_version = nil
