-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: undefined-field, undefined-global
local dodo = _G.dodo

local CreateFrame         = CreateFrame
local EditMacro           = EditMacro
local GetInstanceInfo     = GetInstanceInfo
local GetMacroIndexByName = GetMacroIndexByName
local InCombatLockdown    = InCombatLockdown
local IsInInstance        = IsInInstance

local MACRO_NAME = "징"

-- 인스턴스 ID → 매크로 텍스트
-- ID 확인: /run local n,_,_,_,_,_,_,id=GetInstanceInfo() print(n,id)
local MARK_TABLE = {
    -- 루생웅
    [2521] = "/tar 섬광서리 한\n/tar 심해석 대지창조자\n/tm ~2\n/tar 섬광서리 한\n/tar 심해석 대지창조자\n/tar 원시술사 잿\n/tm ~3",

    -- 송곳니의 제단
    [2993] = "/tar 원시의 독\n/tar 고위 진화\n/tm ~2",
}

-- ==============================
-- 적용
-- ==============================
local pending = false

local function apply()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false

    if not IsInInstance() then return end

    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx == 0 then return end

    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    local text = instanceID and MARK_TABLE[instanceID]
    if not text then return end

    EditMacro(idx, MACRO_NAME, nil, text)
end

-- ==============================
-- 이벤트
-- ==============================
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then apply() end
    else
        apply()
    end
end)

dodo.Macro.ApplyMarkMacro = apply
