---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local GetCVar = GetCVar
local SetCVar = SetCVar

-- ==============================
-- 게임설정 목록
-- ==============================
local NAMEPLATE_CLASS_COLOR = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local NAMEPLATE_ONLY_NAME   = "nameplateShowOnlyNameForFriendlyPlayerUnits"

local OPTIMIZED_CVARS = {
    { "deselectOnClick",                    1     },
    { "autoDismountFlying",                 1     },
    { "autoLootDefault",                    1     },
    { "SoftTargetInteract",                 3     },
    { "cameraWaterCollision", 0     },
    { "cameraSmoothStyle", 0     },
    { "showTutorials",                      0     },
    { "Outline",                            3     },
    { "raidFramesDisplayIncomingHeals",     1     },
    { "raidFramesDisplayPowerBar",          1     },
    { "raidFramesDisplayOnlyHealerPowerBars", 1   },
    { "raidFramesDisplayAggroHighlight",    1     },
    { "raidFramesDisplayClassColor",        1     },
    { "raidFramesDisplayDispels",           1     },
    { "raidFramesDisplayLargerRoleSpecificDebuffs", 1 },
    { "raidFramesCenterBigDefensive", 1 },
    { "raidFramesDispelIndicatorType", 2 },
    { "raidFramesDispelIndicatorOverlay", 1 },
    { "raidFramesDispelIndicatorOverlayAnimation", 1 },
    { "raidFramesHealthText",               "none"   },
    { "worldMapShowPlayerCoords", 1 },
    { "worldMapShowCursorCoords", 1 },
    { "countdownForCooldowns",              1     },
    { "enableMultiActionBars",              127   },
    { "findYourselfAnywhere",               1     },
    { "findYourselfModeCircle",             1     },
    { "findYourselfModeOutline",            1     },
    { "occludedSilhouettePlayer",            1     },
    { "showTargetOfTarget",            1     },
    { "chatStyle", "im" },
    { "whisperMode", "popout_and_inline" },
    { "showTimestamps", "%H:%M" },
    { "combatWarningsEnabled", 1 },
    { "encounterWarningsEnabled",           1     },
    { "cooldownViewerEnabled", 1 },
    { "externalDefensivesEnabled", 1 },
    { "damageMeterEnabled",                 1     },
    { "damageMeterResetOnNewInstance",      1     },
    { "nameplateMaxDistance",               60    },
    { "nameplateMinScale",                  1     },
    { "nameplateMaxScale",                  1     },
    { "nameplateMinAlpha",                  0.9   },
    { "nameplateOccludedAlphaMult",         0.4   },
    { NAMEPLATE_CLASS_COLOR,                1     },
    { NAMEPLATE_ONLY_NAME,                  1     },
    { "questTextContrast", 1 },
    { "advancedCombatLogging",              1     },
    { "cameraDistanceMaxZoomFactor",        2.6   },
    { "cameraIndirectVisibility",           1     },
    { "cameraIndirectOffset",               10    },
    { "showDungeonEntrancesOnMap",          1     },
    { "screenshotQuality",                  10    },
    { "xpBarText",                          1     },
}

function dodo:SetupCVars()
    if not dodoDB.cvarBackup then
        local backup = {}
        for _, info in ipairs(OPTIMIZED_CVARS) do
            backup[info[1]] = GetCVar(info[1])
        end
        dodoDB.cvarBackup = backup
    else
        local backup = dodoDB.cvarBackup
        for _, info in ipairs(OPTIMIZED_CVARS) do
            if backup[info[1]] == nil then
                backup[info[1]] = GetCVar(info[1])
            end
        end
    end
    for _, info in ipairs(OPTIMIZED_CVARS) do
        local cvar, value = info[1], info[2]
        if GetCVar(cvar) ~= tostring(value) then
            SetCVar(cvar, value)
        end
    end
    print("|cffffd200[dodo]|r 게임 설정 최적화가 완료되었습니다.")
end

function dodo:RestoreCVars()
    if not dodoDB.cvarBackup then
        print("|cffffd200[dodo]|r 복원할 백업이 없습니다.")
        return
    end
    local backup = dodoDB.cvarBackup
    dodoDB.cvarBackup = nil
    for _, info in ipairs(OPTIMIZED_CVARS) do
        local saved = backup[info[1]]
        if saved then SetCVar(info[1], saved) end
    end
    print("|cffffd200[dodo]|r 게임 설정이 복원되었습니다.")
end

-- ==============================
-- 그래픽설정 목록
-- ==============================
local GRAPHICS_CVARS = {
    { "vsync",                              0     },
    { "RAIDsettingsEnabled",       0 },
    { "graphicsShadowQuality",     0 },
    { "graphicsLiquidDetail",      0 },
    { "graphicsParticleDensity",   1 },
    { "graphicsSSAO",              0 },
    { "graphicsDepthEffects",      0 },
    { "graphicsComputeEffects",    0 },
    { "graphicsOutlineMode",       1 },
    { "graphicsTextureResolution", 2 },
    { "graphicsSpellDensity",      0 },
    { "graphicsProjectedTextures", 0 },
    { "graphicsViewDistance",      0 },
    { "graphicsEnvironmentDetail", 0 },
    { "graphicsGroundClutter",     0 },
    { "ResampleAlwaysSharpen",     1 },
    { "Contrast",                           70    },
    { "volumeFogLevel",                     0     },
    { "weatherDensity",                     0     },
    { "worldPreloadNonCritical",            0     },
    { "Sound_EnableReverb",        0 },
}

function dodo:SetupGraphics()
    if not dodoDB.graphicsBackup then
        local backup = {}
        for _, info in ipairs(GRAPHICS_CVARS) do
            backup[info[1]] = GetCVar(info[1])
        end
        dodoDB.graphicsBackup = backup
    else
        local backup = dodoDB.graphicsBackup
        for _, info in ipairs(GRAPHICS_CVARS) do
            if backup[info[1]] == nil then
                backup[info[1]] = GetCVar(info[1])
            end
        end
    end
    for _, info in ipairs(GRAPHICS_CVARS) do
        local cvar, value = info[1], info[2]
        if GetCVar(cvar) ~= tostring(value) then
            SetCVar(cvar, value)
        end
    end
    print("|cffffd200[dodo]|r 그래픽 설정 최적화가 완료되었습니다.")
end

function dodo:RestoreGraphics()
    if not dodoDB.graphicsBackup then
        print("|cffffd200[dodo]|r 복원할 백업이 없습니다.")
        return
    end
    local backup = dodoDB.graphicsBackup
    dodoDB.graphicsBackup = nil
    for _, info in ipairs(GRAPHICS_CVARS) do
        local saved = backup[info[1]]
        if saved then SetCVar(info[1], saved) end
    end
    print("|cffffd200[dodo]|r 그래픽 설정이 복원되었습니다.")
end
