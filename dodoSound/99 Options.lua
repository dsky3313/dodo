---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 음원 테이블 (설정창 드롭다운용)
-- ==============================

---@class AudioSoundItem
---@field text string
---@field value string

---@type AudioSoundItem[]
local sound_encounter_start_table = {
    { text = "돌격", value = "16971" },
}

---@type AudioSoundItem[]
local sound_encounter_victory_table = {
    { text = "PVP 얼라이언스", value = "38352" },
    { text = "퀘스트 추가",     value = "618"   },
    { text = "PVP 승리",       value = "34091" },
}

---@type AudioSoundItem[]
local alert_sound_table = {
    { text = "멀록",    value = "416"    },
    { text = "경매장1", value = "5274"   },
    { text = "경매장2", value = "5275"   },
    { text = "PVP1",   value = "9378"   },
    { text = "PVP2",   value = "9379"   },
    { text = "퀘스트",  value = "26905"  },
    { text = "레이드1", value = "8959"   },
    { text = "레이드2", value = "11773"  },
    { text = "인간여성", value = "552141" },
}

local colors      = dodo.Colors
local soft_red_hex = (colors and colors.SoftRed and colors.SoftRed.hex) or "ffff3232"

-- ==============================
-- 설정 등록 — 오디오 동기화 / 보스 사운드
-- ==============================
dodo.RegisterOption("음성", function(category)
    dodo.UI:SettingsCheckbox(category, "useAudioSync", "출력장치 동기화",
        "출력장치 변경 시 오디오를 자동 동기화합니다.", true,
        function(val)
            if dodo.AudioUpdateEventRegistration then dodo.AudioUpdateEventRegistration() end
            if val then
                if dodo.AudioSyncNow then dodo.AudioSyncNow(true) end
            else
                print("[|c" .. soft_red_hex .. "dodo|r] 오디오 동기화 비활성화")
            end
        end)

    dodo.UI:SettingsCheckboxDropDown(category,
        "useSoundEncounterStart", "useSoundEncounterStart_soundID",
        "보스전 시작", "보스전 시작 시 효과음을 재생합니다.",
        sound_encounter_start_table, true, "16971",
        function(val)
            if dodo.AudioUpdateEventRegistration then dodo.AudioUpdateEventRegistration() end
            if val and dodo.AudioPlayEncounterStart then dodo.AudioPlayEncounterStart() end
        end)

    dodo.UI:SettingsCheckboxDropDown(category,
        "useSoundEncounterVictory", "useSoundEncounterVictory_soundID",
        "보스전 승리", "보스전 승리 시 효과음을 재생합니다.",
        sound_encounter_victory_table, true, "38352",
        function(val)
            if dodo.AudioUpdateEventRegistration then dodo.AudioUpdateEventRegistration() end
            if val and dodo.AudioPlayEncounterVictory then dodo.AudioPlayEncounterVictory() end
        end)
end, 8000)

-- ==============================
-- 설정 등록 — 파티 신청 알림
-- ==============================
dodo.RegisterOption("음성", function(category)
    local setting_parent = nil
    local setting_child  = nil

    local function on_parent_changed(_, value)
        if value == false and setting_child then
            setting_child:SetValue(false)
        end
    end

    local function is_parent_active()
        return setting_parent and setting_parent:GetValue() or true
    end

    local init_parent_lfg
    setting_parent, _, init_parent_lfg = dodo.UI:SettingsCheckboxDropDown(
        category,
        "useNewLFG", "soundID",
        "파티신청 알림", "새로운 파티신청 시 알림",
        alert_sound_table, true, alert_sound_table[2].value,
        function() if dodo.NewLFG then dodo.NewLFG() end end
    )

    local init_child_lfg
    init_child_lfg, setting_child = dodo.UI:SettingsCheckbox(
        category,
        "useNewLFGLeader",
        "파티원 기능 활성화", "파티원일 경우에도 활성화합니다.",
        true,
        function() if dodo.NewLFG then dodo.NewLFG() end end
    )

    if setting_parent and setting_child then
        setting_parent:SetValueChangedCallback(on_parent_changed)
        init_child_lfg:SetParentInitializer(init_parent_lfg, is_parent_active)
    end
end, 8001)
