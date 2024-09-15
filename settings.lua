data:extend(
  {
    {
      type = "double-setting",
      name = "pollution_intensity",
      setting_type = "runtime-global",
      default_value = 0.25,
      minimum_value = 0,
      maximum_value = 1.0
    },
    {
      type = "double-setting",
      name = "pollution_evaporation",
      setting_type = "runtime-global",
      default_value = 0.005,
      minimum_value = 0,
      maximum_value = 1.0
    },
    {
      type = "int-setting",
      name = "medium_spill_threshold",
      setting_type = "startup",
      default_value = 1000,
      minimum_value = 100,
      maximum_value = 10000
    },
    {
      type = "int-setting",
      name = "large_spill_threshold",
      setting_type = "startup",
      default_value = 10000,
      minimum_value = 1000,
      maximum_value = 100000
    }
  }--[=[@as data.AnyModSetting[]]=]
)
