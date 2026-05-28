local addonName, addon = ...

local L = setmetatable({}, { __index = function (_, k) return k end })

local function Getter(info)
    local k = info[#info]
    return addon.db.profile[k]
end

local function Setter(info, val ,...)
    local k = info[#info]
    addon.SetOption(k, val)
end

local function ValidateSpellValue(_, v)
    if v == "" then
        return true
    elseif v and C_Spell.GetSpellInfo(v) ~= nil then
        return true
    else
        return format(
                L["Error: unknown spell: %s"] ..
                 "\n\n" ..
                 L["For spells that aren't in your spell book use the spell ID number."],
                ORANGE_FONT_COLOR:WrapTextInColorCode(v))
    end
end

local order
do
    local n = 0
    order = function () n = n + 1 return n end
end

local addAuraMap = { }

local ValidateTexture = UIParent:CreateTexture()

local options = {
    type = "group",
    childGroups = "tab",
    args = {
        -- First options are just for the command line
        options = {
            type = "execute",
            name = L["Show options panel."],
            hidden = true,
            cmdHidden = false,
            order = order(),
            func = function () addon.OpenOptions() end,
        },
        MappingGroup = {
            type = "group",
            name = L["Extra aura displays"],
            inline = false,
            order = order(),
            args = {
                showAura = {
                    name = L["Show aura"],
                    type = "input",
                    width = 1.4,
                    order = order(),
                    get =
                        function ()
                            if addAuraMap[1] then
                                local info = C_Spell.GetSpellInfo(addAuraMap[1])
                                return ("%s (%s)"):format(info.name, info.spellID) .. "\0" .. addAuraMap[1]
                            end
                        end,
                    set =
                        function (_, v)
                            local info = C_Spell.GetSpellInfo(v)
                            addAuraMap[1] = info and info.spellID or nil
                        end,
                    control = 'LBAInputFocus',
                    validate = ValidateSpellValue,
                },
                preOnAbilityGap = {
                    name = "",
                    type = "description",
                    width = 0.1,
                    order = order(),
                },
                onAbility = {
                    name = L["On ability"],
                    type = "input",
                    width = 1.4,
                    order = order(),
                    get =
                        function ()
                            if addAuraMap[2] then
                                local info = C_Spell.GetSpellInfo(addAuraMap[2])
                                return ("%s (%s)"):format(info.name, info.spellID) .. "\0" .. addAuraMap[2]
                            end
                        end,
                    set =
                        function (_, v)
                            local info = C_Spell.GetSpellInfo(v)
                            addAuraMap[2] = info and info.spellID or nil
                        end,
                    control = 'LBAInputFocus',
                    validate = ValidateSpellValue,
                },
                preAddButtonGap = {
                    name = "",
                    type = "description",
                    width = 0.1,
                    order = order(),
                },
                AddButton = {
                    name = ADD,
                    type = "execute",
                    width = 0.5,
                    order = order(),
                    disabled =
                        function (info, v)
                            local auraName = addAuraMap[1] and C_Spell.GetSpellName(addAuraMap[1])
                            local abilityName = addAuraMap[2] and C_Spell.GetSpellName(addAuraMap[2])
                            if auraName and abilityName and auraName ~= abilityName then
                                return false
                            else
                                return true
                            end
                        end,
                    func =
                        function ()
                            local auraInfo = addAuraMap[1] and C_Spell.GetSpellInfo(addAuraMap[1])
                            local abilityInfo = addAuraMap[2] and C_Spell.GetSpellInfo(addAuraMap[2])
                            if auraInfo and abilityInfo then
                                addon.AddAuraMap(auraInfo.spellID, abilityInfo.spellID)
                                addAuraMap[1] = nil
                                addAuraMap[2] = nil
                            end
                        end,
                },
                Mappings = {
                    name = L["Extra aura displays"],
                    type = "group",
                    order = order(),
                    inline = true,
                    args = {},
                    plugins = {},
                }
            }
        },
    },
}

local function GenerateOptions()
    local auraMapList = addon.GetAuraMapList()
    local auraMaps = { }
    for i, entry in ipairs(auraMapList) do
        auraMaps["mapAura"..i] = {
            order = 10*i+1,
            name = addon.SpellString(entry[1], entry[2]),
            type = "description",
            image = C_Spell.GetSpellTexture(entry[1] or entry[2]),
            imageWidth = 22,
            imageHeight = 22,
            width = 1.4,
        }
        auraMaps["onText"..i] = {
            order = 10*i+2,
            name = GRAY_FONT_COLOR:WrapTextInColorCode(L["on"]),
            type = "description",
            width = 0.15,
        }
        auraMaps["mapAbility"..i] = {
            order = 10*i+3,
            name = addon.SpellString(entry[3], entry[4]),
            type = "description",
            image = C_Spell.GetSpellTexture(entry[3] or entry[4]),
            imageWidth = 22,
            imageHeight = 22,
            width = 1.4,
        }
        auraMaps["delete"..i] = {
            order = 10*i+4,
            name = DELETE,
            type = "execute",
            func = function () addon.RemoveAuraMap(entry[1], entry[3]) end,
            width = 0.45,
        }
    end
    options.args.MappingGroup.args.Mappings.plugins.auraMaps = auraMaps

    return options
end

-- The sheer amount of crap required here is ridiculous. I bloody well hate
-- frameworks, just give me components I can assemble. Dot-com weenies ruined
-- everything, even WoW.

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigCmd = LibStub("AceConfigCmd-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions =  LibStub("AceDBOptions-3.0")

-- AddOns are listed in the Blizzard panel in the order they are
-- added, not sorted by name. In order to mostly get them to
-- appear in the right order, add the main panel when loaded.

AceConfig:RegisterOptionsTable(addonName, GenerateOptions, { "cba" })
local optionsPanel, category = AceConfigDialog:AddToBlizOptions(addonName)

function addon.InitializeGUIOptions()
    local profileOptions = AceDBOptions:GetOptionsTable(addon.db)
    AceConfig:RegisterOptionsTable(addonName.."Profiles", profileOptions)
    AceConfigDialog:AddToBlizOptions(addonName.."Profiles", profileOptions.name, addonName)
end

function addon.OpenOptions()
    if not InCombatLockdown() then
        Settings.OpenToCategory(category)
    end
end
