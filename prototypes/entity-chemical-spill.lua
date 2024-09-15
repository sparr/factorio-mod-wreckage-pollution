-- create prototypes for all types and sizes of chemical spills
-- one type per fluid prototype
-- three sizes per type
-- must run in data-updates or data-final-fixes to see all fluids from other mods' data

local spill_sizes = {
  small = { name = "small",  size = 1, max_amount = settings.startup["medium_spill_threshold"].value--[[@as integer]] },
  medium = { name = "medium", size = 2, max_amount = settings.startup["large_spill_threshold"].value--[[@as integer]] },
  large = { name = "large",  size = 3, max_amount = 25000 }, -- TODO get max fluid container size
}

-- liquids that create non-polluting spills
local non_pollutants = {
  ["water"] = true,
}

for name, proto in pairs(data.raw.fluid) do
  for size_name, spill_data in pairs(spill_sizes) do
    local size = spill_data.size
    -- See what kind of entity this liquid gets
    ---@type string
    local spill_type
    if non_pollutants[name] == true then
      spill_type = 'liquid-spill'
    else
      spill_type = 'chemical-spill'
    end

    data:extend(
      {
        {
          type = "simple-entity",
          name = spill_type .. "-" .. proto.name .. '-' .. size_name,
          flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
          icon = "__wreckage-pollution__/graphics/entity/chemical-spill-" .. size_name .. ".png",
          icon_size = size * 64,
          subgroup = "chemical-spill",
          order = "d[chemical-spill]-a[" .. proto.name .. "]-a[" .. size_name .. "]",
          selection_box = {{-size, -size}, {size, size}},
          selectable_in_game = true,
          collision_box = {{-size, -size}, {size, size}},
          collision_mask = {"floor-layer"},
          localised_name = {"entity-name." .. spill_type .. "-" .. size_name, {"fluid-name." .. proto.name}},
          localised_description = {"entity-description." .. spill_type .. "-" .. size_name, {"fluid-name." .. proto.name}},
          max_health = spill_data.max_amount,

          render_layer = "decorative",
          pictures =
          {
            {
              filename = "__wreckage-pollution__/graphics/entity/chemical-spill-" .. size_name .. ".png",
              width = size * 64,
              height = size * 64,
              tint = proto.base_color,
            }
          }
        },
      }
    )
  end
end
