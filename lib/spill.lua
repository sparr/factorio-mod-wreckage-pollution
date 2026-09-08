--- What kind of spill a fluid makes, and how big.
---
--- Everything here is a decision about names and numbers, with no game in it, so the data
--- stage and the control stage can both ask and the unit tier can check the answers
--- without a game running. Which fluids are ignored and which do not pollute used to be
--- written out once in each stage, and the two lists could drift apart.
local spill = {}

--- Fluid types that will not make a spill at all
spill.IGNORED_FLUIDS = {
  ["steam"] = true,
}

--- Fluid types that make a puddle, but do not pollute
spill.NON_POLLUTANTS = {
  ["water"] = true,
}

spill.SIZES = { "small", "medium", "large" }

---Whether a destroyed fluid leaves anything behind at all.
---@param fluid_name string
---@return boolean
function spill.ignored(fluid_name)
  return spill.IGNORED_FLUIDS[fluid_name] == true
end

---Which of the two families of spill entity a fluid belongs to.
---@param fluid_name string
---@return "chemical-spill"|"liquid-spill"
function spill.kind(fluid_name)
  if spill.NON_POLLUTANTS[fluid_name] == true then
    return "liquid-spill"
  end
  return "chemical-spill"
end

---How big a spill an amount of fluid makes.
---
---The thresholds are startup settings, passed in rather than read here so that this stays
---answerable without a game.
---@param amount number
---@param medium_threshold number at or above this it is no longer small
---@param large_threshold number at or above this it is large
---@return "small"|"medium"|"large"
function spill.size(amount, medium_threshold, large_threshold)
  if amount < medium_threshold then
    return "small"
  elseif amount < large_threshold then
    return "medium"
  end
  return "large"
end

---The entity prototype a spill of this fluid at this size is called.
---@param fluid_name string
---@param size "small"|"medium"|"large"
---@return string
function spill.entity_name(fluid_name, size)
  return spill.kind(fluid_name) .. "-" .. fluid_name .. "-" .. size
end

---@class HeldFluid
---@field fluid string
---@field amount number per one of the item

---Which items are containers holding a fluid, worked out from the recipes that empty
---them. A barrel is only a barrel because a recipe turns one of them back into fifty
---units of something, and that is as true of a modded canister as of a vanilla barrel.
---
---The shape looked for is: one item goes in, no fluid goes in, one fluid comes out, and
---an item comes out too. That last part is what separates a container from a conversion.
---Melting one ice into twenty water is the same shape without it, and ice is not a
---container -- it is the thing itself.
---@param recipe_prototypes table<string, {ingredients: table[], products: table[]}>
---@return table<string, HeldFluid>
function spill.containers(recipe_prototypes)
  local held = {}
  for _, recipe in pairs(recipe_prototypes) do
    local item_in, fluid_out, item_out, ok = nil, nil, false, true
    for _, ingredient in pairs(recipe.ingredients or {}) do
      if ingredient.type == "fluid" then
        ok = false
      elseif item_in then
        ok = false
      else
        item_in = ingredient
      end
    end
    if ok and item_in and item_in.amount == 1 then
      for _, product in pairs(recipe.products or {}) do
        if product.type == "fluid" then
          if fluid_out then ok = false else fluid_out = product end
        else
          item_out = true
        end
      end
      if ok and item_out and fluid_out and (fluid_out.amount or 0) > 0 then
        held[item_in.name] = { fluid = fluid_out.name, amount = fluid_out.amount }
      end
    end
  end
  return held
end

---@class Harvest
---@field item string the fruit a plant gives up
---@field amount number how much of it one plant yields

---What a plant yields when it is taken, out of a mining results list. The first item in
---the list is the fruit; a plant that yields nothing yields nothing.
---
---Pure, so both stages can ask and the unit tier can check without a game. The data stage
---calls its list `results` and the control stage calls it `products`; the caller hands
---over whichever it has.
---@param results table[]?
---@return Harvest?
function spill.harvest(results)
  for _, result in pairs(results or {}) do
    if result.type == "item" and result.name then
      local amount = result.amount or result.amount_max or result.amount_min
      if amount and amount > 0 then
        return { item = result.name, amount = amount }
      end
    end
  end
  return nil
end

--- What colour a spill of something that is not a fluid is drawn in, when whatever ships
--- it offers none.
spill.DEFAULT_COLOUR = { r = 0.6, g = 0.6, b = 0.5, a = 1 }

---@class SpillBox
---@field left_top {x: number, y: number}
---@field right_bottom {x: number, y: number}

---The area of a bounding box, which stands in for how big a wreck is. Corpses that carry
---no box at all count for nothing rather than erroring.
---
---Described structurally rather than as Factorio's BoundingBox, because nothing in this
---file is allowed to need a game.
---@param box SpillBox?
---@return number
function spill.bounding_box_area(box)
  if not box or not box.right_bottom or not box.right_bottom.x then
    return 0
  end
  return (box.right_bottom.x - box.left_top.x) *
         (box.right_bottom.y - box.left_top.y)
end

return spill
