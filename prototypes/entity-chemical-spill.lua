-- create prototypes for all types and sizes of chemical spills
-- one type per fluid prototype
-- three sizes per type
-- must run in data-updates or data-final-fixes to see all fluids from other mods' data

local spill_sizes = {
  small = { name = "small",  size = 1, max_amount = settings.startup["medium_spill_threshold"].value--[[@as integer]] },
  medium = { name = "medium", size = 2, max_amount = settings.startup["large_spill_threshold"].value--[[@as integer]] },
  large = { name = "large",  size = 3, max_amount = 25000 }, -- TODO get max fluid container size
}

local spill = require("lib.spill")

--- Everything that can be spilled, and the colour to draw it in.
---
--- Fluids come with a colour of their own. A plant's fruit does not, so it borrows the
--- tint the game already uses to show that plant on an agricultural tower, which is the
--- colour a player associates with it.
local spillable = {}
for name, proto in pairs(data.raw.fluid) do
  spillable[name] = { colour = proto.base_color, source = "fluid" }
end
for _, plant in pairs(data.raw.plant or {}) do
  local harvest = spill.harvest(plant.minable and plant.minable.results)
  if harvest and not spillable[harvest.item] then
    local tint = plant.agricultural_tower_tint
    spillable[harvest.item] = {
      colour = spill.FRUIT_COLOURS[harvest.item]
               or (tint and tint.primary)
               or spill.DEFAULT_COLOUR,
      source = "plant",
    }
  end
end

for name, spillable_data in pairs(spillable) do
  local proto = { name = name, base_color = spillable_data.colour }
  -- a fluid is named out of the fluid list, a fruit out of the item list
  local what_spilled = { (spillable_data.source == "fluid" and "fluid-name." or "item-name.")
                         .. name }
  for size_name, spill_data in pairs(spill_sizes) do
    local size = spill_data.size
    -- See what kind of entity this liquid gets
    local spill_type = spill.kind(name)

    data:extend(
      {
        {
          type = "simple-entity",
          name = spill.entity_name(proto.name, size_name),
          flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
          icon = "__wreckage-pollution__/graphics/entity/chemical-spill-" .. size_name .. ".png",
          icon_size = size * 64,
          subgroup = "chemical-spill",
          order = "d[chemical-spill]-a[" .. proto.name .. "]-a[" .. size_name .. "]",
          selection_box = {{-size, -size}, {size, size}},
          selectable_in_game = true,
          -- The full size of the sprite, so that what a spill covers is what a spill
          -- blocks. On the floor layer that is belts, rails, rail signals, heat pipes and
          -- pipes to ground -- the same set 1.1 kept off a spill, and rather more of it,
          -- since 2.0 moved splitters, loaders and underground belts onto this layer too.
          -- Assemblers and chests were never stopped by a spill and still are not.
          --
          -- Spills lie over one another all the same: they are placed rather than built,
          -- and create_entity does not ask about collision.
          collision_box = {{-size, -size}, {size, size}},
          -- 2.0 turned collision layers into prototypes and renamed floor-layer to
          -- floor. A spill is decoration: it lies on the ground and must not stop
          -- anything being built on top of it.
          collision_mask = {layers = {floor = true}},
          localised_name = {"entity-name." .. spill_type .. "-" .. size_name, what_spilled},
          localised_description = {"entity-description." .. spill_type .. "-" .. size_name, what_spilled},
          max_health = spill_data.max_amount,

          render_layer = "decorative",
          pictures =
          {
            {
              filename = "__wreckage-pollution__/graphics/entity/chemical-spill-" .. size_name .. ".png",
              width = size * 64,
              height = size * 64,
              tint = spillable_data.colour,
            }
          }
        },
      }
    )
  end
end
