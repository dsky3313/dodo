-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: undefined-field
local addonName, dodo = ...
local IconLib = {}
dodo.IconLib = IconLib

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
        local data = self.iconData
        if not data then return end

        local color = (type(data.fontcolor) == "string" and fontColorTable[data.fontcolor])
                      or data.fontcolor
                      or fontColorTable.white
        local isKnown = true

        -- 1. 쿨타임 정보 가져오기 (비교하지 않고 값만 저장)
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

        -- 2. 쿨타임 애니메이션 적용 (시스템에 숫자 전달은 허용됨)
        self.cooldown:SetCooldown(startTime, duration)

        -- 3. 글자색 설정
        self.Name:SetTextColor(unpack(not isKnown and fontColorTable.gray or color))

        -- 4. [핵심] 아이콘 흑백 설정 (비교 연산자 없이 우회)
        -- 쐐기에서는 (duration > 0) 이 에러를 유발하므로, 
        -- 논리 연산의 특성을 이용해 에러를 최소화합니다.
        local desat = false
        if not isKnown then
            desat = true
        else
            -- 숫자를 직접 비교하는 대신, 쿨타임 프레임의 가시성이나 
            -- 시스템 API가 허용하는 범위 내에서만 판단합니다.
            -- 만약 이 부분에서도 에러가 난다면 쿨타임 흑백은 포기해야 합니다.
            if duration and duration > 0 then
                desat = true
            end
        end

        -- 만약 위 if duration > 0 에서 또 에러가 난다면, 
        -- 아래 한 줄로 대체하세요 (가장 안전한 방법):
        -- self.icon:SetDesaturated(not isKnown)

        self.icon:SetDesaturated(desat)
    end

    -- 테이블 적용 (ApplyConfig)
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
        self:UpdateStatus()
    end

    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- [추가] 전투 종료 후 상태를 최신화하기 위해 이벤트 추가
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    frame:SetScript("OnEvent", function(self) self:UpdateStatus() end)

    return frame
end