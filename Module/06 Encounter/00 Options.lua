-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 설정 기본값
-- ==============================
dodo.EC_DEFAULTS = {
    enableEncounter                    = true,
    enableEncounterSound               = true,
    enableEncounterText                = true,
    enableEncounterTimelineColor       = true,
    useEncounterTimelineColorHighlight = false,
}

-- ==============================
-- /dd 설정 등록
-- ==============================
dodo.RegisterOption("우두머리 경보", function(category)
    local D = dodo.EC_DEFAULTS

    -- 마스터 토글
    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableEncounter", "우두머리 경보 활성화",
        "우두머리 경보 타임라인 기능을 활성화합니다.",
        D.enableEncounter, function(val)
            if dodoDB then dodoDB.enableEncounter = val end
            if dodo.EncounterApplySounds then dodo.EncounterApplySounds() end
            if dodo.EncounterUpdateTimelineVisual then dodo.EncounterUpdateTimelineVisual() end
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    T(dodo.UI:SettingsSectionHeader(category, "소리"))

    T(dodo.UI:SettingsCheckbox(category, "enableEncounterSound", "소리 알림",
        "우두머리 기술 타임라인 이벤트에 맞게 소리를 재생합니다.",
        D.enableEncounterSound, function(val)
            if dodoDB then dodoDB.enableEncounterSound = val end
            if dodo.EncounterApplySounds then dodo.EncounterApplySounds() end
        end))

    T(dodo.UI:SettingsSectionHeader(category, "텍스트 알림"))

    T(dodo.UI:SettingsCheckbox(category, "enableEncounterText", "텍스트 알림",
        "우두머리 기술이 시전될 때 화면에 텍스트 알림을 표시합니다.",
        D.enableEncounterText, function(val)
            if dodoDB then dodoDB.enableEncounterText = val end
        end))

    T(dodo.UI:SettingsSectionHeader(category, "타임라인 색상"))

    T(dodo.UI:SettingsCheckbox(category, "enableEncounterTimelineColor", "타임라인 역할 색상",
        "우두머리 타임라인 이벤트에 역할별 색상을 적용합니다.",
        D.enableEncounterTimelineColor, function(val)
            if dodoDB then dodoDB.enableEncounterTimelineColor = val end
            if dodo.EncounterUpdateTimelineVisual then dodo.EncounterUpdateTimelineVisual() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useEncounterTimelineColorHighlight", "5초 강조 시 블리자드 기본 색상",
        "이벤트가 5초 전 강조될 때 블리자드 기본 색상으로 복원합니다. 꺼두면 역할 색상을 유지합니다.",
        D.useEncounterTimelineColorHighlight, function(val)
            if dodoDB then dodoDB.useEncounterTimelineColorHighlight = val end
            if dodo.EncounterUpdateTimelineVisual then dodo.EncounterUpdateTimelineVisual() end
        end))

    local function _shown() return master_setting:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 6000)
