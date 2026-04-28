-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: undefined-field
local addonName, dodo = ...
local IconLib = {}
dodo.IconLib = IconLib

local function isIns()
    local _, instanceType = GetInstanceInfo()
    return IsInInstance() or (instanceType ~= "none")
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
function IconLib:Create(name, parent, config)
    local isAction = config and config.isAction or false
    local template = isAction and "SecureActionButtonTemplate" or nil
    local frameType = isAction and "CheckButton" or "Frame"
    local frame = CreateFrame(frameType, name, parent or UIParent, template)
    local size = config and config.iconsize or {40, 40}

    -- 아이콘 크기, 레이아웃
    frame:SetSize(size[1], size[2])
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    function frame:RescaleIcon()
        local width = self:GetWidth()
        local margin = math.max(2, width * 0.07)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", margin, -margin)
        self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -margin, margin)
    end
    frame:RescaleIcon()

    frame.normalTexture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.normalTexture:SetAtlas("UI-HUD-ActionBar-IconFrame")
    frame.normalTexture:SetAllPoints(frame)

    frame.cooldown = CreateFrame("Cooldown", name .. "Cooldown", frame, "CooldownFrameTemplate")
    frame.cooldown:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", 0, 0)
    frame.cooldown:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 0, 0)
    frame.cooldown:SetFrameLevel(frame:GetFrameLevel())
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetDrawSwipe(true)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.8)

    frame.Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    frame.Count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

    if isAction then
        local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        highlight:SetAlpha(0.5); highlight:SetBlendMode("ADD"); highlight:SetAllPoints(frame)
        local pushed = frame:CreateTexture(nil, "OVERLAY")
        pushed:SetAtlas("UI-HUD-ActionBar-IconFrame-Down")
        pushed:SetAlpha(0.5); pushed:SetBlendMode("ADD"); pushed:SetAllPoints(frame)
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
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 상태 업데이트
    function frame:UpdateStatus()
        if isIns() then
            if self.cooldown then self.cooldown:Clear() end return
        end

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
                startTime, duration = cd.startTime or 0, cd.duration or 0
            end
        elseif data.type == "item" then
            local count = C_Item.GetItemCount(data.id)
            self.Count:SetText(count > 1 and count or "")
            isKnown = (count > 0) or (C_ToyBox and C_ToyBox.GetToyInfo(data.id))
            startTime, duration = C_Item.GetItemCooldown(data.id)
            startTime, duration = startTime or 0, duration or 0
        elseif data.type == "macro" then
            isKnown = true
            self.Count:SetText(""); self.cooldown:Clear()
        end

        self.cooldown:SetCooldown(startTime, duration) -- 쿨타임
        self.Name:SetTextColor(unpack(not isKnown and fontColorTable.gray or color)) -- 글자색
        self.icon:SetDesaturated(not isKnown) -- 흑백
    end

    -- 테이블 적용
    function frame:ApplyConfig(data)
        if InCombatLockdown() and data.isAction then return end
        self.iconData = data

        if data.isAction then
            self:SetAttribute("type", nil); self:SetAttribute("spell", nil)
            self:SetAttribute("item", nil); self:SetAttribute("macrotext", nil)
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

        self:SetFrameStrata(data.framestrata or "HIGH")
        if not isIns() then self:UpdateStatus() end
    end
    return frame
end