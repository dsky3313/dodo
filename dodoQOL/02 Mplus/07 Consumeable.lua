-- ==============================
-- Inspired
-- ==============================
-- Method Raid Tools (RaidCheck)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName = ...
local dodo = _G.dodo
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
local GetInventoryItemDurability = GetInventoryItemDurability
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

local FOOD_ITEMS = { -- 음식 아이템 (가방 수량 체크용)
    266996, 255846, -- 잔치상
    242275,         -- 왕실 구이
}

local FLASK_BUFFS = { -- 영약 버프 (Midnight)
    [1235110] = true, -- 피의 기사단 영약
    [1235108] = true, -- 마법학자의 영약
    [1235111] = true, -- 무너진 태양의 영약
    [1235057] = true, -- 탈라시안 저항 영약
    [1239355] = true, -- 사악한 탈라시안 명예 영약 (PvP)
    -- PvP 변형 (아레나/전장에서 교체됨)
    [1235113] = true, [1235114] = true, [1235115] = true, [1235116] = true,
}

local FLASK_ITEMS = { -- 영약 아이템 (가방 수량 체크용)
    241324, 241325, 245931, 245930, -- 피의 기사단 영약
    241322, 241323, 245933, 245932, -- 마법학자의 영약
    241326, 241327, 245929, 245928, -- 무너진 태양의 영약
    241320, 241321, 245926, 245927, -- 탈라시안 저항 영약
    241334,                          -- 사악한 탈라시안 명예 영약
}

local RAID_BUFF_IDS = { -- 레이드버프 (Midnight, non-secret)
    1126, 432661,   -- 자연의 표식 (드루이드)
    6673,           -- 전투 함성 (전사)
    21562,          -- 신성한 의지 (사제)
    1459, 432778,   -- 비전 지성 (마법사)
    381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758, -- 청동의 축복 (용군주)
    462854,         -- 하늘의 분노 (주술사)
}

local RUNE_BUFFS = { -- 증폭 룬 버프
    [1264426] = true, [453250]  = true, [1234969] = true,
    [1242347] = true, [393438]  = true, [347901]  = true,
}

local POTION_ITEMS = { -- 물약 아이템 (가방 수량 체크용, Midnight)
    241308, 241309, 241310, -- 빛의 잠재력
    241288,                  -- 무모함의 물약
}

local INKY_ITEM = 124640  -- 잉크빛 검은 물약
local INKY_BUFF = 185394  -- Inky Blackness (아이콘 136122)

local WEAPON_ITEMS = { -- 무기 임시 인첸트 아이템 (Midnight)
    243733, 243734, -- 탈라시안 불사조 기름
    243735, 243736, -- 새벽의 기름
    243737, 243738, -- 밀수꾼의 마법 칼날
    237367, 237369, -- 눈부신 숫돌 (둔기)
    237370, 237371, -- 눈부신 숫돌날 (날카로운)
    257749, 257750, -- 레이스된 줌샷 (원거리)
    257751, 257752, -- 무게달린 붐샷 (원거리)
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
main_frame:SetSize(360, 40)
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
    statusFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 6)
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
local FLASK_MACRO = "/run print('|cffffd200[dodo]|r 영약 클릭됨')\n/use item:241324\n/use item:241325\n/use item:241322\n/use item:241323\n/use item:241326\n/use item:241327\n/use item:241320\n/use item:241321\n/use item:241334\n/use item:245931\n/use item:245930\n/use item:245933\n/use item:245932\n/use item:245929\n/use item:245928\n/use item:245926\n/use item:245927"
local RUNE_MACRO = "/run print('|cffffd200[dodo]|r 룬 클릭됨')\n/use item:259085\n/use item:243191"
local HS_MACRO = "/run print('|cffffd200[dodo]|r 생석 클릭됨')\n/use item:5512\n/use 생명석"
local WEAPON_MACRO = "/run print('|cffffd200[dodo]|r 무기 도핑 클릭됨')\n/use item:243733\n/use 16\n/use item:243734\n/use 16\n/use item:243735\n/use 16\n/use item:243736\n/use 16\n/use item:243737\n/use 16\n/use item:243738\n/use 16"

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
---@field durability ReadyCheckIconFrame 내구도 아이콘 프레임
---@field inky ReadyCheckIconFrame 잉크빛 검은 물약 아이콘 프레임
---@field raidbuff ReadyCheckIconFrame 레이드버프 아이콘 프레임

---@type ReadyCheckIcons
local icons = {}
icons.food = create_icon("Food", 136000, 1, "item", 242275, FOOD_MACRO)
icons.flask = create_icon("Flask", 7548903, 2, "item", 241327, FLASK_MACRO)
icons.weapon = create_icon("Weapon", 7548987, 3, "item", 243734, WEAPON_MACRO)
icons.rune = create_icon("Rune", 3566863, 4, "spell", 393438, RUNE_MACRO)
icons.potion = create_icon("Potion", 7548911, 5, "item", 241308, nil)
icons.hs = create_icon("Healthstone", 135230, 6, "item", 5512, HS_MACRO)
icons.durability = create_icon("Durability", 136241, 7, nil, nil, nil)
icons.inky = create_icon("Inky", 134757, 8, "item", INKY_ITEM, "/use item:"..INKY_ITEM)
icons.raidbuff = create_icon("RaidBuff", 135987, 9, "spell", 21562, nil)
do
    local cdFont
    for _, r in ipairs({icons.durability.cooldown:GetRegions()}) do
        if r:GetObjectType() == "FontString" then
            cdFont = (select(1, r:GetFont()))
            break
        end
    end
    icons.durability.text:ClearAllPoints()
    icons.durability.text:SetPoint("CENTER", icons.durability, "CENTER", 0, 0)
    icons.durability.text:SetFont(cdFont or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    icons.durability.text:SetTextColor(1, 1, 1)
end
icons.durability:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("내구도", 1, 1, 1)
    if self.duraPct then
        local r = self.duraPct < 20 and 1 or 0.1
        local g = self.duraPct < 20 and 0.2 or 1
        GameTooltip:AddLine(self.duraPct .. "%", r, g, 0.1)
    end
    GameTooltip:Show()
end)

-- ==============================
-- 아이템 선택 드롭다운
-- ==============================
local LAST_USED_KEYS = {
    flask  = "lastUsedFlask",
    food   = "lastUsedFood",
    potion = "lastUsedPotion",
    weapon = "lastUsedWeapon",
}

-- lastUsed가 가방에 있으면 우선, 없으면 목록에서 첫 번째 보유 아이템
local function get_display_item(dbKey, items)
    local lastUsed = dbKey and dodoDB and dodoDB[dbKey]
    if lastUsed then
        for _, id in ipairs(items) do
            if id == lastUsed and GetItemCount(id, false, true) > 0 then
                return id
            end
        end
    end
    for _, id in ipairs(items) do
        if GetItemCount(id, false, true) > 0 then return id end
    end
    return items[1]
end

-- 가방 아이템 링크에서 제작 품질 아틀라스 문자열 반환 (Blizzard ItemButtonTemplate 방식)
local function get_quality_atlas_from_bag(itemID)
    if not C_TradeSkillUI then return nil end
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local slotInfo = C_Container.GetContainerItemInfo(bag, slot)
            if slotInfo and slotInfo.itemID == itemID and slotInfo.hyperlink then
                local qi = (C_TradeSkillUI.GetItemReagentQualityInfo and C_TradeSkillUI.GetItemReagentQualityInfo(slotInfo.hyperlink))
                        or (C_TradeSkillUI.GetItemCraftedQualityInfo  and C_TradeSkillUI.GetItemCraftedQualityInfo(slotInfo.hyperlink))
                if qi and qi.iconInventory then return qi.iconInventory end
            end
        end
    end
    return nil
end

local function update_icon_item(iconFrame, itemID)
    if not iconFrame or not itemID then return end
    local tex = GetItemIcon(itemID)
    if tex then iconFrame.icon:SetTexture(tex) end
    iconFrame.tooltipId   = itemID
    iconFrame.tooltipType = "item"
    -- 제작 품질 ★ 아틀라스
    local qualityAtlas = get_quality_atlas_from_bag(itemID)
    if not iconFrame._qualityOv then
        local ov = iconFrame.overlayLayer:CreateTexture(nil, "OVERLAY", nil, 7)
        ov:SetPoint("TOPLEFT", iconFrame.overlayLayer, "TOPLEFT", -3, 2)
        iconFrame._qualityOv = ov
    end
    if qualityAtlas then
        iconFrame._qualityOv:SetAtlas(qualityAtlas, true)
        iconFrame._qualityOv:Show()
    else
        iconFrame._qualityOv:Hide()
    end
end

local dd_frame, dd_catch
local dd_buttons = {}

local function hide_dropdown()
    if dd_frame  then dd_frame:Hide()  end
    if dd_catch  then dd_catch:Hide()  end
end

local DD_SZ, DD_GAP = 36, 3

local function show_dropdown(anchor, category, items, slot)
    local avail = {}
    for _, id in ipairs(items) do
        local c = GetItemCount(id, false, true)
        if c > 0 then avail[#avail+1] = {id=id, count=c} end
    end
    if #avail == 0 then return end

    -- 지연 생성: 클릭-캐처 (드롭다운 바깥 클릭 시 닫기)
    if not dd_catch then
        dd_catch = CreateFrame("Frame", nil, UIParent)
        dd_catch:SetFrameStrata("MEDIUM")
        dd_catch:SetFrameLevel(800)
        dd_catch:SetAllPoints(UIParent)
        dd_catch:EnableMouse(true)
        dd_catch:SetScript("OnMouseDown", hide_dropdown)
        dd_catch:Hide()
    end
    -- 지연 생성: 드롭다운 컨테이너 프레임
    if not dd_frame then
        dd_frame = CreateFrame("Frame", "dodoConsumeDropdown", UIParent)
        dd_frame:SetFrameStrata("HIGH")
        dd_frame:SetFrameLevel(100)
    end

    for _, btn in ipairs(dd_buttons) do btn:Hide() end

    local n = #avail
    dd_frame:SetSize(n * (DD_SZ + DD_GAP) + DD_GAP, DD_SZ + DD_GAP * 2)

    for i, info in ipairs(avail) do
        local btn = dd_buttons[i]
        if not btn then
            btn = LibIcon:Create("dodoDD_"..i, dd_frame, {
                isAction = true,
                iconsize = {DD_SZ, DD_SZ}
            })
            btn:HookScript("PostClick", function(self)
                if dodoDB and self._dbKey then dodoDB[self._dbKey] = self._itemID end
                hide_dropdown()
            end)
            dd_buttons[i] = btn
        end
        btn._dbKey  = LAST_USED_KEYS[category]
        btn._itemID = info.id
        btn:ApplyConfig({
            type        = "item",
            id          = info.id,
            isAction    = true,
            useTooltip  = true,
            framestrata = "HIGH",
            label       = "",
        })
        -- 무기 인첸트: 슬롯 지정 매크로로 덮어쓰기
        if slot then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/use item:"..info.id.."\n/use "..slot)
        end
        -- 제작 품질 아틀라스
        local qualityAtlas = get_quality_atlas_from_bag(info.id)
        if not btn._qualityOv then
            local ov = btn.overlayLayer:CreateTexture(nil, "OVERLAY", nil, 7)
            ov:SetPoint("TOPLEFT", btn.overlayLayer, "TOPLEFT", -3, 2)
            btn._qualityOv = ov
        end
        if qualityAtlas then
            btn._qualityOv:SetAtlas(qualityAtlas, true)
            btn._qualityOv:Show()
        else
            btn._qualityOv:Hide()
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", dd_frame, "TOPLEFT", DD_GAP + (i-1)*(DD_SZ+DD_GAP), -DD_GAP)
        btn:Show()
    end

    dd_frame:ClearAllPoints()
    dd_frame:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    dd_frame:Show()
    dd_catch:Show()
end

local function add_dropdown_arrow(iconFrame, category, items, slot)
    local arrow = CreateFrame("Button", nil, iconFrame)
    arrow:SetPoint("BOTTOM", iconFrame, "BOTTOM", 0, -16)
    arrow:SetFrameLevel(200)
    local tex = arrow:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas("minimal-scrollbar-arrow-bottom-over", true)
    tex:SetAllPoints()
    arrow:SetSize(tex:GetWidth() * 1.2, tex:GetHeight() * 1.2)
    local hl = arrow:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAtlas("minimal-scrollbar-arrow-bottom-over", true)
    hl:SetAllPoints()
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.6)
    arrow:SetScript("OnClick", function()
        if dd_frame and dd_frame:IsShown() then hide_dropdown()
        else show_dropdown(arrow, category, items, slot) end
    end)
end

add_dropdown_arrow(icons.flask,  "flask",  FLASK_ITEMS)
add_dropdown_arrow(icons.food,   "food",   FOOD_ITEMS)
add_dropdown_arrow(icons.potion, "potion", POTION_ITEMS)
add_dropdown_arrow(icons.weapon, "weapon", WEAPON_ITEMS, 16)

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
    if main_frame.is_visible then
        PlaySoundFile("Interface\\AddOns\\dodo\\Media\\Sound\\Repair.ogg", "Master")
    end
    main_frame.is_visible = false
    for _, icon in pairs(icons) do
        icon:EnableMouse(false)
    end
end

local function set_status(iconFrame, active)
    iconFrame.icon:SetDesaturated(not active)
    iconFrame.status:SetTexture(active and READY_ICON or NOT_READY_ICON)
end

function update_consumables()
    if not main_frame.is_visible then return end

    throttle("ReadyCheckUpdate", function()
        local now = GetTime()
        local hasFood, hasFlask, hasRune = false, false, false
        local foodDuration, foodExpiration = 0, 0
        local flaskDuration, flaskExpiration, flaskIcon = 0, 0, nil
        local runeDuration, runeExpiration = 0, 0

        -- 영약: GetPlayerAuraBySpellID 직접 조회 (화이트리스트 ID, secret-safe)
        for id in pairs(FLASK_BUFFS) do
            local data = C_UnitAuras.GetPlayerAuraBySpellID(id)
            if data then
                hasFlask = true
                local ic = data.icon
                flaskIcon = (ic and not issecretvalue(ic)) and ic or nil
                flaskDuration = data.duration
                flaskExpiration = data.expirationTime
                break
            end
        end

        -- 룬: GetPlayerAuraBySpellID 직접 조회
        for id in pairs(RUNE_BUFFS) do
            local data = C_UnitAuras.GetPlayerAuraBySpellID(id)
            if data then
                hasRune = true
                runeDuration = data.duration
                runeExpiration = data.expirationTime
                break
            end
        end

        -- 음식: 아이콘 136000(Well Fed) 스캔 (spell ID 없음)
        for i = 1, 40 do
            local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not data then break end
            local ic = data.icon
            if ic and not issecretvalue(ic) and ic == 136000 then
                hasFood = true
                foodDuration = data.duration
                foodExpiration = data.expirationTime
                break
            end
        end

        local foodCount = 0
        for i = 1, #FOOD_ITEMS do
            foodCount = foodCount + GetItemCount(FOOD_ITEMS[i], false, true)
        end

        local flaskCount = 0
        for i = 1, #FLASK_ITEMS do
            flaskCount = flaskCount + GetItemCount(FLASK_ITEMS[i], false, true)
        end

        local potionCount = 0
        for i = 1, #POTION_ITEMS do
            potionCount = potionCount + GetItemCount(POTION_ITEMS[i], false, true)
        end

        local hsCount = GetItemCount(5512, false, true)
        local hasHS = (hsCount > 0)

        -- 표시 아이콘 갱신: lastUsed 우선, 없으면 가방 첫 번째
        -- (영약은 버프 활성 시 아래 섹션에서 flaskIcon으로 덮어씀)
        do
            local fid = get_display_item(LAST_USED_KEYS.flask,  FLASK_ITEMS)
            if fid then update_icon_item(icons.flask,  fid) end
            local fd  = get_display_item(LAST_USED_KEYS.food,   FOOD_ITEMS)
            if fd  then update_icon_item(icons.food,   fd)  end
            local pid = get_display_item(LAST_USED_KEYS.potion, POTION_ITEMS)
            if pid then update_icon_item(icons.potion, pid) end
            local wid = get_display_item(LAST_USED_KEYS.weapon, WEAPON_ITEMS)
            if wid then update_icon_item(icons.weapon, wid) end
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
            icons.flask.Count:SetText(flaskCount > 0 and flaskCount or "")
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
        -- 7. 잉크빛 검은 물약
        local hasInky = false
        local inkyCount = GetItemCount(INKY_ITEM, false, true)
        for i = 1, 40 do
            local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not data then break end
            local sid = data.spellId
            local ic  = data.icon
            if (sid and not issecretvalue(sid) and sid == INKY_BUFF)
            or (ic  and not issecretvalue(ic)  and ic  == 136122) then
                hasInky = true; break
            end
        end
        set_status(icons.inky, hasInky)
        icons.inky.cooldown:Clear()
        icons.inky.Count:SetText(inkyCount > 0 and inkyCount or "")
        icons.inky.text:SetText("")

        -- 8. 내구도
        local durabilitySlots = {1, 3, 5, 6, 7, 8, 9, 10, 16, 17}
        local totalCur, totalMax = 0, 0
        for _, slot in ipairs(durabilitySlots) do
            local cur, max = GetInventoryItemDurability(slot)
            if cur and max and max > 0 then
                totalCur = totalCur + cur
                totalMax = totalMax + max
            end
        end
        local duraPct = totalMax > 0 and math.floor(totalCur / totalMax * 100) or 100
        icons.durability.duraPct = duraPct
        set_status(icons.durability, duraPct >= 20)
        icons.durability.cooldown:Clear()
        icons.durability.Count:SetText("")
        icons.durability.text:SetText(duraPct .. "%")

        -- 9. 레이드버프
        local hasRaidBuff = false
        for _, id in ipairs(RAID_BUFF_IDS) do
            local data = C_UnitAuras.GetPlayerAuraBySpellID(id)
            if data then
                hasRaidBuff = true
                local ic = data.icon
                if ic and not issecretvalue(ic) then icons.raidbuff.icon:SetTexture(ic) end
                icons.raidbuff.tooltipId = id
                break
            end
        end
        set_status(icons.raidbuff, hasRaidBuff)
        icons.raidbuff.cooldown:Clear()
        icons.raidbuff.Count:SetText("")
        icons.raidbuff.text:SetText("")
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
        hide_dropdown()
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
