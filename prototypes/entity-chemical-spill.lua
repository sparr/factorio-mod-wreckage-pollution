-- create prototypes for all types and sizes of chemical spills
-- one type per fluid prototype
-- must run in data-updates or data-final-fixes to see all fluids from other mods' data

local spill_sizes = {
  small =1,
  medium=2,
  large =3
}

for name, proto in pairs(data.raw.fluid) do
  for sizename, size in pairs(spill_sizes) do
    data:extend(
      {
        {
          type = "simple-entity",
          name = "chemical-spill-" .. proto.name .. '-' .. sizename,
          flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
          icon = "__wreckage-pollution__/graphics/entity/chemical-spill-" .. sizename .. ".png",
          subgroup = "chemical-spill",
          order = "d[chemical-spill]-a[" .. proto.name .. "]-a[" .. sizename .. "]",
          selection_box = {{-size, -size}, {size, size}},
          selectable_in_game = false,
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