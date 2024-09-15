---@type {version: string?, data_version: string?}
global = global
if global.pollution_sources then
    for _, v in pairs(global.pollution_sources) do
        v.amount = v.amount * 10  -- v0.15 multiplied fluid amounts by 10
    end
end
