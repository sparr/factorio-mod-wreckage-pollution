local spill_sizes = {
  small =1,
  medium=2,
  large =3
}

for name,proto in pairs(data.raw.fluid) do
  for sizename,size in pairs(spill_sizes) do
    data:extend({
      {
        type = "decorative",
        name = "chemical-spill-"..proto.name..'-'..sizename,
        flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
        icon = "__wreckage-pollution__/graphics/entity/chemical-spill-"..sizename..".png",
        subgroup = "chemical-spill",
        order = "d[chemical-spill]-a["..proto.name.."]-a["..sizename.."]",
        collision_box = {{-size,-size},{size,size}},
        selection_box = {{-size,-size},{size,size}},
        selectable_in_game = false,
        render_layer = "decorative",
        pictures =
        {
          {
            filename = "__wreckage-pollution__/graphics/entity/chemical-spill-"..sizename..".png",
            width = size*64,
            height = size*64,
            tint = proto.base_color,
          }
        }
      },
    })
  end      
end