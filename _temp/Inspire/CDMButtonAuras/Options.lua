local addonName, addon = ...

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local defaults = {
    global = {
    },
    profile = {
        auraMap = { },
    },
    char = {
    },
}

function addon.InitializeOptions()
    addon.db = LibStub("AceDB-3.0"):New("CDMButtonAurasDB", defaults, true)
    addon.UpdateAuraMap()
end

function addon.SetOption(option, value, key)
    key = key or "profile"
    if not defaults[key] then return end
    if value == "default" or value == DEFAULT:lower() or value == nil then
        value = defaults[key][option]
    end
    if type(defaults[key][option]) == 'boolean' then
        addon.db[key][option] = ValueToBoolean(value)
    elseif type(defaults[key][option]) == 'number' then
        if tonumber(value) then
            addon.db[key][option] = tonumber(value)
        end
    else
        addon.db[key][option] = value
    end
    addon.db.callbacks:Fire('OnModified')
end

function addon.SetOptionOutsideUI(option, value, key)
    addon.SetOption(option, value, key)
    AceConfigRegistry:NotifyChange(addonName)
end

function addon.AddAuraMap(auraSpell, abilitySpell)
    auraSpell = tonumber(auraSpell) or auraSpell
    abilitySpell = tonumber(abilitySpell) or abilitySpell

    if addon.db.profile.auraMap[auraSpell] then
        table.insert(addon.db.profile.auraMap[auraSpell], abilitySpell)
    else
        addon.db.profile.auraMap[auraSpell] = { abilitySpell }
    end
    addon.UpdateAuraMap()
    AceConfigRegistry:NotifyChange(addonName)
end

function addon.RemoveAuraMap(auraSpell, abilitySpell)
    auraSpell = tonumber(auraSpell) or auraSpell
    abilitySpell = tonumber(abilitySpell) or abilitySpell
    if not addon.db.profile.auraMap[auraSpell] then return end

    tDeleteItem(addon.db.profile.auraMap[auraSpell], abilitySpell)

    if next(addon.db.profile.auraMap[auraSpell]) == nil then
        if not defaults.profile.auraMap[auraSpell] then
            addon.db.profile.auraMap[auraSpell] = nil
        else
            addon.db.profile.auraMap[auraSpell] = { false }
        end
    end
    addon.UpdateAuraMap()
    AceConfigRegistry:NotifyChange(addonName)
end

function addon.DefaultAuraMap()
    addon.db.profile.auraMap = CopyTable(defaults.profile.auraMap)
    addon.UpdateAuraMap()
    AceConfigRegistry:NotifyChange(addonName)
end

function addon.WipeAuraMap()
    addon.db.profile.auraMap = {}
    addon.UpdateAuraMap()
    AceConfigRegistry:NotifyChange(addonName)
end

function addon.SpellString(spellID, spellName)
    spellName = NORMAL_FONT_COLOR:WrapTextInColorCode(spellName)
    if spellID then
        return string.format("%s (%d)", spellName, spellID)
    else
        return spellName
    end
end

function addon.AuraMapString(auraID, auraName, abilityID, abilityName)
    return string.format(
                "%s %s %s",
                addon.SpellString(auraID, auraName),
                L["on"],
                addon.SpellString(abilityID, abilityName)
            )
end

function addon.GetAuraMapList()
    local out = { }
    for showAura, onAbilityTable in pairs(addon.db.profile.auraMap) do
        for _, onAbility in ipairs(onAbilityTable) do
            local auraName, auraID, abilityName, abilityID
            if type(showAura) == 'number' then
                local info = C_Spell.GetSpellInfo(showAura)
                if info then
                    auraName = info.name
                    auraID = info.spellID
                end
            else
                auraName = showAura
            end
            if type(onAbility) == 'number' then
                local info = C_Spell.GetSpellInfo(onAbility)
                if info then
                    abilityName = info.name
                    abilityID = info.spellID
                end
            else
                abilityName = onAbility
            end
            if auraName and abilityName then
                table.insert(out, { auraID, auraName, abilityID, abilityName })
            end
        end
    end
    sort(out, function (a, b) return a[2]..a[4] < b[2]..b[4] end)
    return out
end

function addon.ApplyDefaultSettings()
    addon.db:ResetProfile()
    AceConfigRegistry:NotifyChange(addonName)
end

addon.AuraMap = {}

function addon.UpdateAuraMap()
    addon.AuraMapByName = {}
    for showAura, onAbilityTable in pairs(addon.db.profile.auraMap) do
        if type(showAura) == 'number' then
            showAura = C_Spell.GetSpellName(showAura)
        end
        for _, onAbility in ipairs(onAbilityTable) do
            local spellID = C_Spell.GetSpellIDForSpellIdentifier(onAbility)
            local baseSpellID = C_Spell.GetBaseSpell(spellID)
            onAbility = C_Spell.GetSpellName(baseSpellID)
            if showAura and onAbility then
                addon.AuraMapByName[showAura] = addon.AuraMapByName[showAura] or {}
                table.insert(addon.AuraMapByName[showAura], onAbility)
            end
        end
    end
end
