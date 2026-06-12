-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: undefined-field
local addonName, dodo = ...
local LibIcon = {}
dodo.LibIcon = LibIcon

local function RescaleIcon(self)
    local width = self:GetWidth()
    local margin = math.max(2, width * 0.07)
    self.icon:ClearAllPoints()
    self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", margin, -margin)
    self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -margin, margin)
end

local function SetTextColorFromTable(fontString, colorTable)
    if colorTable then
        fontString:SetTextColor(colorTable[1] or 1, colorTable[2] or 1, colorTable[3] or 1)
    end
end

local fontColorTable = {
    white  = {1, 1, 1},
    yellow = {1, 0.82, 0},
    red    = {1, 0.2, 0.2},
    green  = {0.1, 1, 0.1},
    orange = {1, 0.5, 0},
    gray   = {0.5, 0.5, 0.5},
}

-- ==============================
-- 동작
-- ==============================
function LibIcon:Create(name, parent, config)
    local isAction = config and config.isAction or false
    local template = isAction and "SecureActionButtonTemplate" or nil
    local frameType = isAction and "Button" or "Frame"
    local frame = CreateFrame(frameType, name, parent or UIParent, template)
    local size = config and config.iconsize or {40, 40}

    -- 아이콘 크기, 레이아웃
    frame:SetSize(size[1], size[2])
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    frame.RescaleIcon = RescaleIcon
    frame:RescaleIcon()

    frame.normalTexture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.normalTexture:SetAtlas("UI-HUD-ActionBar-IconFrame")
    frame.normalTexture:SetAllPoints(frame)

    frame.cooldown = CreateFrame("Cooldown", name .. "Cooldown", frame, "CooldownFrameTemplate")
    frame.cooldown:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", 0, 0)
    frame.cooldown:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 0, 0)
    frame.cooldown:SetFrameLevel(frame:GetFrameLevel() + 1)
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetDrawSwipe(true)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.8)

    -- 오버레이 레이어 (border, text 전용)
    local overlayLayer = CreateFrame("Frame", nil, frame)
    overlayLayer:SetAllPoints(frame)
    overlayLayer:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.overlayLayer = overlayLayer

    frame.normalTexture:SetParent(overlayLayer)
    frame.normalTexture:SetDrawLayer("ARTWORK")

    frame.Name = overlayLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Count = overlayLayer:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    frame.Count:SetPoint("BOTTOMRIGHT", overlayLayer, "BOTTOMRIGHT", -2, 2)
    if dodo.Colors and dodo.Colors.Gold then
        frame.Count:SetTextColor(dodo.Colors.Gold.r, dodo.Colors.Gold.g, dodo.Colors.Gold.b)
    else
        frame.Count:SetTextColor(1.00, 0.82, 0.00)
    end

    if isAction then
        local highlight = overlayLayer:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        highlight:SetAlpha(0.5); highlight:SetBlendMode("ADD"); highlight:SetAllPoints(overlayLayer)
        local pushed = overlayLayer:CreateTexture(nil, "OVERLAY")
        pushed:SetAtlas("UI-HUD-ActionBar-IconFrame-Down")
        pushed:SetAlpha(0.5); pushed:SetBlendMode("ADD"); pushed:SetAllPoints(overlayLayer)
        if frame.SetPushedTexture then frame:SetPushedTexture(pushed) end
        frame:RegisterForClicks("AnyUp", "AnyDown")
    end

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local data = self.iconData
        if not data or data.useTooltip == false then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if data.type == "spell" then GameTooltip:SetSpellByID(data.id)
        elseif data.type == "item" then GameTooltip:SetItemByID(data.id)
        elseif data.type == "macro" then
            GameTooltip:AddLine(data.label or "매크로", 1, 1, 1)
            if data.macrotext then GameTooltip:AddLine(data.macrotext, 0.7, 0.7, 0.7, true) end
        elseif data.type == "housing" then
            local canReturn = C_HousingNeighborhood and C_HousingNeighborhood.CanReturnAfterVisitingHouse()
            local text = canReturn and _G.HOUSING_DASHBOARD_RETURN or _G.HOUSING_DASHBOARD_TELEPORT_TO_PLOT
            GameTooltip:AddLine(text, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 상태 업데이트
    function frame:UpdateStatus()
        local data = self.iconData
        if not data then return end

        local color = (type(data.fontcolor) == "string" and fontColorTable[data.fontcolor]) or data.fontcolor or fontColorTable.white
        local isKnown = true

        -- 업데이트
        local startTime, duration = 0, 0
        if data.type == "spell" then
            isKnown = C_SpellBook.IsSpellInSpellBook(data.id) or C_SpellBook.IsSpellKnown(data.id)
            local cd = C_Spell.GetSpellCooldown(data.id)
            if cd then
                if issecretvalue(cd.startTime) or issecretvalue(cd.duration) then
                    startTime, duration = 0, 0
                else
                    startTime, duration = cd.startTime or 0, cd.duration or 0
                end
            end
        elseif data.type == "item" then
            local count = C_Item.GetItemCount(data.id)
            self.Count:SetText(count > 1 and count or "")
            isKnown = (count > 0) or (C_ToyBox and C_ToyBox.GetToyInfo(data.id))
            startTime, duration = C_Item.GetItemCooldown(data.id)
            if issecretvalue(startTime) or issecretvalue(duration) then
                startTime, duration = 0, 0
            else
                startTime, duration = startTime or 0, duration or 0
            end
        elseif data.type == "macro" then
            isKnown = true
            self.Count:SetText(""); self.cooldown:Clear()
        elseif data.type == "housing" then
            isKnown = true
            self.Count:SetText("")
            local canReturn = C_HousingNeighborhood and C_HousingNeighborhood.CanReturnAfterVisitingHouse()
            
            if not InCombatLockdown() then
                if canReturn then
                    self:SetAttribute("type", "returnhome")
                    self:SetAttribute("house-neighborhood-guid", nil)
                    self:SetAttribute("house-guid", nil)
                    self:SetAttribute("house-plot-id", nil)
                else
                    self:SetAttribute("type", "teleporthome")
                    local houses = dodo.houseData
                    local houseInfo
                    if houses and #houses > 0 then
                        -- TeleportMenu와 동일하게 팩션에 따른 하우징 인덱스 선택
                        if #houses == 1 or UnitFactionGroup("player") == "Alliance" then
                            houseInfo = houses[1]
                        else
                            houseInfo = houses[2] or houses[1]
                        end
                        
                        if houseInfo then
                            self:SetAttribute("house-neighborhood-guid", houseInfo.neighborhoodGUID)
                            self:SetAttribute("house-guid", houseInfo.houseGUID)
                            self:SetAttribute("house-plot-id", houseInfo.plotID)
                        end
                    end
                end
            end

            if canReturn then
                self.icon:SetAtlas("dashboard-panel-homestone-teleport-out-button")
            else
                local spellTexture = C_Spell and C_Spell.GetSpellTexture(1263273)
                self.icon:SetTexture(spellTexture or data.icon or 134400)
            end

            local cdInfo = C_Housing and C_Housing.GetVisitCooldownInfo and C_Housing.GetVisitCooldownInfo()
            if cdInfo and cdInfo.isEnabled and not canReturn then
                if issecretvalue(cdInfo.startTime) or issecretvalue(cdInfo.duration) then
                    startTime, duration = 0, 0
                else
                    startTime, duration = cdInfo.startTime, cdInfo.duration
                end
            else
                startTime, duration = 0, 0
            end
        end

        self.cooldown:SetCooldown(startTime, duration) -- 쿨타임
        local finalColor = not isKnown and fontColorTable.gray or color
        SetTextColorFromTable(self.Name, finalColor) -- 글자색
        self.icon:SetDesaturated(not isKnown) -- 흑백
    end

    -- 테이블 적용
    function frame:ApplyConfig(data)
        if InCombatLockdown() and data.isAction then return end
        self.iconData = data

        if data.isAction then
            self:SetAttribute("type", nil); self:SetAttribute("spell", nil)
            self:SetAttribute("item", nil); self:SetAttribute("macrotext", nil)
            self:SetAttribute("house-neighborhood-guid", nil)
            self:SetAttribute("house-guid", nil)
            self:SetAttribute("house-plot-id", nil)
        end

        if data.type == "spell" then
            if data.isAction then self:SetAttribute("type", "spell"); self:SetAttribute("spell", data.id) end
            local info = C_Spell.GetSpellInfo(data.id)
            self.icon:SetTexture(data.icon or (info and info.iconID) or 132311)
        elseif data.type == "item" then
            if data.isAction then self:SetAttribute("type", "item"); self:SetAttribute("item", "item:" .. data.id) end
            local icon = C_Item.GetItemIconByID(data.id)
            if icon then self.icon:SetTexture(data.icon or icon) end
            local item = Item:CreateFromItemID(data.id)
            item:ContinueOnItemLoad(function()
                if not data.icon then self.icon:SetTexture(item:GetItemIcon()) end
                if not data.label then self.Name:SetText(item:GetItemName()) end
                self:UpdateStatus()
            end)
        elseif data.type == "macro" then
            if data.isAction then self:SetAttribute("type", "macro"); self:SetAttribute("macrotext", data.macrotext) end
            self.icon:SetTexture(data.icon or 134400)
        elseif data.type == "housing" then
            -- 상태와 아이콘은 UpdateStatus에서 동적으로 처리합니다.
        end

        if data.iconposition then
            local p = data.iconposition
            local rel = (type(p[2]) == "string" and _G[p[2]]) or UIParent
            self:ClearAllPoints(); self:SetPoint(p[1], rel, p[3], p[4], p[5])
        end

        if data.label then self.Name:SetText(data.label) end
        local font, fSize = self.Name:GetFont()
        self.Name:SetFont(font, data.fontsize or fSize, data.outline and "OUTLINE" or nil)

        self.Name:ClearAllPoints()
        if data.fontposition then
            local fp = data.fontposition
            local fRel = (fp[2] == "self" and self) or (type(fp[2]) == "string" and _G[fp[2]]) or self
            self.Name:SetPoint(fp[1], fRel, fp[3] or fp[1], fp[4] or 0, fp[5] or 0)
        else
            self.Name:SetPoint("TOP", self, "BOTTOM", 0, -2)
        end

        if data.cooldownSize then
            for _, region in ipairs({self.cooldown:GetRegions()}) do
                if region:GetObjectType() == "FontString" then
                    local f, _, o = region:GetFont()
                    region:SetFont(f, data.cooldownSize, "OUTLINE")
                end
            end
        end

        self:SetFrameStrata(data.framestrata or "LOW")
        self:UpdateStatus()
    end
    return frame
end