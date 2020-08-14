-- create prototypes for all types and sizes of chemical spills
-- one type per fluid prototype
-- must run in data-updates or data-final-fixes to see all fluids from other mods' data

local spill_sizes = {
  small =1,
  medium=2,
  large =3
}

-- liquids that create non-polluting spills
local non_pollutants = {
  ["water"] = true,
}

for name, proto in pairs(data.raw.fluid) do
  for sizename, size in pairs(spill_sizes) do
    -- See what kind of entity this liquid gets
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
          name = spill_type .. "-" .. proto.name .. '-' .. sizename,
          flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
          icon = "__wreckage-pollution__/graphics/entity/chemical-spill-" .. sizename .. ".png",
          icon_size = size * 64,
          subgroup = "chemical-spill",
          order = "d[chemical-spill]-a[" .. proto.name .. "]-a[" .. sizename .. "]",
          selection_box = {{-size, -size}, {size, size}},
          selectable_in_game = true,
          collision_box = {{-size, -size}, {size, size}},
          collision_mask = {"floor-layer"},
          localised_name = {"entity-name." .. spill_type .. "-" .. sizename, {"fluid-name." .. proto.name}},
          localised_description = {"entity-description." .. spill_type .. "-" .. sizename, {"fluid-name." .. proto.name}},

          render_layer = "decorative",
          pictures =
          {
            {
              filename = "__wreckage-pollution__/graphics/entity/chemical-spill-" .. sizename .. ".png",
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
