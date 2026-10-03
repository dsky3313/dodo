-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo

-- ==============================
-- 수동 버프 ID 입력 팝업
-- ==============================
local pending_link_skill_id = nil
local pending_page_refresh   = nil

StaticPopupDialogs["DODO_CDM_LINK_BUFF"] = {
    text         = "연결할 버프 주문 ID를 입력하세요.",
    button1      = "확인",
    button2      = "취소",
    hasEditBox   = true,
    maxLetters   = 12,
    OnShow = function(self)
        self.editBox:SetText("")
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local buffID = tonumber(self.editBox:GetText())
        if buffID and buffID > 0 and pending_link_skill_id then
            if dodo.setCDMMapping then dodo.setCDMMapping(buffID, pending_link_skill_id) end
            if dodo.BuildSpecialButtonCache then dodo.BuildSpecialButtonCache() end
            if pending_page_refresh then pending_page_refresh() end
        end
        pending_link_skill_id = nil
        pending_page_refresh  = nil
    end,
    OnCancel = function()
        pending_link_skill_id = nil
        pending_page_refresh  = nil
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ==============================
-- 스펠북 + CDM 버프 연결
-- ==============================
local ICON_SIZE      = 38
local SPELLBOOK_COLS = 3  -- columnsPerRow (column-first 배치)

-- 첫 번째 non-General 라인 = 클래스, 이후 = 특성
local function collect_class_talent_spells()
    local bank          = Enum.SpellBookSpellBank.Player
    local class_spells  = {}
    local talent_spells = {}
    local numLines      = C_SpellBook.GetNumSpellBookSkillLines()
    local first_found   = false
    for skillIndex = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillIndex)
        if lineInfo and lineInfo.name ~= "일반" and lineInfo.name ~= "General" then
            local target    = (not first_found) and class_spells or talent_spells
            first_found     = true
            local line_spells = {}
            for slot = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                local itemInfo = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if itemInfo and itemInfo.itemType == Enum.SpellBookItemType.Spell then
                    if not C_SpellBook.IsSpellBookItemPassive(slot, bank)
                    and not C_SpellBook.IsSpellBookItemOffSpec(slot, bank)
                    and not C_SpellBook.IsAutoAttackSpellBookItem(slot, bank) then
                        line_spells[#line_spells + 1] = { spellID = itemInfo.spellID, icon = itemInfo.iconID }
                    end
                end
            end
            -- 스펠북은 column-first 배치 → 가로(왼→오른) 우선 읽기로 전치
            local n    = #line_spells
            local rows = math.ceil(n / SPELLBOOK_COLS)
            for row = 0, rows - 1 do
                for col = 0, SPELLBOOK_COLS - 1 do
                    local idx = col * rows + row + 1
                    if idx <= n then
                        target[#target + 1] = line_spells[idx]
                    end
                end
            end
        end
    end
    return class_spells, talent_spells
end

-- 장착된 장신구(슬롯 13, 14) 전부 — 사용 스킬 없는 패시브 장신구도 포함
local function collect_trinket_spells()
    local result = {}
    for _, slot in ipairs({13, 14}) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local icon = GetInventoryItemTexture("player", slot)
            if icon then
                local _, spellID = C_Item.GetItemSpell(itemID)
                result[#result + 1] = { spellID = spellID, icon = icon, itemID = itemID }
            end
        end
    end
    return result
end

-- CDM에 등록된 스펠 목록 수집. [baseSpellID] = 이름
-- CDM spellID(탤런트/패시브)와 실제 버프 ID가 다를 수 있어서
-- linkedSpellIDs를 먼저 추가하고 메인 spellID는 이름 중복 시 스킵.
-- (예: 집행자의 정밀함 — CDM=386634, 실제 버프=386633)
-- item_only=true  → equipSlot 있는 것만 (장신구 강화효과)
-- item_only=false → equipSlot 없는 것만 (직업/특성 스킬)
local function collect_cdm_spells(item_only)
    local result = {}
    local seen_names = {}
    local function add(id)
        local baseID = C_Spell.GetBaseSpell(id) or id
        local name = C_Spell.GetSpellName(baseID) or tostring(baseID)
        if not seen_names[name] then
            seen_names[name] = true
            result[baseID] = name
        end
    end
    local function scan(pool)
        if not pool or not pool.GetItemFrames then return end
        for _, item in ipairs(pool:GetItemFrames()) do
            if item.cooldownID and C_CooldownViewer then
                local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
                if cdInfo then
                    local is_item = cdInfo.equipSlot ~= nil
                    if is_item == item_only then
                        for _, sid in ipairs(cdInfo.linkedSpellIDs or {}) do add(sid) end
                        if cdInfo.spellID and cdInfo.spellID ~= 0 then add(cdInfo.spellID) end
                    end
                end
            end
        end
    end
    scan(EssentialCooldownViewer)
    scan(UtilityCooldownViewer)
    scan(BuffBarCooldownViewer)
    scan(BuffIconCooldownViewer)
    return result
end

local function create_skill_icon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:EnableMouse(true)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    f.Icon = icon

    -- 액션바 border (원본: TOPLEFT + Size(46,45) on 45x45 button)
    local border = f:CreateTexture(nil, "OVERLAY", nil, 7)
    border:SetAtlas("UI-HUD-ActionBar-IconFrame", false)
    border:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    border:SetSize(ICON_SIZE + 1, ICON_SIZE)

    -- 마우스오버 하이라이트
    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")

    -- 연결 표시 (원본 SpellHighlightTexture: TOPLEFT + alphaMode ADD + alpha 0.4)
    local glow = f:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", false)
    glow:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    glow:SetSize(ICON_SIZE + 1, ICON_SIZE)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0, 1, 0, 1)
    glow:Hide()
    f.LinkedGlow = glow

    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.spellID then
            GameTooltip:SetSpellByID(self.spellID)
        elseif self.itemID then
            GameTooltip:SetItemByID(self.itemID)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" or not self.spellID then return end
        local spellID = self.spellID

        MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
            local name = C_Spell.GetSpellName(spellID) or tostring(spellID)
            rootDescription:CreateTitle(name)

            local linked = dodo.getCDMMappingForSkill and dodo.getCDMMappingForSkill(spellID) or {}
            if #linked > 0 then
                for _, buffID in ipairs(linked) do
                    local buffName = C_Spell.GetSpellName(buffID) or tostring(buffID)
                    rootDescription:CreateTitle("→ " .. buffName)
                end
                rootDescription:CreateButton("연결 해제", function()
                    for _, buffID in ipairs(linked) do
                        if dodo.removeCDMMapping then dodo.removeCDMMapping(buffID) end
                    end
                    if dodo.BuildSpecialButtonCache then dodo.BuildSpecialButtonCache() end
                    if self.__page_refresh then self.__page_refresh() end
                end)
            end
            rootDescription:CreateDivider()

            local cdm_spells = collect_cdm_spells(self.itemID ~= nil)
            if next(cdm_spells) then
                rootDescription:CreateTitle("강화효과 연결:")
                for buffID, buffName in pairs(cdm_spells) do
                    local bid = buffID
                    local icon = C_Spell.GetSpellTexture(buffID)
                    local label = icon and ("|T" .. icon .. ":14:14:0:0|t " .. buffName) or buffName
                    local btn = rootDescription:CreateButton(label, function()
                        if dodo.setCDMMapping then dodo.setCDMMapping(bid, spellID) end
                        if dodo.BuildSpecialButtonCache then dodo.BuildSpecialButtonCache() end
                        if self.__page_refresh then self.__page_refresh() end
                    end)
                    btn:SetTooltip(function(tooltip)
                        tooltip:SetSpellByID(bid)
                    end)
                end
                rootDescription:CreateDivider()
            end

            rootDescription:CreateButton("ID 직접 입력...", function()
                pending_link_skill_id = spellID
                pending_page_refresh  = self.__page_refresh
                StaticPopup_Show("DODO_CDM_LINK_BUFF")
            end)
        end)
    end)

    return f
end

local function build_page_a(page)
    local sf = CreateFrame("ScrollFrame", nil, page)
    sf:SetPoint("TOPLEFT",     page, "TOPLEFT")
    sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT")

    local content = CreateFrame("Frame", nil, sf)
    content:SetHeight(1)
    sf:SetScrollChild(content)

    local STRIDE         = 7
    local ITEM_PAD       = 8   -- childXPadding / childYPadding (블리자드 원본)
    local HEADER_H       = 22
    local CONTAINER_LEFT = 13  -- Header BOTTOMLEFT x=13 (블리자드 원본)
    local CONTAINER_TOP  = 15  -- Header BOTTOMLEFT y=-15 (블리자드 원본)
    local SECTION_GAP    = 8   -- 섹션 간 여백

    local sections = {
        { label = "직업",   pool = {}, spells = {}, collapsed = false },
        { label = "특성",   pool = {}, spells = {}, collapsed = false },
        { label = "장신구", pool = {}, spells = {}, collapsed = false },
    }

    local layout_all  -- forward declaration (헤더 클릭 핸들러에서 참조)

    for _, sec in ipairs(sections) do
        sec.header = CreateFrame("Button", nil, content, "ListHeaderThreeSliceTemplate")
        sec.header:SetSize(0, HEADER_H)
        if sec.header.Name then sec.header.Name:SetText(sec.label) end
        sec.header:SetTitleColor(false, NORMAL_FONT_COLOR)
        sec.header:SetTitleColor(true, NORMAL_FONT_COLOR)
        sec.header:UpdateCollapsedState(false)
        sec.header:SetClickHandler(function(self)
            sec.collapsed = not sec.collapsed
            self:UpdateCollapsedState(sec.collapsed)
            layout_all()
        end)
    end

    layout_all = function()
        local w = sf:GetWidth()
        if w < 1 then w = CONTAINER_LEFT + STRIDE * (ICON_SIZE + ITEM_PAD) end
        content:SetWidth(w)
        local y = 0
        for _, sec in ipairs(sections) do
            sec.header:ClearAllPoints()
            sec.header:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
            sec.header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            y = y + HEADER_H + CONTAINER_TOP
            local count = #sec.spells
            if sec.collapsed or count == 0 then
                for i = 1, count do
                    if sec.pool[i] then sec.pool[i]:Hide() end
                end
            else
                for i = 1, count do
                    local col = (i - 1) % STRIDE
                    local row = math.floor((i - 1) / STRIDE)
                    sec.pool[i]:ClearAllPoints()
                    sec.pool[i]:SetPoint("TOPLEFT", content, "TOPLEFT",
                        CONTAINER_LEFT + col * (ICON_SIZE + ITEM_PAD),
                        -(y + row * (ICON_SIZE + ITEM_PAD)))
                    sec.pool[i]:Show()
                end
                local rows = math.ceil(count / STRIDE)
                y = y + rows * (ICON_SIZE + ITEM_PAD) + SECTION_GAP
            end
        end
        content:SetHeight(math.max(1, y))
    end

    local function update_section(sec, spells, refresh_fn)
        for i = #spells + 1, #sec.pool do
            if sec.pool[i] then sec.pool[i]:Hide() end
        end
        for i, spell in ipairs(spells) do
            local ib = sec.pool[i]
            if not ib then
                ib = create_skill_icon(content)
                sec.pool[i] = ib
            end
            ib.Icon:SetTexture(spell.icon)
            ib.spellID        = spell.spellID
            ib.itemID         = spell.itemID
            ib.__page_refresh = refresh_fn
            local linked = (spell.spellID and dodo.getCDMMappingForSkill) and dodo.getCDMMappingForSkill(spell.spellID) or {}
            ib.LinkedGlow:SetShown(#linked > 0)
        end
        sec.spells = spells
    end

    local function refresh()
        if not page:IsShown() then return end

        local classLabel = UnitClass("player") or "직업"
        if sections[1].header.Name then sections[1].header.Name:SetText(classLabel) end

        local specIndex = GetSpecialization()
        local specLabel = (specIndex and select(2, GetSpecializationInfo(specIndex))) or "특성"
        if sections[2].header.Name then sections[2].header.Name:SetText(specLabel) end

        local class_spells, talent_spells = collect_class_talent_spells()
        local trinket_spells = collect_trinket_spells()
        update_section(sections[1], class_spells,   refresh)
        update_section(sections[2], talent_spells,  refresh)
        update_section(sections[3], trinket_spells, refresh)
        layout_all()
    end

    page.Refresh = refresh
    page:SetScript("OnShow", function() refresh() end)
    sf:SetScript("OnSizeChanged", function() layout_all() end)
end

-- ==============================
-- 초기화 (Data/CDM.lua setup 완료 후)
-- ==============================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    local settings = _G.CooldownViewerSettings
    if settings and settings.dodoPageA then
        build_page_a(settings.dodoPageA)
    end
    self:UnregisterEvent("PLAYER_LOGIN")
end)
