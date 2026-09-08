local data = storage
if data.pollution_sources then
    for _, v in pairs(data.pollution_sources) do
        v.amount = v.amount * 10  -- v0.15 multiplied fluid amounts by 10
    end
end
