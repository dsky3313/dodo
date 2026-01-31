------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...
local IconLib = {}
dodo.IconLib = IconLib

function IconLib:Create(name, parent, config)
    local isAction = config and config.isAction or false
    local template = isAction and "SecureActionButtonTemplate" or nil
    local frameType = isAction and "CheckButton" or "Frame"
    local frame = CreateFrame(frameType, name, parent or UIParent, template)
    local size = config and config.iconsize or {40, 40}

    local fontColorTable = {
    white = {1, 1, 1},
    yellow = {1, 0.82, 0},
    red = {1, 0.2, 0.2},
    green = {0.1, 1, 0.1},
    orange = {1, 0.5, 0},
    gray = {0.5, 0.5, 0.5},
    }

    -- 아이콘 크기
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

    -- 아이콘 텍스쳐
    frame.normalTexture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.normalTexture:SetAtlas("UI-HUD-ActionBar-IconFrame")
    frame.normalTexture:SetAllPoints(frame)

    -- 아이콘 쿨다운
    frame.cooldown = CreateFrame("Cooldown", name .. "Cooldown", frame, "CooldownFrameTemplate")
    frame.cooldown:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", 0, 0)
    frame.cooldown:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 0, 0)
    frame.cooldown:SetFrameLevel(frame:GetFrameLevel())
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetDrawSwipe(true)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.8)

    -- 아이콘 글꼴
    frame.Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    frame.Count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

    if isAction then -- 클릭가능
        local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        highlight:SetAlpha(0.5); highlight:SetBlendMode("ADD"); highlight:SetAllPoints(frame)

        local pushed = frame:CreateTexture(nil, "OVERLAY")
        pushed:SetAtlas("UI-HUD-ActionBar-IconFrame-Down")
        pushed:SetAlpha(0.5); pushed:SetBlendMode("ADD"); pushed:SetAllPoints(frame)
        if frame.SetPushedTexture then frame:SetPushedTexture(pushed) end

        frame:RegisterForClicks("AnyUp", "AnyDown")
    end

    -- 상태 업데이트
    function frame:UpdateStatus()
        local data = self.iconData
        if not data then return end

        local isKnown, isOnCooldown = true, false
        local fontColor = (type(data.fontcolor) == "string" and fontColorTable[data.fontcolor])
                      or data.fontcolor or fontColorTable.white

        if data.type == "spell" then
            isKnown = C_SpellBook.IsSpellInSpellBook(data.id) or C_SpellBook.IsSpellKnown(data.id)
            local cd = C_Spell.GetSpellCooldown(data.id)
            if cd and cd.isEnabled and cd.duration > 0 then
                self.cooldown:SetCooldown(cd.startTime, cd.duration)
                isOnCooldown = true
            else self.cooldown:Clear() end
        elseif data.type == "item" then
            local count = C_Item.GetItemCount(data.id)
            self.Count:SetText(count > 1 and count or "")
            isKnown = (count > 0) or (C_ToyBox and C_ToyBox.GetToyInfo(data.id))
            local start, duration = C_Item.GetItemCooldown(data.id)
            if start and start > 0 and duration > 0 then
                self.cooldown:SetCooldown(start, duration)
                isOnCooldown = true
            else self.cooldown:Clear() end
        end

        -- 색상 적용 (배우지 않았으면 회색, 아니면 지정된 색상)
        if not isKnown then
            self.Name:SetTextColor(unpack(fontColorTable.gray))
        else
            self.Name:SetTextColor(unpack(fontColor))
        end

        self.icon:SetDesaturated(not isKnown or isOnCooldown)
    end

    -- 테이블 적용 (ApplyConfig)
    function frame:ApplyConfig(data)
        if InCombatLockdown() and data.isAction then return end
        self.iconData = data

        -- 속성 초기화 및 재설정 (생략)
        if data.isAction then
            self:SetAttribute("type", nil)
            self:SetAttribute("spell", nil)
            self:SetAttribute("item", nil)
            self:SetAttribute("macrotext", nil)
        end

        if data.type == "spell" then
            if data.isAction then
                self:SetAttribute("type", "spell")
                self:SetAttribute("spell", data.id)
            end
            local info = C_Spell.GetSpellInfo(data.id)
            self.icon:SetTexture(data.icon or (info and info.iconID) or 132311)
        elseif data.type == "item" then
            if data.isAction then
                self:SetAttribute("type", "item")
                self:SetAttribute("item", "item:" .. data.id)
            end
            local icon = C_Item.GetItemIconByID(data.id)
            if icon then self.icon:SetTexture(data.icon or icon) end
            local item = Item:CreateFromItemID(data.id)
            item:ContinueOnItemLoad(function()
                if not data.icon then self.icon:SetTexture(item:GetItemIcon()) end
                if not data.label then self.Name:SetText(item:GetItemName()) end
                self:UpdateStatus()
            end)
        elseif data.type == "macro" then
            if data.isAction then 
                self:SetAttribute("type", "macro")
                self:SetAttribute("macrotext", data.macrotext)
            end
            self.icon:SetTexture(data.icon or 134400)
        end

        -- 위치, 폰트, Strata 설정
        if data.iconposition then
            local p = data.iconposition
            local rel = (type(p[2]) == "string" and _G[p[2]]) or UIParent
            self:ClearAllPoints()
            self:SetPoint(p[1], rel, p[3], p[4], p[5])
        end

        if data.label then self.Name:SetText(data.label) end
        local font, fSize = self.Name:GetFont()
        self.Name:SetFont(font, data.fontsize or fSize, data.outline and "OUTLINE" or nil)
        
        -- 폰트 위치 설정
        self.Name:ClearAllPoints()
        if data.fontposition then
            local fp = data.fontposition
            local fRel = (fp[2] == "self" and self) or (type(fp[2]) == "string" and _G[fp[2]]) or self
            self.Name:SetPoint(fp[1], fRel, fp[3] or fp[1], fp[4] or 0, fp[5] or 0)
        else
            self.Name:SetPoint("TOP", self, "BOTTOM", 0, -2)
        end

        -- 쿨다운 숫자 크기
        if data.cooldownSize then
            for _, region in ipairs({self.cooldown:GetRegions()}) do
                if region:GetObjectType() == "FontString" then
                    local f, _, o = region:GetFont()
                    region:SetFont(f, data.cooldownSize, "OUTLINE")
                end
            end
        end

        self:SetFrameStrata(data.framestrata or "HIGH")
        self:UpdateStatus()
    end

    frame:SetScript("OnEvent", frame.UpdateStatus)
    return frame
end

--[[ 설정테이블
local BobberConfig = {
    isAction = true,
    type = "item",
    -- macrotext = "/cast 낚시\n/use 13",
    id = 202207,
    icon = nil,
    iconsize = {34, 34},
    iconposition = {"TOPLEFT", "SecondaryProfession2", "TOPLEFT", 250, -7},
    label = "낚시찌",
    fontsize = 12,
    fontposition = {"BOTTOMRIGHT", "self", "BOTTOMLEFT", -2, 2},
    fontcolor = "yellow",
    cooldownSize = 12,
    outline = false,
    framestrata = "HIGH",
}
]]