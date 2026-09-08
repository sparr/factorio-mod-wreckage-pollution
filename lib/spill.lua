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
