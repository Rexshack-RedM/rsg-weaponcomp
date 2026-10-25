----------------------------------------
-- Shared component helpers (client + server)
----------------------------------------
WeaponComp = {}

--- Categories whose first config entry is the weapon's factory part (the wooden stock
--- is GRIP on long arms). Every other category is an optional cosmetic that can be
--- left on "Factory" (nothing applied).
WeaponComp.FactoryCategories = {
    BARREL = true, GRIP = true, SIGHT = true, CLIP = true, TUBE = true, MAG = true, STOCK = true,
}

function WeaponComp.IsFactoryCategory(cat)
    return WeaponComp.FactoryCategories[cat] == true
end

--- Application order: base parts first, then materials, engravings, tints, wraps last.
--- Tints/materials must go on after the stock/grip model or the game drops them.
local BASE_ORDER = {
    BARREL = 1, GRIP = 2, STOCK = 4, SIGHT = 5, SCOPE = 6, CLIP = 7, MAG = 8, TUBE = 9,
    WRAP = 60, WRAP_MATERIAL = 65, WRAP_TINT = 70,
}

function WeaponComp.Priority(cat)
    if BASE_ORDER[cat] then return BASE_ORDER[cat] end
    if cat:find('RIFLING') then return 20 end
    if cat:find('ENGRAVING_MATERIAL') then return 45 end
    if cat:find('_MATERIAL') then return 30 end
    if cat:find('_ENGRAVING') then return 40 end
    if cat:find('_TINT') then return 50 end
    return 35
end

function WeaponComp.SortedKeys(comps)
    local keys = {}
    for k in pairs(comps) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local pa, pb = WeaponComp.Priority(a), WeaponComp.Priority(b)
        if pa == pb then return a < b end
        return pa < pb
    end)
    return keys
end

--- Price of going from `current` to `new`. Changing/adding a part costs its price,
--- removing a cosmetic back to factory costs Config.RemovePrice of it.
--- Returns price, changed.
function WeaponComp.ChangePrice(current, new)
    local total, changed = 0, false
    for cat, comp in pairs(new) do
        if current[cat] ~= comp then
            total = total + (Config.price[cat] or 0)
            changed = true
        end
    end
    for cat in pairs(current) do
        if new[cat] == nil then
            total = total + (Config.price[cat] or 0) * (Config.RemovePrice or 0.5)
            changed = true
        end
    end
    return math.floor(total * 100 + 0.5) / 100, changed
end
