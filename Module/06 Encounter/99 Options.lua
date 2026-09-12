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
    -- 텍스트 알림 (04 Text.lua DEFAULT_ICON_SIZE / DEFAULT_FONT_SIZE 와 동일)
    enableEncounterText                = true,
    encounterTextIconSize              = 30,
    encounterTextFontSize              = 15,
    -- 타임라인 색상
    enableEncounterTimelineColor       = true,
    useEncounterTimelineColorHighlight = false,
    -- 소리
    enableEncounterSound               = true,
    soundEncounterAdds                 = "Adds",
    soundEncounterAOE                  = "AOE",
    soundEncounterDispel               = "Dispel",
    soundEncounterFrontal              = "Frontal",
    soundEncounterInterrupt            = "Interrupt",
    soundEncounterPhase                = "Phase",
    soundEncounterPool                 = "Pool",
    soundEncounterSoak                 = "Soak",
    soundEncounterTank                 = "Tank",
}

-- ==============================
-- /dd 설정 등록
-- ==============================
dodo.RegisterOption("우두머리 경보", function(category)
    local D = dodo.EC_DEFAULTS

    -- 마스터 토글
    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableEncounter", "우두머리 경보 모듈 활성화",
        "우두머리 경보 기능을 활성화합니다.",
        D.enableEncounter, function(val)
            if dodoDB then dodoDB.enableEncounter = val end
            if dodo.EncounterApplySounds then dodo.EncounterApplySounds() end
            if dodo.EncounterUpdateTimelineVisual then dodo.EncounterUpdateTimelineVisual() end
        end)

    local _text_sub     = {}
    local _timeline_sub = {}
    local _common_sub   = {}
    local _ts_sub       = {}  -- 텍스트 크기 서브 (텍스트 탭 + text ON 일 때만)
    local _sub_drop     = {}
    local function T(v)  if v then _text_sub[#_text_sub+1]         = v end return v end
    local function L(v)  if v then _timeline_sub[#_timeline_sub+1] = v end return v end
    local function C(v)  if v then _common_sub[#_common_sub+1]     = v end return v end
    local function TS(v) if v then _ts_sub[#_ts_sub+1]             = v end return v end

    local _preview_init = dodo.UI:SettingsTabbedPreview(category, {"텍스트", "타임라인(막대)"}, dodoEncounterPreviewMixin)

    -- ── 텍스트 알림 탭 ──────────────────────────────────────
    T(dodo.UI:SettingsSectionHeader(category, "텍스트 알림"))

    local text_init, text_setting = dodo.UI:SettingsCheckbox(category, "enableEncounterText", "텍스트 알림",
        "우두머리 기술 시전 5초전에 텍스트 알림을 표시합니다.",
        D.enableEncounterText, function(val)
            if dodoDB then dodoDB.enableEncounterText = val end
            if dodo.EncounterRefreshPreview then dodo.EncounterRefreshPreview() end
        end)
    T(text_init)

    -- LEM 설정과 동일한 DB 키 (encounterTextIconSize / encounterTextFontSize)
    TS(dodo.UI:SettingsSlider(category, "encounterTextIconSize", "아이콘 크기",
        "텍스트 알림 아이콘의 크기를 설정합니다.",
        16, 48, 1, D.encounterTextIconSize, "Integer", function(val)
            if dodoDB then dodoDB.encounterTextIconSize = val end
            if dodo.EncounterRefreshText    then dodo.EncounterRefreshText()    end
            if dodo.EncounterRefreshPreview then dodo.EncounterRefreshPreview() end
        end))

    TS(dodo.UI:SettingsSlider(category, "encounterTextFontSize", "텍스트 크기",
        "텍스트 알림 글자 크기를 설정합니다.",
        10, 24, 1, D.encounterTextFontSize, "Integer", function(val)
            if dodoDB then dodoDB.encounterTextFontSize = val end
            if dodo.EncounterRefreshText    then dodo.EncounterRefreshText()    end
            if dodo.EncounterRefreshPreview then dodo.EncounterRefreshPreview() end
        end))

    -- ── 타임라인 색상 탭 ────────────────────────────────────
    L(dodo.UI:SettingsSectionHeader(category, ""))

    local color_init, color_setting = dodo.UI:SettingsCheckbox(category, "enableEncounterTimelineColor", "타임라인 색상 변경",
        "우두머리 경보 막대에 역할별 색상을 적용합니다.",
        D.enableEncounterTimelineColor, function(val)
            if dodoDB then dodoDB.enableEncounterTimelineColor = val end
            if dodo.EncounterUpdateTimelineVisual then dodo.EncounterUpdateTimelineVisual() end
            if dodo.EncounterRefreshPreview then dodo.EncounterRefreshPreview() end
        end)
    L(color_init)

    local highlight_init = dodo.UI:SettingsCheckbox(category, "useEncounterTimelineColorHighlight", "5초 전 색상강조",
        "경보 5초 전, 막대 색상을 빨간색으로 강조합니다.",
        D.useEncounterTimelineColorHighlight, function(val)
            if dodoDB then dodoDB.useEncounterTimelineColorHighlight = val end
            if dodo.EncounterUpdateTimelineVisual then dodo.EncounterUpdateTimelineVisual() end
            if dodo.EncounterRefreshPreview then dodo.EncounterRefreshPreview() end
        end)
    L(highlight_init)
    if highlight_init and color_init and highlight_init.SetParentInitializer then
        highlight_init:SetParentInitializer(color_init, function() return color_setting:GetValue() end)
    end

    -- ── 소리 (두 탭 모두, 항상 하단) ───────────────────────
    C(dodo.UI:SettingsSectionHeader(category, "소리"))

    local sound_init, sound_setting = dodo.UI:SettingsCheckbox(category, "enableEncounterSound", "소리 알림",
        "우두머리 능력에 맞게 소리를 재생합니다.",
        D.enableEncounterSound, function(val)
            if dodoDB then dodoDB.enableEncounterSound = val end
            if dodo.EncounterApplySounds then dodo.EncounterApplySounds() end
        end)
    C(sound_init)

    local sound_opts = {
        { value = "Adds",      text = "쫄 소환" },
        { value = "AOE",       text = "광역"    },
        { value = "Dispel",    text = "해제"    },
        { value = "Frontal",   text = "정면"    },
        { value = "Interrupt", text = "차단"    },
        { value = "Phase",     text = "페이즈"  },
        { value = "Pool",      text = "장판"    },
        { value = "Soak",      text = "흡수"    },
        { value = "Tank",      text = "탱커"    },
        { value = "none",      text = "없음"    },
    }
    local sound_items = {
        { key = "soundEncounterAdds",      label = "쫄 소환" },
        { key = "soundEncounterAOE",       label = "광역"    },
        { key = "soundEncounterDispel",    label = "해제"    },
        { key = "soundEncounterFrontal",   label = "정면"    },
        { key = "soundEncounterInterrupt", label = "차단"    },
        { key = "soundEncounterPhase",     label = "페이즈"  },
        { key = "soundEncounterPool",      label = "장판"    },
        { key = "soundEncounterSoak",      label = "흡수"    },
        { key = "soundEncounterTank",      label = "탱커"    },
    }
    for _, item in ipairs(sound_items) do
        local _, drop_init = dodo.UI:SettingsDropDown(category, item.key, item.label, "", sound_opts, D[item.key], function(val)
            if dodoDB then dodoDB[item.key] = val end
            if val ~= "none" and dodo.EncounterPlaySoundKey then dodo.EncounterPlaySoundKey(val) end
            if dodo.EncounterApplySounds then dodo.EncounterApplySounds() end
        end)
        C(drop_init)
        _sub_drop[#_sub_drop + 1] = drop_init
    end

    -- 탭 전환 시 predicate 재평가 트리거
    dodo.EncounterSetTabChangeFn(function()
        if master_setting then master_setting:SetValue(master_setting:GetValue()) end
    end)

    local function _shown()          return master_setting:GetValue() end
    local function _text_shown()     return master_setting:GetValue() and dodo.EncounterGetPreviewTab() == "text" end
    local function _timeline_shown() return master_setting:GetValue() and dodo.EncounterGetPreviewTab() == "timeline" end
    local function _ts_shown()       return _text_shown() and text_setting and text_setting:GetValue() end
    local function is_sound_active() return sound_setting:GetValue() end

    if _preview_init and _preview_init.AddShownPredicate then
        _preview_init:AddShownPredicate(_shown)
    end
    for _, v in ipairs(_text_sub)     do if v.AddShownPredicate then v:AddShownPredicate(_text_shown)     end end
    for _, v in ipairs(_ts_sub)       do if v.AddShownPredicate then v:AddShownPredicate(_ts_shown)       end end
    for _, v in ipairs(_timeline_sub) do if v.AddShownPredicate then v:AddShownPredicate(_timeline_shown) end end
    for _, v in ipairs(_common_sub)   do if v.AddShownPredicate then v:AddShownPredicate(_shown)          end end
    for _, v in ipairs(_sub_drop)     do if v.SetParentInitializer then v:SetParentInitializer(sound_init, is_sound_active) end end
end, 6000)
