---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.RegisterOption("편의기능.쐐기돌", function(category)
    local _, master = dodo.UI:SettingsCheckbox(category, "enableKeystoneTimer", "쐐기 타이머",
        "M+ 타이머 블록을 리스킨하고 추가 정보를 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableKeystoneTimer = val end
            if dodo.KeystoneTimerUpdateVisual then dodo.KeystoneTimerUpdateVisual() end
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    T(dodo.UI:SettingsCheckbox(category, "useKeystoneTimerBarStyle", "디자인 변경",
        "적 세력 바 스타일을 변경합니다.",
        true, function(val)
            if dodoDB then dodoDB.useKeystoneTimerBarStyle = val end
            if dodo.KeystoneTimerUpdateVisual then dodo.KeystoneTimerUpdateVisual() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useKeystoneTimerPercent", "퍼센트 소수점",
        "적 세력 퍼센트를 소수점 2자리로 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.useKeystoneTimerPercent = val end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useKeystoneTimerTick", "+2 / +3 틱 표시",
        "시간 바에 +2/+3 시간 틱 마커를 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.useKeystoneTimerTick = val end
            if dodo.KeystoneTimerUpdateVisual then dodo.KeystoneTimerUpdateVisual() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "enableCollapse", "퀘스트 목록 접기",
        "인스턴스 진입 시 퀘스트 목록을 자동으로 접습니다.",
        true, function(val)
            if dodoDB then dodoDB.enableCollapse = val end
            if dodo.CollapseUpdateVisual then dodo.CollapseUpdateVisual() end
        end))

    local function _shown() return master:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 9010)

dodo.RegisterOption("편의기능.쐐기돌", function(category)
    dodo.UI:SettingsCheckbox(category, "enableReadyCheckTimer", "전투준비 타이머",
        "전투 준비 확인 시 ReadyCheckFrame 위에 남은 시간 바를 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableReadyCheckTimer = val end
            if dodo.ReadyCheckTimerUpdateVisual then dodo.ReadyCheckTimerUpdateVisual() end
        end)
end, 9011)
