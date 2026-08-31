---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local GetCVar = GetCVar
local SetCVar = SetCVar

-- ==============================
-- CVar 최적화 목록
-- ==============================
local NAMEPLATE_CLASS_COLOR = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local NAMEPLATE_ONLY_NAME   = "nameplateShowOnlyNameForFriendlyPlayerUnits"

local OPTIMIZED_CVARS = {
    { "countdownForCooldowns",              1     },
    { "screenshotQuality",                  10    },
    { "showTutorials",                      0     },
    { "damageMeterEnabled",                 1     },
    { "damageMeterResetOnNewInstance",      1     },
    { "encounterWarningsEnabled",           1     },
    { "nameplateMaxDistance",               60    },
    { "nameplateMinScale",                  1     },
    { "nameplateMaxScale",                  1     },
    { "nameplateMinAlpha",                  0.9   },
    { "nameplateOccludedAlphaMult",         0.4   },
    { NAMEPLATE_CLASS_COLOR,                1     },
    { NAMEPLATE_ONLY_NAME,                  1     },
    { "cameraDistanceMaxZoomFactor",        2.6   },
    { "cameraIndirectVisibility",           1     },
    { "cameraIndirectOffset",               10    },
    { "advancedCombatLogging",              1     },
    { "autoDismountFlying",                 1     },
    { "autoLootDefault",                    1     },
    { "Contrast",                           70    },
    { "deselectOnClick",                    1     },
    { "enableMultiActionBars",              127   },
    { "findYourselfAnywhere",               1     },
    { "findYourselfModeCircle",             1     },
    { "findYourselfModeOutline",            1     },
    { "ResampleAlwaysSharpen",              1     },
    { "showDungeonEntrancesOnMap",          1     },
    { "SoftTargetInteract",                 3     },
    { "spellActivationOverlayOpacity",      0.25  },
    { "volumeFogLevel",                     0     },
    { "vsync",                              0     },
    { "weatherDensity",                     0     },
    { "worldPreloadNonCritical",            0     },
    { "xpBarText",                          1     },
}

function dodo:SetupCVars()
    for _, info in ipairs(OPTIMIZED_CVARS) do
        local cvar, value = info[1], info[2]
        if GetCVar(cvar) ~= tostring(value) then
            SetCVar(cvar, value)
        end
    end
    print("|cffffd200[dodo]|r 게임 설정 최적화가 완료되었습니다.")
end
