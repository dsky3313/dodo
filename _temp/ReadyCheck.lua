-- ==============================
-- Inspired
-- ==============================
-- Method Raid Tools (RaidCheck)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("ReadyCheck", module)

-- ==============================
-- 캐싱 및 상수
-- ==============================
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local GetItemCount = GetItemCount
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local ReadyCheckFrame = ReadyCheckFrame
local UIParent = UIParent

-- 아이콘 텍스처
local READY_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local NOT_READY_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- 도핑 데이터 (주문 ID)
local FOOD_BUFFS = {
    [185736] = true, [257413] = true, [257418] = true, [257408] = true, [257422] = true,
    [259449] = true, [259452] = true, [259448] = true, [259453] = true, [288074] = true,
    [136000] = true,
}

local FLASK_BUFFS = {
    [1236763] = true, [1239355] = true, [1235057] = true, [1239755] = true,
    [1236767] = true, [1235111] = true, [1235110] = true, [1235108] = true,
}

local RUNE_BUFFS = {
    [192106] = true,
    [393438] = true,
}

-- ==============================
-- 프레임 생성 (MRT 위치: ReadyCheckFrame 상단)
-- ==============================
local main_frame = CreateFrame("Frame", "dodoReadyCheckFrame", ReadyCheckFrame or UIParent)
main_frame:SetSize(160, 40)
main_frame:SetPoint("BOTTOM", ReadyCheckFrame, "TOP", 0, 5)
main_frame:Hide()

-- 디버그용 배경
main_frame.bg = main_frame:CreateTexture(nil, "BACKGROUND")
main_frame.bg:SetAllPoints()
main_frame.bg:SetColorTexture(0, 0, 0, 0.5)
main_frame.bg:Hide()

local function create_icon(name, texture, index)
    local f = CreateFrame("Frame", nil, main_frame)
    f:SetSize(32, 32)
    f:SetPoint("LEFT", (index - 1) * 40, 0)

    f.icon = f:CreateTexture(nil, "BACKGROUND")
    f.icon:SetAllPoints()
    f.icon:SetTexture(texture)
    f.icon:SetDesaturated(true)

    f.status = f:CreateTexture(nil, "OVERLAY")
    f.status:SetSize(16, 16)
    f.status:SetPoint("BOTTOMRIGHT", 2, -2)
    f.status:SetTexture(NOT_READY_ICON)

    f.text = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    f.text:SetPoint("BOTTOM", 0, -10)

    return f
end

local icons = {}
icons.food = create_icon("Food", 136000, 1)
icons.flask = create_icon("Flask", 136243, 2)
icons.rune = create_icon("Rune", 134430, 3)
icons.hs = create_icon("Healthstone", 135230, 4)

-- ==============================
-- 기능: 도핑 체크
-- ==============================
local function update_consumables()
    if not main_frame:IsShown() then return end

    dodo.Throttle("ReadyCheckUpdate", function()
        local now = GetTime()
        local hasFood, hasFlask, hasRune = false, false, false

        for i = 1, 40 do
            local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not data then break end

            if FOOD_BUFFS[data.spellId] or data.icon == 136000 then
                hasFood = true
                icons.food.text:SetText(math.ceil((data.expirationTime - now) / 60) .. "m")
            elseif FLASK_BUFFS[data.spellId] then
                hasFlask = true
                icons.flask.icon:SetTexture(data.icon)
                icons.flask.text:SetText(math.ceil((data.expirationTime - now) / 60) .. "m")
            elseif RUNE_BUFFS[data.spellId] then
                hasRune = true
                icons.rune.text:SetText(math.ceil((data.expirationTime - now) / 60) .. "m")
            end
        end

        local hsCount = GetItemCount(5512, false, true)
        local hasHS = (hsCount > 0)

        local function set_status(iconFrame, active)
            iconFrame.icon:SetDesaturated(not active)
            iconFrame.status:SetTexture(active and READY_ICON or NOT_READY_ICON)
            if not active then iconFrame.text:SetText("") end
        end

        set_status(icons.food, hasFood)
        set_status(icons.flask, hasFlask)
        set_status(icons.rune, hasRune)
        set_status(icons.hs, hasHS)
        icons.hs.text:SetText(hasHS and hsCount or "")
    end, 0.2)
end

-- ==============================
-- 테스트 기능
-- ==============================
function module:Test()
    if main_frame:IsShown() then
        main_frame:Hide()
        main_frame.bg:Hide()
        if ReadyCheckFrame then ReadyCheckFrame:Hide() end
        print("|cffffd200[dodo]|r ReadyCheck 테스트 모드 종료")
    else
        -- 실제 준비 체크 창과 함께 표시하여 위치 확인 가능하게 함
        if ReadyCheckFrame then
            ReadyCheckFrame:Show()
            ReadyCheckFrameText:SetText("dodo ReadyCheck 테스트 중...")
        end

        main_frame:Show()
        main_frame.bg:Show()
        update_consumables()
        
        -- 실제 상황과 동일하게 35초 후 자동 숨김 타이머 작동
        dodo.Debounce("ReadyCheckHide", function()
            main_frame:Hide()
            main_frame.bg:Hide()
            if ReadyCheckFrame then ReadyCheckFrame:Hide() end
        end, 35)

        print("|cffffd200[dodo]|r ReadyCheck 테스트 모드 시작 (35초 후 자동 종료)")
    end
end

-- ==============================
-- 명령어 등록
-- ==============================
SLASH_DODORC1 = "/111"
SlashCmdList["DODORC"] = function()
    module:Test()
end

-- ==============================
-- 모듈 On/Off 제어
-- ==============================
local function update_module_state()
    local enabled = (dodo.DB and dodo.DB.enableReadyCheckModule ~= false)
    
    if not enabled then
        main_frame:Hide()
        main_frame:UnregisterAllEvents()
    else
        main_frame:RegisterEvent("READY_CHECK")
        main_frame:RegisterEvent("READY_CHECK_FINISHED")
        main_frame:RegisterEvent("UNIT_AURA")
        main_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    end
end

dodo.UpdateReadyCheckModuleState = update_module_state

-- ==============================
-- 이벤트 핸들러
-- ==============================
main_frame:SetScript("OnEvent", function(self, event, ...)
    if event == "READY_CHECK" then
        self:Show()
        update_consumables()
        
        dodo.Debounce("ReadyCheckHide", function()
            self:Hide()
        end, 35)
    elseif event == "READY_CHECK_FINISHED" then
        dodo.Debounce("ReadyCheckHide", function()
            self:Hide()
        end, 2)
    elseif event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
        update_consumables()
    end
end)

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    update_module_state()

    if isInitialized then return end
    isInitialized = true
end
