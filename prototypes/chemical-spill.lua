data:extend(
{

  {
    type = "item-subgroup",
    name = "chemical-spill",
    group = "environment",
    order = "d",
  },

  {
    type = "decorative",
    name = "chemical-spill-small",
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
    icon = "__wreckage-pollution__/graphics/entity/chemical-spill-small.png",
    subgroup = "chemical-spill",
    order = "d[chemical-spill]-a[green]-a[small]",
    collision_box = {{-1, -1}, {1, 1}},
    selection_box = {{-1, -1}, {1, 1}},
    selectable_in_game = false,
    render_layer = "decorative",
    pictures =
    {
      {
        filename = "__wreckage-pollution__/graphics/entity/chemical-spill-small.png",
        width = 64,
        height = 64,
      }
    }
  },

  {
    type = "decorative",
    name = "chemical-spill-medium",
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
    icon = "__wreckage-pollution__/graphics/entity/chemical-spill-medium.png",
    subgroup = "chemical-spill",
    order = "d[chemical-spill]-a[green]-a[medium]",
    collision_box = {{-2, -2}, {2, 2}},
    selection_box = {{-2, -2}, {2, 2}},
    selectable_in_game = false,
    render_layer = "decorative",
    pictures =
    {
      {
        filename = "__wreckage-pollution__/graphics/entity/chemical-spill-medium.png",
        width = 128,
        height = 128,
      }
    }
  },

  {
    type = "decorative",
    name = "chemical-spill-large",
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
    icon = "__wreckage-pollution__/graphics/entity/chemical-spill-large.png",
    subgroup = "chemical-spill",
    order = "d[chemical-spill]-a[green]-a[large]",
    collision_box = {{-3, -3}, {3, 3}},
    selection_box = {{-3, -3}, {3, 3}},
    selectable_in_game = false,
    render_layer = "decorative",
    pictures =
    {
      {
        filename = "__wreckage-pollution__/graphics/entity/chemical-spill-large.png",
        width = 192,
        height = 192,
      }
    }
  },

})