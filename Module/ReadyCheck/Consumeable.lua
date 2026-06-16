-- ==============================
-- Inspired
-- ==============================
-- Method Raid Tools (RaidCheck)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱 및 상수
-- ==============================
local C_Spell = C_Spell
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local GetItemCount = GetItemCount
local GetTime = GetTime
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local InCombatLockdown = InCombatLockdown
local ReadyCheckFrame = ReadyCheckFrame
local UIParent = UIParent
local LibIcon = dodo.LibIcon

-- 포워드 선언
local update_consumables

-- 아이콘 텍스처
local READY_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local NOT_READY_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- 도핑 데이터 (주문)
local FOOD_BUFFS = {
    [1294727] = true, -- 왕실 구이
    [136000] = true,
}

local FLASK_BUFFS = {
    [1235111] = true, -- 무너진 태양의 영약 (치명)
}

local RUNE_BUFFS = {
    [1234969] = true, -- 내부전쟁 평판룬
    [393438] = true,
}

-- 도핑 데이터 (아이템)
local FOOD_ITEMS = {
    242275, -- 왕실 구이
}

local POTION_ITEMS = {
    241308, 241309, 241310, 212239, 212240, 212241,
}

local WEAPON_ITEMS = {
    243734, -- 탈라시안 불사조 기름 (2성)
}

-- 샤먼 무기 인첸트 주문 (enchant ID -> 주문ID) — 활성 시 해당 주문 아이콘/툴팁으로 표시
local SHAMAN_IMBUE_ENCHANTS = {
    [5400] = 318038, -- 화염전염 무기
    [5401] = 33757,  -- 질풍 무기
    [6498] = 382021, -- 대지생명 무기
    [7528] = 457496, -- 해류군주의 수호
    [7587] = 462757, -- 천둥벼락 부적
}


-- ==============================
-- 프레임 생성
-- ==============================
local main_frame = CreateFrame("Frame", "dodoReadyCheckFrame", UIParent, "SecureHandlerStateTemplate")
main_frame:SetSize(280, 40)
main_frame:SetPoint("BOTTOM", ReadyCheckFrame, "TOP", 0, 15)
main_frame:SetFrameStrata("DIALOG")
main_frame:SetFrameLevel(100)
main_frame:Hide()
main_frame.is_visible = false

-- 전투 돌입 시 보안 환경에서 물리적으로 프레임을 즉각 숨기도록 보안 상태 드라이버 등록
RegisterStateDriver(main_frame, "combatstate", "[combat] combat; normal")
main_frame:SetAttribute("_onstate-combatstate", [=[
    if newstate == "combat" then
        self:Hide()
    end
]=])

---준비 체크 도핑 확인용 보안 아이콘 버튼을 생성합니다.
---@param name string 아이콘 고유 이름
---@param texture number|string 대표 아이콘 텍스처 ID 또는 경로
---@param index number 배치 순서 인덱스 (1부터 시작)
---@param tooltipType "spell"|"item" 마우스오버 툴팁 유형
---@param tooltipId number 툴팁에 표시할 주문 또는 아이템 ID
---@param macrotext string|nil 클릭 시 실행할 보안 매크로 텍스트
---@return ReadyCheckIconFrame # 생성된 아이콘 프레임 객체
local function create_icon(name, texture, index, tooltipType, tooltipId, macrotext)
    local hasMacro = (macrotext ~= nil)
    local f = LibIcon:Create("dodoReadyCheckIcon_" .. name, main_frame, {
        isAction = hasMacro,
        iconsize = {40, 40}
    })
    f:SetPoint("LEFT", (index - 1) * 40, 0)

    f.icon:SetTexture(texture)
    f.icon:SetDesaturated(true)

    f:ApplyConfig({
        type = hasMacro and "macro" or tooltipType,
        id = tooltipId,
        macrotext = macrotext,
        isAction = hasMacro,
        useTooltip = true,
        icon = texture,
        cooldownSize = 12
    })

    -- V X 상태 마크를 위한 프레임 레벨이 높은 자식 프레임 생성 (테두리 위 렌더링 보장)
    local statusFrame = CreateFrame("Frame", nil, f)
    statusFrame:SetSize(20, 20)
    statusFrame:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 6)
    statusFrame:SetFrameLevel(f:GetFrameLevel() + 2)

    f.status = statusFrame:CreateTexture(nil, "OVERLAY")
    f.status:SetAllPoints(statusFrame)
    f.status:SetTexture(NOT_READY_ICON)

    f.text = f.Name
    f.text:SetFontObject("NumberFontNormalSmall")
    f.text:ClearAllPoints()
    f.text:SetPoint("BOTTOM", f, "BOTTOM", 0, -10)

    f.tooltipType = tooltipType
    f.tooltipId = tooltipId

    -- 툴팁 수동 재정의 (매크로 문구 대신 원래 주문/아이템 툴팁 표시)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.tooltipType == "spell" then
            GameTooltip:SetSpellByID(self.tooltipId)
        elseif self.tooltipType == "item" then
            GameTooltip:SetItemByID(self.tooltipId)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 스와이프(원형 음영) 끄고 카운트다운 숫자만 표시
    f.cooldown:SetDrawSwipe(false)

    return f
end

local FOOD_MACRO = "/run print('|cffffd200[dodo]|r 음식 클릭됨')\n/use 밤의 가면 대연회\n/use 푸짐한 밤의 가면 대연회\n/use Feast of the Midnight Masquerade\n/use Hearty Feast of the Midnight Masquerade\n/use 왕실 구이"
local FLASK_MACRO = "/run print('|cffffd200[dodo]|r 영약 클릭됨')\n/use item:212265\n/use item:212266\n/use item:212284\n/use item:212285\n/use item:212283\n/use item:212282\n/use item:224424\n/use item:224403\n/use item:224401\n/use item:224400\n/use item:224399\n/use item:224402"
local RUNE_MACRO = "/run print('|cffffd200[dodo]|r 룬 클릭됨')\n/use item:224020\n/use item:224522\n/use item:211228\n/use item:243191"
local HS_MACRO = "/run print('|cffffd200[dodo]|r 생석 클릭됨')\n/use item:5512\n/use 생명석"
local WEAPON_MACRO = "/run print('|cffffd200[dodo]|r 무기 도핑 클릭됨')\n/use item:224017\n/use 16\n/use item:224018\n/use 16"

---@class ReadyCheckIconFrame: Button
---@field status Texture
---@field text FontString
---@field cooldown Cooldown
---@field icon Texture
---@field Count FontString

---@class ReadyCheckIcons
---@field food ReadyCheckIconFrame 음식 아이콘 프레임
---@field flask ReadyCheckIconFrame 영약 아이콘 프레임
---@field potion ReadyCheckIconFrame 물약 아이콘 프레임
---@field rune ReadyCheckIconFrame 룬 아이콘 프레임
---@field hs ReadyCheckIconFrame 생석 아이콘 프레임
---@field weapon ReadyCheckIconFrame 무기 도핑 아이콘 프레임

---@type ReadyCheckIcons
local icons = {}
icons.food = create_icon("Food", 136000, 1, "item", 242275, FOOD_MACRO)
icons.flask = create_icon("Flask", 7548903, 2, "item", 241327, FLASK_MACRO)
icons.weapon = create_icon("Weapon", 7548987, 3, "item", 243734, WEAPON_MACRO)
icons.rune = create_icon("Rune", 3566863, 4, "spell", 393438, RUNE_MACRO)
icons.potion = create_icon("Potion", 7548911, 5, "item", 241308, nil)
icons.hs = create_icon("Healthstone", 135230, 6, "item", 5512, HS_MACRO)

-- ==============================
-- 헬퍼 함수 (Throttle & Debounce)
-- ==============================
local throttles = {}
local function throttle(key, func, duration)
    local now = GetTime()
    if not throttles[key] or (now - throttles[key] >= duration) then
        throttles[key] = now
        func()
    end
end

local debounces = {}
local function debounce(key, func, duration)
    if debounces[key] then
        debounces[key]:Cancel()
    end
    debounces[key] = C_Timer.NewTimer(duration, func)
end

-- ==============================
-- 기능: 도핑 체크
-- ==============================
local function show_frame()
    if not InCombatLockdown() then
        main_frame:Show()
    end
    main_frame.is_visible = true
    for _, icon in pairs(icons) do
        icon:EnableMouse(true)
    end
    update_consumables()
end

local function hide_frame()
    if not InCombatLockdown() then
        main_frame:Hide()
    end
    main_frame.is_visible = false
    for _, icon in pairs(icons) do
        icon:EnableMouse(false)
    end
end

function update_consumables()
    if not main_frame.is_visible then return end

    throttle("ReadyCheckUpdate", function()
        local now = GetTime()
        local hasFood, hasFlask, hasRune = false, false, false
        local foodDuration, foodExpiration = 0, 0
        local flaskDuration, flaskExpiration, flaskIcon = 0, 0, nil
        local runeDuration, runeExpiration = 0, 0

        for i = 1, 40 do
            local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not data then break end

            if FOOD_BUFFS[data.spellId] or data.icon == 136000 then
                hasFood = true
                foodDuration = data.duration
                foodExpiration = data.expirationTime
            elseif FLASK_BUFFS[data.spellId] then
                hasFlask = true
                flaskIcon = data.icon
                flaskDuration = data.duration
                flaskExpiration = data.expirationTime
            elseif RUNE_BUFFS[data.spellId] then
                hasRune = true
                runeDuration = data.duration
                runeExpiration = data.expirationTime
            end
        end

        local foodCount = 0
        for i = 1, #FOOD_ITEMS do
            foodCount = foodCount + GetItemCount(FOOD_ITEMS[i], false, true)
        end

        local potionCount = 0
        for i = 1, #POTION_ITEMS do
            potionCount = potionCount + GetItemCount(POTION_ITEMS[i], false, true)
        end

        local hsCount = GetItemCount(5512, false, true)
        local hasHS = (hsCount > 0)

        local function set_status(iconFrame, active)
            iconFrame.icon:SetDesaturated(not active)
            iconFrame.status:SetTexture(active and READY_ICON or NOT_READY_ICON)
        end

        -- 1. 음식
        set_status(icons.food, hasFood)
        if hasFood then
            icons.food.cooldown:SetCooldown(foodExpiration - foodDuration, foodDuration)
            icons.food.Count:SetText("")
            icons.food.text:SetText("")
        else
            icons.food.cooldown:Clear()
            icons.food.Count:SetText(foodCount > 0 and foodCount or "")
            icons.food.text:SetText("")
        end

        -- 2. 영약
        set_status(icons.flask, hasFlask)
        if hasFlask then
            if flaskIcon then icons.flask.icon:SetTexture(flaskIcon) end
            icons.flask.cooldown:SetCooldown(flaskExpiration - flaskDuration, flaskDuration)
            icons.flask.Count:SetText("")
            icons.flask.text:SetText("")
        else
            icons.flask.cooldown:Clear()
            icons.flask.Count:SetText("")
            icons.flask.text:SetText("")
        end

        -- 3. 룬
        set_status(icons.rune, hasRune)
        if hasRune then
            icons.rune.cooldown:SetCooldown(runeExpiration - runeDuration, runeDuration)
            icons.rune.Count:SetText("")
            icons.rune.text:SetText("")
        else
            icons.rune.cooldown:Clear()
            icons.rune.Count:SetText("")
            icons.rune.text:SetText("")
        end

        -- 4. 생석
        set_status(icons.hs, hasHS)
        icons.hs.cooldown:Clear()
        icons.hs.Count:SetText(hasHS and hsCount or "")
        icons.hs.text:SetText("")

        -- 5. 물약 (버프 체크 없이 가방 내 소지 개수만으로 판단)
        local hasPotion = (potionCount > 0)
        set_status(icons.potion, hasPotion)
        icons.potion.cooldown:Clear()
        icons.potion.Count:SetText(potionCount)
        icons.potion.text:SetText("")

        -- 6. 무기 도핑
        local hasMainHandEnchant, mainHandExpiration, _, mainHandEnchID = GetWeaponEnchantInfo()
        local hasWeapon = not not hasMainHandEnchant

        local weaponCount = 0
        for i = 1, #WEAPON_ITEMS do
            weaponCount = weaponCount + GetItemCount(WEAPON_ITEMS[i], false, true)
        end

        -- 샤먼 무기 인첸트 주문이 걸려있으면 해당 주문 아이콘/툴팁으로, 아니면 기본 오일로 표시
        local imbueSpell = hasWeapon and SHAMAN_IMBUE_ENCHANTS[mainHandEnchID]
        if imbueSpell then
            icons.weapon.icon:SetTexture(C_Spell.GetSpellTexture(imbueSpell))
            icons.weapon.tooltipType = "spell"
            icons.weapon.tooltipId = imbueSpell
        else
            icons.weapon.icon:SetTexture(7548987) -- 탈라시안 불사조 기름
            icons.weapon.tooltipType = "item"
            icons.weapon.tooltipId = 243734
        end

        set_status(icons.weapon, hasWeapon)
        if hasWeapon then
            icons.weapon.cooldown:SetCooldown(GetTime(), (mainHandExpiration or 0) / 1000)
            icons.weapon.Count:SetText("")
            icons.weapon.text:SetText("")
        else
            icons.weapon.cooldown:Clear()
            icons.weapon.Count:SetText(weaponCount > 0 and weaponCount or "")
            icons.weapon.text:SetText("")
        end
    end, 0.2)
end

-- ==============================
-- 테스트 기능
-- ==============================
local function test_ready_check()
    if main_frame.is_visible then
        if debounces["ReadyCheckHide"] then
            debounces["ReadyCheckHide"]:Cancel()
        end
        hide_frame()
        main_frame:UnregisterEvent("READY_CHECK_FINISHED")
        main_frame:UnregisterEvent("UNIT_AURA")
        main_frame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        main_frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
        
        if ReadyCheckFrame then ReadyCheckFrame:Hide() end
        print("|cffffd200[dodo]|r ReadyCheck 테스트 모드 종료")
    else
        if ReadyCheckFrame_Start then
            ReadyCheckFrame_Start(UnitName("player") or "player", 35)
        elseif ReadyCheckFrame then
            ReadyCheckFrame:Show()
            ReadyCheckFrameText:SetText("dodo ReadyCheck 테스트 중...")
        end

        -- 테스트 시작 시 실시간 추적 이벤트 동적 등록
        main_frame:RegisterEvent("READY_CHECK_FINISHED")
        main_frame:RegisterEvent("UNIT_AURA")
        main_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")

        show_frame()
        
        debounce("ReadyCheckHide", function()
            hide_frame()
            main_frame:UnregisterEvent("READY_CHECK_FINISHED")
            main_frame:UnregisterEvent("UNIT_AURA")
            main_frame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
            main_frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
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
    test_ready_check()
end

-- ==============================
-- 모듈 On/Off 제어
-- ==============================
local function update_module_state()
    local enabled = (dodoDB and dodoDB.enableReadyCheck ~= false)
    
    hide_frame()
    main_frame:UnregisterAllEvents()
    
    if enabled then
        -- 평소에는 오직 READY_CHECK 시작 이벤트만 대기
        main_frame:RegisterEvent("READY_CHECK")
    end
end

dodo.UpdateReadyCheckModuleState = update_module_state

-- ==============================
-- 이벤트 핸들러
-- ==============================
main_frame:SetScript("OnEvent", function(self, event, ...)
    if event == "READY_CHECK" then
        -- 전투준비 시작 시점에 실시간 추적에 필요한 이벤트들 동적 등록
        self:RegisterEvent("READY_CHECK_FINISHED")
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("UNIT_INVENTORY_CHANGED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        
        show_frame()
        
        debounce("ReadyCheckHide", function()
            hide_frame()
            self:UnregisterEvent("READY_CHECK_FINISHED")
            self:UnregisterEvent("UNIT_AURA")
            self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
            self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        end, 35)
    elseif event == "READY_CHECK_FINISHED" then
        debounce("ReadyCheckHide", function()
            hide_frame()
            self:UnregisterEvent("READY_CHECK_FINISHED")
            self:UnregisterEvent("UNIT_AURA")
            self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
            self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        end, 2)
    elseif event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
        update_consumables()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if debounces["ReadyCheckHide"] then
            debounces["ReadyCheckHide"]:Cancel()
        end
        hide_frame()
        self:UnregisterEvent("READY_CHECK_FINISHED")
        self:UnregisterEvent("UNIT_AURA")
        self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "준비 체크 도핑 확인 활성화",
            get = function() return dodoDB and dodoDB.enableReadyCheck ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableReadyCheck = checked end
                update_module_state()
            end
        }
    })
end

-- ==============================
-- 초기화 프레임
-- ==============================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        if dodoDB.enableReadyCheck == nil then dodoDB.enableReadyCheck = true end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        update_module_state()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
