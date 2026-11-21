-- ==============================
-- Inspired
-- ==============================
-- Method Raid Tools (https://www.curseforge.com/wow/addons/method-raid-tools)

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
local GetItemCount = C_Item.GetItemCount
local GetTime = GetTime
local GetInventoryItemDurability = GetInventoryItemDurability
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local InCombatLockdown = InCombatLockdown
local ReadyCheckFrame = ReadyCheckFrame
local UIParent = UIParent
local LibIcon = dodo.LibIcon

-- 포워드 선언
local update_consumables

-- 디버그 (/111 테스트 모드 중에만 출력) — DEBUG_ENABLED = true 로 켬
local DEBUG_ENABLED = false
local debug_mode = false
local function debug_print(...)
    if debug_mode then print("|cffffd200[dodo]|r|cff888888[debug]|r", ...) end
end

-- 아이콘 텍스처
local READY_ICON = "UI-LFG-ReadyMark"       -- V (아틀라스)
local NOT_READY_ICON = "UI-LFG-DeclineMark" -- X (아틀라스)
local PENDING_ICON = "UI-LFG-PendingMark"   -- ? (아틀라스)

local RAID_BUFFS = { -- 레이드버프
    {key = "Druid",   class = "DRUID",   ids = {1126, 432661}},   -- 야생의 징표
    {key = "Evoker",  class = "EVOKER",  cast = 364342, ids = {381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758}}, -- 청동용군단의 축복
    {key = "Mage",    class = "MAGE",    ids = {1459, 432778}},   -- 신비한 지능
    {key = "Priest",  class = "PRIEST",  ids = {21562}},          -- 신의 권능: 인내
    {key = "Shaman",  class = "SHAMAN",  ids = {462854}},         -- 하늘의 격노
    {key = "Warrior", class = "WARRIOR", ids = {6673}},           -- 전투의 외침
}

local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local FOOD_ITEMS = { -- 음식 아이템 (가방 수량 체크용)
    242275,         -- 왕실 구이
    266996, 255846, -- 든든한 하란다르 기념상 / 하란다르 기념상
}

local FLASK_DATA = { -- 영약
    {buff = 1235110, items = {241325, 241324, 245930, 245931}}, -- 한밤 가속 (혈기사의 영약 1,2성 / 덧없는 혈기사의 영약 1,2성)
    {buff = 1235108, items = {241323, 241322, 245932, 245933}}, -- 한밤 특화 (마법학자의 영약 1,2성 / 덧없는 마법학자의 영약 1,2성)
    {buff = 1235111, items = {241327, 241326, 245928, 245929}}, -- 한밤 치명 (무너진 태양의 영약 1,2성 / 덧없는 무너진 태양의 영약 1,2성)
    {buff = 1235057, items = {241320, 241321, 245926, 245927}}, -- 한밤 유연 (탈라시안 저항력의 영약 1,2성 / 덧없는 탈라시안 저항력의 영약 1,2성)
    {buff = 1239355, items = {241334}},                         -- 한밤 명예점수 (흉포한 명예의 탈라시안 영약)
}

local RUNE_DATA = { -- 증강 룬
    {buff = 347901,  items = {181468}},         -- 어둠땅 (장막에 감싸인 증강의 룬)
    {buff = 393438,  items = {201325, 211495}}, -- 용군단 (용의 증강의 룬) / 용군단 무한 (꿈결속 증강의 룬)
    {buff = 453250,  items = {224572}},         -- 내부전쟁 (결정화된 증강의 룬)
    {buff = 1234969, items = {243191}},         -- 내부전쟁 무한 (실체 없는 증강의 룬)
    {buff = 1242347, items = {246492}},         -- 내부전쟁 무한? (영혼포식 증강의 룬)
    {buff = 1264426, items = {259085}},         -- 한밤 (공허에 물든 증강의 룬)
}

local WEAPON_ITEMS = { -- 무기 임시 인첸트 아이템 (Midnight)
    243733, 243734, -- 탈라시안 불사조 기름
    243735, 243736, -- 여명의 기름
    243737, 243738, -- 밀수업자의 마력 깃든 칼날
    237367, 237369, -- 광명 무게추 (둔기)
    237370, 237371, -- 광명 숫돌 (날카로운)
    257749, 257750, -- 특수 성분 첨가 고속탄 (원거리)
    257751, 257752, -- 무게추 폭발탄 (원거리)
}

-- 샤먼 무기 인첸트 주문 (enchant ID -> 주문ID) — 활성 시 해당 주문 아이콘/툴팁으로 표시
local SHAMAN_IMBUE_ENCHANTS = {
    [5400] = 318038, -- 불꽃혓바닥 무기
    [5401] = 33757,  -- 질풍의 무기
    [6498] = 382021, -- 대지생명의 무기
    [7528] = 457496, -- 파도소환사의 수호
    [7587] = 462757, -- 천둥의 일격 수호물
}

local POTION_ITEMS = { -- 물약 아이템 (가방 수량 체크용, Midnight)
    241308, 241309, -- 빛의 잠재력
    241310,         -- 기교의 하라니르 약병
    241288,         -- 무모함의 물약
}

local INKY_DATA = { -- 칠흑같이 검은 물약
    {buff = 185394, items = {124640}}, -- 칠흑 같은 어둠 (버프 아이콘 136122)
}

-- ==============================
-- 테이블 파생 (위 데이터 테이블에서 생성)
-- ==============================
-- {buff = 버프 ID, items = {아이템 ID...}} 테이블에서 버프 ID 리스트 / 아이템 목록(가방 수량 체크용, 중복 제거) 파생
local function build_buff_item_tables(data)
    local buffs, items, seen_buff, seen_item = {}, {}, {}, {}
    for _, d in ipairs(data) do
        if not seen_buff[d.buff] then
            seen_buff[d.buff] = true
            buffs[#buffs + 1] = d.buff
        end
        for _, id in ipairs(d.items) do
            if not seen_item[id] then
                seen_item[id] = true
                items[#items + 1] = id
            end
        end
    end
    return buffs, items
end

local FLASK_BUFFS, FLASK_ITEMS = build_buff_item_tables(FLASK_DATA)
local RUNE_BUFFS, RUNE_ITEMS = build_buff_item_tables(RUNE_DATA)
local INKY_BUFFS, INKY_ITEMS = build_buff_item_tables(INKY_DATA)
local INKY_BUFF, INKY_ITEM = INKY_BUFFS[1], INKY_ITEMS[1] -- 현재 버프/아이템 1개씩


-- ==============================
-- 프레임 생성
-- ==============================
local main_frame = CreateFrame("Frame", "dodoReadyCheckFrame", UIParent, "SecureHandlerStateTemplate")
main_frame:SetSize(304, 88) -- 7칸: 7 * 44 - 4(마지막 간격 제외)
main_frame:SetPoint("BOTTOM", ReadyCheckFrame, "TOP", 0, 70)
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
---@param row number 행 인덱스 (1부터 시작, 위에서 아래로)
---@param index number 행 내 아이콘 순서 (1부터 시작)
---@param tooltipType "spell"|"item" 마우스오버 툴팁 유형
---@param tooltipId number 툴팁에 표시할 주문 또는 아이템 ID
---@param macrotext string|nil 클릭 시 실행할 보안 매크로 텍스트
---@return ReadyCheckIconFrame # 생성된 아이콘 프레임 객체
local function create_icon(name, texture, row, index, tooltipType, tooltipId, macrotext)
    local hasMacro = (macrotext ~= nil)
    local f = LibIcon:Create("dodoReadyCheckIcon_" .. name, main_frame, {
        isAction = hasMacro,
        iconsize = {40, 40}
    })
    f:SetPoint("TOPLEFT", main_frame, "TOPLEFT", (index - 1) * 44, -(row - 1) * 48)

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
    statusFrame:SetFrameLevel(f:GetFrameLevel() + 5) -- glow 오버레이(+3)보다 위

    f.status = statusFrame:CreateTexture(nil, "OVERLAY")
    f.status:SetAllPoints(statusFrame)
    f.status:SetAtlas(NOT_READY_ICON)

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

local HS_MACRO = "/run print('|cffffd200[dodo]|r 생석 클릭됨')\n/use item:5512\n/use 생명석"
local FOOD_MACRO = "/run print('|cffffd200[dodo]|r 음식 클릭됨')\n/use 밤의 가면 대연회\n/use 푸짐한 밤의 가면 대연회\n/use Feast of the Midnight Masquerade\n/use Hearty Feast of the Midnight Masquerade\n/use 왕실 구이"
local FLASK_MACRO = "/run print('|cffffd200[dodo]|r 영약 클릭됨')\n/use item:241324\n/use item:241325\n/use item:241322\n/use item:241323\n/use item:241326\n/use item:241327\n/use item:241320\n/use item:241321\n/use item:241334\n/use item:245931\n/use item:245930\n/use item:245933\n/use item:245932\n/use item:245929\n/use item:245928\n/use item:245926\n/use item:245927"
local RUNE_MACRO = "/run print('|cffffd200[dodo]|r 룬 클릭됨')\n/use item:259085\n/use item:243191"
local WEAPON_MACRO = "/run print('|cffffd200[dodo]|r 무기 도핑 클릭됨')\n/use item:243733\n/use 16\n/use item:243734\n/use 16\n/use item:243735\n/use 16\n/use item:243736\n/use 16\n/use item:243737\n/use 16\n/use item:243738\n/use 16"

---@class ReadyCheckIconFrame: Button
---@field status Texture
---@field text FontString
---@field cooldown Cooldown
---@field icon Texture
---@field Count FontString

---@class ReadyCheckIcons
---@field hs ReadyCheckIconFrame 생석 아이콘 프레임
---@field food ReadyCheckIconFrame 음식 아이콘 프레임
---@field flask ReadyCheckIconFrame 영약 아이콘 프레임
---@field rune ReadyCheckIconFrame 룬 아이콘 프레임
---@field weapon ReadyCheckIconFrame 무기 도핑 아이콘 프레임
---@field potion ReadyCheckIconFrame 물약 아이콘 프레임
---@field inky ReadyCheckIconFrame 칠흑같이 검은 물약 아이콘 프레임
---@field durability ReadyCheckIconFrame 내구도 아이콘 프레임

---@type ReadyCheckIcons
local icons = {}
-- 1행: 레이드버프 (직업별 항상 표시)
-- 클릭 시 시전은 본인 직업의 버프만 가능 (다른 직업은 표시 전용)
local player_class = select(2, UnitClass("player"))
for i, b in ipairs(RAID_BUFFS) do
    local macro
    if b.class == player_class then
        local spell_name = C_Spell.GetSpellName(b.cast or b.ids[1])
        if spell_name then macro = "/cast " .. spell_name end
    end
    icons["raid" .. b.key] = create_icon("RaidBuff" .. b.key, C_Spell.GetSpellTexture(b.ids[1]) or 135987, 1, i, "spell", b.ids[1], macro)
end
icons.hs = create_icon("Healthstone", 135230, 1, #RAID_BUFFS + 1, "item", 5512, HS_MACRO)
-- 2행: 도핑템 + 기타
icons.food = create_icon("Food", 136000, 2, 1, "item", 242275, FOOD_MACRO)
icons.flask = create_icon("Flask", 7548903, 2, 2, "item", 241327, FLASK_MACRO)
icons.rune = create_icon("Rune", 3566863, 2, 3, "spell", 393438, RUNE_MACRO)
icons.weapon = create_icon("Weapon", 7548987, 2, 4, "item", 243734, WEAPON_MACRO)
icons.potion = create_icon("Potion", 7548911, 2, 5, "item", 241308, nil)
icons.inky = create_icon("Inky", 134757, 2, 6, "item", INKY_ITEM, "/use item:"..INKY_ITEM)
icons.durability = create_icon("Durability", 136241, 2, 7, nil, nil, nil)
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
    rune   = "lastUsedRune",
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
    local tex = C_Item.GetItemIconByID(itemID)
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

local dd_frame
local dd_owner, dd_owner_icon
local dd_buttons = {}

local function hide_dropdown()
    if dd_frame and dd_frame:IsShown() then
        debug_print("드롭다운 닫힘")
        dd_frame:Hide()
    end
end

-- 아이콘/화살표/드롭다운 위에 마우스가 없으면 닫기 (표시 중에만 동작)
local function dropdown_on_update()
    if not main_frame:IsShown()
    or not (dd_frame:IsMouseOver(20, 0, 0, 0)
         or (dd_owner and dd_owner:IsMouseOver())
         or (dd_owner_icon and dd_owner_icon:IsMouseOver())) then
        hide_dropdown()
    end
end

local DD_SZ, DD_GAP = 36, 3

local function show_dropdown(anchor, category, items, slot, ownerIcon)
    local avail = {}
    for _, id in ipairs(items) do
        local c = GetItemCount(id, false, true)
        if c > 0 then avail[#avail+1] = {id=id, count=c} end
    end
    debug_print("드롭다운 열기 시도:", category, "보유 종류", #avail)
    if #avail == 0 then return end

    -- 지연 생성: 드롭다운 컨테이너 프레임
    if not dd_frame then
        dd_frame = CreateFrame("Frame", "dodoConsumeDropdown", UIParent)
        dd_frame:SetFrameStrata("HIGH")
        dd_frame:SetFrameLevel(100)
        dd_frame:SetScript("OnUpdate", dropdown_on_update)
    end
    dd_owner, dd_owner_icon = anchor, ownerIcon

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
    dd_frame:SetPoint("TOPLEFT", ownerIcon, "BOTTOMLEFT", 0, -20) -- 아이콘 왼쪽 기준, 오른쪽으로 성장 (화살표 -16 + 여백 4)
    dd_frame:Show()
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
        else show_dropdown(arrow, category, items, slot, iconFrame) end
    end)
    -- 아이콘에 마우스 올리면 자동 펼침
    iconFrame:HookScript("OnEnter", function()
        if InCombatLockdown() then return end
        show_dropdown(arrow, category, items, slot, iconFrame)
    end)
end

add_dropdown_arrow(icons.flask,  "flask",  FLASK_ITEMS)
add_dropdown_arrow(icons.food,   "food",   FOOD_ITEMS)
add_dropdown_arrow(icons.rune,   "rune",   RUNE_ITEMS)
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

-- 파티/레이드에 존재하는 직업 집합 갱신
local group_classes = {}
local function fill_group_classes()
    wipe(group_classes)
    local units, n = PARTY_UNITS, 5
    if IsInRaid() then
        units, n = RAID_UNITS, GetNumGroupMembers()
    end
    for i = 1, n do
        local _, class = UnitClass(units[i])
        if class and not issecretvalue(class) then group_classes[class] = true end
    end
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

-- unknown: 확인 불가(제한 상태 등)면 흑백 + ? 마크
local function set_status(iconFrame, active, unknown)
    iconFrame.icon:SetDesaturated(not active)
    iconFrame.status:SetAtlas(unknown and PENDING_ICON or (active and READY_ICON or NOT_READY_ICON))
end

-- ==============================
-- 감지 결과(state): 모든 아이콘이 같은 형태로 보관 (재사용 테이블)
--   active: 충족 여부 / unknown: 확인 불가 / duration, expiration: 남은 시간 / icon: 버프 아이콘
-- ==============================
local function new_state()
    return {active = false, unknown = false, duration = 0, expiration = 0, icon = nil}
end

local states = {}
for key in pairs(icons) do states[key] = new_state() end

local function reset_state(state, unknown)
    state.active, state.unknown, state.duration, state.expiration, state.icon = false, unknown or false, 0, 0, nil
end

-- secret 값이면 시간 정보 생략 (연산/SetCooldown 방지)
local function set_timing(state, data)
    local dur, exp = data.duration, data.expirationTime
    if dur and exp and not issecretvalue(dur) and not issecretvalue(exp) then
        state.duration, state.expiration = dur, exp
    end
end

-- 감지 A: 버프 ID 리스트를 GetPlayerAuraBySpellID로 직접 조회 (화이트리스트 ID, secret-safe)
local function detect_by_ids(state, ids)
    reset_state(state)
    for i = 1, #ids do
        local data = C_UnitAuras.GetPlayerAuraBySpellID(ids[i])
        if data then
            state.active = true
            local ic = data.icon
            if ic and not issecretvalue(ic) then state.icon = ic end
            set_timing(state, data)
            return
        end
    end
end

-- 감지 B: 버프 인덱스 스캔은 한 번만 수행 (음식: 아이콘 136000 Well Fed / 칠흑 물약: 버프 ID·아이콘)
-- 스캔 불가/아이콘이 전부 secret이면 unknown (확인 불가)
local function scan_player_auras(food, inky)
    reset_state(food, true)
    reset_state(inky, true)

    -- 제한 상태(M+ 등)에선 인덱스 스캔이 하드 에러 → 스캔 생략
    if InCombatLockdown() then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end

    local saw_icon, saw_secret = false, false
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then return end
        if not data then break end
        local ic, sid = data.icon, data.spellId
        if ic and not issecretvalue(ic) then
            saw_icon = true
            if ic == 136000 and not food.active then
                food.active = true
                set_timing(food, data)
            elseif ic == 136122 then
                inky.active = true
            end
        else
            saw_secret = true
        end
        if sid and not issecretvalue(sid) and sid == INKY_BUFF then inky.active = true end
    end
    local known = saw_icon or not saw_secret
    food.unknown, inky.unknown = not known, not known
end

-- 표시: 상태 마크 + 남은 시간(쿨다운) + 개수. 충족이면 시간, 아니면 개수 표시
local function apply_state(iconFrame, state, count)
    set_status(iconFrame, state.active, state.unknown)
    if state.active then
        if state.duration > 0 then
            iconFrame.cooldown:SetCooldown(state.expiration - state.duration, state.duration)
        else
            iconFrame.cooldown:Clear()
        end
        iconFrame.Count:SetText("")
    else
        iconFrame.cooldown:Clear()
        iconFrame.Count:SetText((count and count > 0) and count or "")
    end
    iconFrame.text:SetText("")
end

function update_consumables()
    if not main_frame.is_visible then return end

    throttle("ReadyCheckUpdate", function()
        -- 표시 아이콘 갱신: lastUsed 우선, 없으면 가방 첫 번째
        -- (영약은 버프 활성 시 아래 섹션에서 버프 아이콘으로 덮어씀)
        local fd  = get_display_item(LAST_USED_KEYS.food,   FOOD_ITEMS)
        if fd  then update_icon_item(icons.food,   fd)  end
        local fid = get_display_item(LAST_USED_KEYS.flask,  FLASK_ITEMS)
        if fid then update_icon_item(icons.flask,  fid) end
        local rid = get_display_item(LAST_USED_KEYS.rune,   RUNE_ITEMS)
        if rid then update_icon_item(icons.rune,   rid) end
        local wid = get_display_item(LAST_USED_KEYS.weapon, WEAPON_ITEMS)
        if wid then update_icon_item(icons.weapon, wid) end
        local pid = get_display_item(LAST_USED_KEYS.potion, POTION_ITEMS)
        if pid then update_icon_item(icons.potion, pid) end

        -- 개수는 아이콘에 표시된 아이템 기준
        local foodCount   = fd  and GetItemCount(fd,  false, true) or 0
        local flaskCount  = fid and GetItemCount(fid, false, true) or 0
        local runeCount   = rid and GetItemCount(rid, false, true) or 0
        local potionCount = pid and GetItemCount(pid, false, true) or 0
        local hsCount     = GetItemCount(5512, false, true)
        local inkyCount   = GetItemCount(INKY_ITEM, false, true)

        -- 감지
        scan_player_auras(states.food, states.inky)
        detect_by_ids(states.flask, FLASK_BUFFS)
        detect_by_ids(states.rune, RUNE_BUFFS)
        fill_group_classes()
        for _, b in ipairs(RAID_BUFFS) do
            detect_by_ids(states["raid" .. b.key], b.ids)
        end

        -- 무기: 임시 인챈트 (남은 시간은 ms → 초)
        local hasMainHandEnchant, mainHandExpiration, _, mainHandEnchID = GetWeaponEnchantInfo()
        local weapon = states.weapon
        reset_state(weapon)
        weapon.active = not not hasMainHandEnchant
        if weapon.active then
            local remain = (mainHandExpiration or 0) / 1000
            weapon.duration, weapon.expiration = remain, GetTime() + remain
        end

        -- 샤먼 무기 인첸트 주문이 걸려있으면 해당 주문 아이콘/툴팁으로, 아니면 기본 오일로 표시
        local imbueSpell = weapon.active and SHAMAN_IMBUE_ENCHANTS[mainHandEnchID]
        if imbueSpell then
            icons.weapon.icon:SetTexture(C_Spell.GetSpellTexture(imbueSpell))
            icons.weapon.tooltipType = "spell"
            icons.weapon.tooltipId = imbueSpell
        else
            icons.weapon.icon:SetTexture(7548987) -- 탈라시안 불사조 기름
            icons.weapon.tooltipType = "item"
            icons.weapon.tooltipId = 243734
        end
        -- 개수는 아이콘에 표시된 아이템 기준
        local weaponCount = (icons.weapon.tooltipType == "item") and GetItemCount(icons.weapon.tooltipId, false, true) or 0

        -- 버프가 아닌 항목: 가방 개수 / 내구도로 판단
        reset_state(states.hs)
        states.hs.active = (hsCount > 0)
        reset_state(states.potion) -- 물약은 버프 체크 없이 가방 내 소지 개수만으로 판단
        states.potion.active = (potionCount > 0)

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
        reset_state(states.durability)
        states.durability.active = (duraPct >= 20)

        -- 표시 (아이콘 배치 순서)
        -- 1. 레이드버프: 파티에 해당 직업이 있는데 버프가 없으면 glow
        for _, b in ipairs(RAID_BUFFS) do
            local key = "raid" .. b.key
            apply_state(icons[key], states[key])
            icons[key]:SetGlow(group_classes[b.class] and not states[key].active)
        end
        -- 2. 생석
        apply_state(icons.hs, states.hs, hsCount)
        -- 3. 음식
        apply_state(icons.food, states.food, foodCount)
        -- 4. 영약
        apply_state(icons.flask, states.flask, flaskCount)
        if states.flask.active and states.flask.icon then icons.flask.icon:SetTexture(states.flask.icon) end
        -- 5. 룬
        apply_state(icons.rune, states.rune, runeCount)
        -- 6. 무기 도핑
        apply_state(icons.weapon, weapon, weaponCount)
        -- 7. 물약
        apply_state(icons.potion, states.potion, potionCount)
        -- 8. 칠흑같이 검은 물약
        apply_state(icons.inky, states.inky, inkyCount)
        -- 9. 내구도
        apply_state(icons.durability, states.durability)
        icons.durability.text:SetText(duraPct .. "%")
    end, 0.2)
end

-- ==============================
-- 테스트 기능
-- ==============================
-- 이름 덤프 (DEBUG_ENABLED 일 때만): 테이블의 아이템/주문 ID → 클라이언트 한국어 이름을 dodoDB.debugNames 에 저장
-- /111 테스트 시작 시 자동 실행 → /reload 후 SavedVariables 파일에서 확인
local function dump_names()
    if not DEBUG_ENABLED then return end

    local item_ids, spell_ids, seen_item, seen_spell = {}, {}, {}, {}
    local function add_item(id)
        if id and not seen_item[id] then seen_item[id] = true; item_ids[#item_ids + 1] = id end
    end
    local function add_spell(id)
        if id and not seen_spell[id] then seen_spell[id] = true; spell_ids[#spell_ids + 1] = id end
    end

    for _, list in ipairs({FOOD_ITEMS, FLASK_ITEMS, RUNE_ITEMS, WEAPON_ITEMS, POTION_ITEMS, INKY_ITEMS}) do
        for _, id in ipairs(list) do add_item(id) end
    end
    add_item(5512) -- 생석
    for _, list in ipairs({FLASK_BUFFS, RUNE_BUFFS, INKY_BUFFS}) do
        for _, id in ipairs(list) do add_spell(id) end
    end
    for _, b in ipairs(RAID_BUFFS) do
        for _, id in ipairs(b.ids) do add_spell(id) end
        add_spell(b.cast)
    end
    for _, id in pairs(SHAMAN_IMBUE_ENCHANTS) do add_spell(id) end

    -- 아이템 정보는 캐시 전이면 비어 있으므로 먼저 로드 요청 후 잠시 뒤 수집
    for _, id in ipairs(item_ids) do C_Item.RequestLoadItemDataByID(id) end
    debug_print("이름 덤프: 아이템 " .. #item_ids .. "개 / 주문 " .. #spell_ids .. "개 조회 중...")

    C_Timer.After(2, function()
        local items, spells, missing = {}, {}, 0
        for _, id in ipairs(item_ids) do
            local name = C_Item.GetItemNameByID(id)
            items[id] = name or "(없음)"
            if not name then missing = missing + 1 end
        end
        for _, id in ipairs(spell_ids) do
            local name = C_Spell.GetSpellName(id)
            spells[id] = name or "(없음)"
            if not name then missing = missing + 1 end
        end
        dodoDB.debugNames = {items = items, spells = spells}
        print("|cffffd200[dodo]|r|cff888888[debug]|r 이름 덤프 완료 (이름 없음 " .. missing .. "개). /reload 하면 SavedVariables에 저장됩니다."
            .. (missing > 0 and " 없음이 있으면 /111 을 한 번 더 실행하세요." or ""))
    end)
end

local function dump_icons()
    for key, ic in pairs(icons) do
        debug_print(key,
            "ready=" .. tostring(not ic.icon:IsDesaturated()),
            "tip=" .. tostring(ic.tooltipType) .. ":" .. tostring(ic.tooltipId),
            "count=" .. tostring(ic.Count:GetText()),
            "mouse=" .. tostring(ic:IsMouseEnabled()))
    end
end

local function test_ready_check()
    if main_frame.is_visible then
        debug_mode = false
        if debounces["ReadyCheckHide"] then
            debounces["ReadyCheckHide"]:Cancel()
        end
        hide_frame()
        main_frame:UnregisterEvent("READY_CHECK_FINISHED")
        main_frame:UnregisterEvent("UNIT_AURA")
        main_frame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        main_frame:UnregisterEvent("PLAYER_REGEN_DISABLED")

        if ReadyCheckFrame then ReadyCheckFrame:Hide() end
        if ReadyCheckListenerFrame then ReadyCheckListenerFrame:Hide() end
        print("|cffffd200[dodo]|r ReadyCheck 테스트 모드 종료")
    else
        debug_mode = DEBUG_ENABLED
        -- 본인이 시작자면 ShowReadyCheck가 ReadyCheckListenerFrame을 숨기므로, 직접 다시 표시
        if ReadyCheckFrame then
            if ShowReadyCheck then ShowReadyCheck("player", 35) end
            if ReadyCheckListenerFrame then ReadyCheckListenerFrame:Show() end
            if ReadyCheckPortrait then SetPortraitTexture(ReadyCheckPortrait, "player") end
            ReadyCheckFrameText:SetText("dodo ReadyCheck 테스트 중...")
            ReadyCheckFrame:Show()
        else
            debug_print("전투준비창: ReadyCheckFrame 자체가 nil")
        end
        debug_print("전투준비창 표시 여부:", ReadyCheckFrame and ReadyCheckFrame:IsShown(),
            "Listener:", ReadyCheckListenerFrame and ReadyCheckListenerFrame:IsShown())

        -- 테스트 시작 시 실시간 추적 이벤트 동적 등록
        main_frame:RegisterEvent("READY_CHECK_FINISHED")
        main_frame:RegisterEvent("UNIT_AURA")
        main_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")

        debug_mode = DEBUG_ENABLED
        show_frame()
        dump_icons()
        dump_names()

        debounce("ReadyCheckHide", function()
            debug_mode = false
            hide_frame()
            main_frame:UnregisterEvent("READY_CHECK_FINISHED")
            main_frame:UnregisterEvent("UNIT_AURA")
            main_frame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
            main_frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
            if ReadyCheckFrame then ReadyCheckFrame:Hide() end
            if ReadyCheckListenerFrame then ReadyCheckListenerFrame:Hide() end
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
