---@diagnostic disable: undefined-global
local addonName, dodo = ...

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

local function collect_spellbook_spells()
    local bank   = Enum.SpellBookSpellBank.Player
    local result = {}
    local numLines = C_SpellBook.GetNumSpellBookSkillLines()
    for skillIndex = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillIndex)
        if lineInfo and lineInfo.name ~= "일반" and lineInfo.name ~= "General" then
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
                        result[#result + 1] = line_spells[idx]
                    end
                end
            end
        end
    end
    return result
end

local function collect_cdm_spells()
    local result = {}
    local function scan(pool)
        if not pool or not pool.GetItemFrames then return end
        for _, item in ipairs(pool:GetItemFrames()) do
            if item.cooldownID and C_CooldownViewer then
                local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
                if cdInfo and cdInfo.spellID then
                    local baseID = C_Spell.GetBaseSpell(cdInfo.spellID) or cdInfo.spellID
                    if not result[baseID] then
                        result[baseID] = C_Spell.GetSpellName(baseID) or tostring(baseID)
                    end
                end
            end
        end
    end
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
                rootDescription:CreateDivider()
            end

            local cdm_spells = collect_cdm_spells()
            if next(cdm_spells) then
                rootDescription:CreateTitle("강화효과 연결:")
                for buffID, buffName in pairs(cdm_spells) do
                    local bid = buffID
                    rootDescription:CreateButton(buffName, function()
                        if dodo.setCDMMapping then dodo.setCDMMapping(bid, spellID) end
                        if dodo.BuildSpecialButtonCache then dodo.BuildSpecialButtonCache() end
                        if self.__page_refresh then self.__page_refresh() end
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
    local header = CreateFrame("Button", nil, page, "ListHeaderThreeSliceTemplate")
    header:SetSize(0, 22)
    header:SetPoint("TOPLEFT",  page, "TOPLEFT")
    header:SetPoint("TOPRIGHT", page, "TOPRIGHT")
    if header.Name then
        header.Name:SetText("행동 단축바")
    end
    header:SetTitleColor(false, NORMAL_FONT_COLOR)
    header:SetTitleColor(true, NORMAL_FONT_COLOR)

    local sf = CreateFrame("ScrollFrame", nil, page)
    sf:SetPoint("TOPLEFT",     header, "BOTTOMLEFT",  13, -15)
    sf:SetPoint("BOTTOMRIGHT", page,   "BOTTOMRIGHT", 0,  0)

    local collapsed = false
    header:UpdateCollapsedState(false)
    header:SetClickHandler(function(self, button)
        collapsed = not collapsed
        self:UpdateCollapsedState(collapsed)
        sf:SetShown(not collapsed)
    end)

    local STRIDE = 7
    local PAD    = 8

    local content = CreateFrame("Frame", nil, sf)
    content:SetHeight(1)
    sf:SetScrollChild(content)

    local icon_pool = {}

    local function layout(count)
        local w = sf:GetWidth()
        if w < 1 then w = STRIDE * (ICON_SIZE + PAD) + PAD end
        content:SetWidth(w)
        local rows = math.ceil(count / STRIDE)
        content:SetHeight(math.max(1, PAD + rows * (ICON_SIZE + PAD)))
        for i = 1, count do
            local col = (i - 1) % STRIDE
            local row = math.floor((i - 1) / STRIDE)
            icon_pool[i]:ClearAllPoints()
            icon_pool[i]:SetPoint("TOPLEFT", content, "TOPLEFT",
                PAD + col * (ICON_SIZE + PAD),
                -(PAD + row * (ICON_SIZE + PAD)))
        end
    end

    local function refresh()
        if not page:IsShown() then return end

        local spells = collect_spellbook_spells()

        for i = #spells + 1, #icon_pool do
            icon_pool[i]:Hide()
        end

        for i, spell in ipairs(spells) do
            local ib = icon_pool[i]
            if not ib then
                ib = create_skill_icon(content)
                icon_pool[i] = ib
            end

            ib.Icon:SetTexture(spell.icon)
            ib.spellID        = spell.spellID
            ib.__page_refresh = refresh

            local linked = dodo.getCDMMappingForSkill and dodo.getCDMMappingForSkill(spell.spellID) or {}
            ib.LinkedGlow:SetShown(#linked > 0)
            ib:Show()
        end

        layout(#spells)
    end

    page.Refresh = refresh
    page:SetScript("OnShow", function() refresh() end)
    sf:SetScript("OnSizeChanged", function()
        layout(#icon_pool)
    end)
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
