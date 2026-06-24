---@diagnostic disable: redundant-parameter
-- ==============================
-- Inspired
-- ==============================
-- asDebuffFilter (https://www.curseforge.com/wow/addons/asdebufffilter)
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local configs = {
    size           = 56,
    sizerate       = 1,
    max_debuffs    = 6,
    max_private    = 6,
    gap            = 2,    -- 아이콘 간격
    cool_size      = 50,   -- 쿨다운 크기
    cool_fontsize  = 18,   -- 쿨다운
    cool_x         = 0,
    cool_y         = 0,
    count_fontsize = 18,   -- 스택
    count_x        = 0,
    count_y        = 0,
    dispel_size    = 20,   -- 해제 아이콘
    dispel_x       = 1,
    dispel_y       = 1,
    clickthrough   = false, -- 클릭 무시 (true시 뒤에 있는 NPC 클릭 가능)
}

local Options_Default = {
    Version = 1,
    xpoint  = 350,         -- 위치
    ypoint  = 0,
}

-- dodo.Colors.Debuff 데이터베이스 동적 참조 매핑 (중앙화 지원)
local debuffinfo = {}
if dodo.Colors and dodo.Colors.Debuff then
    for dispeltype, v in pairs(dodo.Colors.Debuff) do
        debuffinfo[dispeltype] = CreateColor(v.r, v.g, v.b)
    end
else
    debuffinfo = {
        [0]  = CreateColor(0.80, 0.80, 0.80), -- 일반 디버프
        [1]  = CreateColor(0.32, 0.66, 1.00), -- Magic (파랑)
        [2]  = CreateColor(0.67, 0.16, 1.00), -- Curse (보라)
        [3]  = CreateColor(0.70, 0.47, 0.00), -- Disease (노랑/갈색)
        [4]  = CreateColor(0.00, 1.00, 0.00), -- Poison (녹색)
        [9]  = CreateColor(1.00, 0.29, 0.17), -- Bleed (붉은 갈색)
        [11] = CreateColor(1.00, 0.16, 0.16), -- Bleed (붉은 갈색)
    }
end

local filterList = {
    [26013]  = true, -- 탈영병 (Deserter)
    [71041]  = true, -- 탈영병 (Deserter - 인스턴스)
    [57723]  = true, -- 소진 (Exhaustion - 영웅심)
    [57724]  = true, -- 만족함 (Sated - 피의 욕망)
    [80354]  = true, -- 시간 변위 (Temporal Displacement - 시간 왜곡)
    [95809]  = true, -- 포만감 (Ancient Hysteria - 고대 광분)
    [160455] = true, -- 만족함 (Insanity - 북)
    [264689] = true, -- 피로 (Fatigued - 원초적 분노)
    [390435] = true, -- 탈진 (Aspects' Benevolence - 위상의 격노)
    [97821]  = true, -- 죽기 디버프
}

-- ==============================
-- 캐싱
-- ==============================
local CopyTable = CopyTable
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local ipairs = ipairs
local math_max = math.max
local next = next
local pairs = pairs
local type = type

local GetTime = GetTime

local activeDebuffs = {}
local activeDebuffsCache = {}
local is_preview_active = false
local bsetupprivate = false
local debuff_frame
local debufffilter = AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful)
local main_frame = CreateFrame("Frame", nil, UIParent)
local private_frame
local DISPEL_TYPE_NAMES = { "Magic", "Curse", "Disease", "Poison", "Bleed" } -- 해제 타입 이름 (상수)

local isSecretValue = issecretvalue or function() return false end

local colorcurve = C_CurveUtil.CreateColorCurve()
colorcurve:SetType(Enum.LuaCurveType.Step)
for dispeltype, v in pairs(debuffinfo) do
    colorcurve:AddPoint(dispeltype, v)
end

-- 탐지용 커브 생성 도우미 함수 (비교 연산 에러 방지용)
local function create_dispel_curve(type_id, alt_type_id)
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(0, 0, 0, 0))
    curve:AddPoint(type_id, CreateColor(1, 1, 1, 1))
    curve:AddPoint(type_id + 1, CreateColor(0, 0, 0, 0))
    if alt_type_id then
        curve:AddPoint(alt_type_id, CreateColor(1, 1, 1, 1))
        curve:AddPoint(alt_type_id + 1, CreateColor(0, 0, 0, 0))
    end
    return curve
end

local detect_curves = {
    Magic   = create_dispel_curve(1),
    Curse   = create_dispel_curve(2),
    Disease = create_dispel_curve(3),
    Poison  = create_dispel_curve(4),
    Bleed   = create_dispel_curve(9, 11),
}

-- ==============================
-- Private Aura Mixin
-- ==============================
dodo_PrivateAuraAnchorMixin = {}

function dodo_PrivateAuraAnchorMixin:SetUnit(unit)
    if unit == self.unit then
        return
    end
    self.unit = unit

    if self.anchorID then
        C_UnitAuras.RemovePrivateAuraAnchor(self.anchorID)
        self.anchorID = nil
    end

    if unit then
        local iconAnchor = {
            point         = "CENTER",
            relativeTo    = self,
            relativePoint = "CENTER",
            offsetX       = 0,
            offsetY       = 0,
        }

        local args = {}
        args.unitToken            = unit
        args.auraIndex            = self.auraIndex
        args.parent               = self
        args.showCountdownFrame   = true
        args.showCountdownNumbers = true
        args.isContainer          = false
        args.iconInfo = {
            iconAnchor  = iconAnchor,
            iconWidth   = self:GetWidth(),
            iconHeight  = self:GetHeight(),
            borderScale = 2.0,
        }
        args.durationAnchor = nil

        self.anchorID = C_UnitAuras.AddPrivateAuraAnchor(args)
    end
end

-- ==============================
-- 마우스 오버 툴팁 정적 핸들러 (가비지 프리)
-- ==============================
local function on_debuff_enter(self)
    if self.auraid then
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnitDebuffByAuraInstanceID(self.unit, self.auraid, debufffilter)
    end
end

local function on_debuff_leave()
    GameTooltip:Hide()
end

-- ==============================
-- UI 생성
-- ==============================
local function create_debuff_frames(parent)
    if parent.frames == nil then
        parent.frames = {}
    end

    local w = configs.size
    local h = configs.size * configs.sizerate

    for idx = 1, 6 do  -- 슬라이더 maxVal=6 고정, 항상 최대치 생성
        local frame = CreateFrame("Button", nil, parent, "dodo_DebuffFrameTemplate")
        parent.frames[idx] = frame

        frame.cooldown:SetDrawEdge(false)
        frame.cooldown:SetDrawSwipe(true)
        frame.cooldown:SetHideCountdownNumbers(false)
        frame.cooldown:ClearAllPoints()
        frame.cooldown:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
        frame.cooldown:SetSize(configs.cool_size, configs.cool_size)
        for _, r in next, { frame.cooldown:GetRegions() } do
            if r:GetObjectType() == "FontString" then
                r:SetFont(STANDARD_TEXT_FONT, configs.cool_fontsize, "OUTLINE")
                r:ClearAllPoints()
                r:SetPoint("CENTER", configs.cool_x, configs.cool_y)
                r:SetDrawLayer("OVERLAY")
                break
            end
        end

        frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame.icon:ClearAllPoints()
        frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
        frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        frame:SetSize(w, h)
        frame:ClearAllPoints()

        -- border/dispel/count 전용 오버레이 프레임 (swipe 501 위)
        local overlayLayer = CreateFrame("Frame", nil, frame)
        overlayLayer:SetAllPoints(frame)
        overlayLayer:SetFrameLevel(frame:GetFrameLevel() + 2)
        frame.overlayLayer = overlayLayer

        frame.border:SetParent(overlayLayer)
        frame.border:SetDrawLayer("ARTWORK")
        frame.border:ClearAllPoints()
        frame.border:SetPoint("CENTER", overlayLayer, "CENTER", 0, 0)
        frame.border:SetSize(w, h)

        frame.count:SetParent(overlayLayer)
        frame.count:SetDrawLayer("OVERLAY")
        frame.count:SetFont(STANDARD_TEXT_FONT, configs.count_fontsize, "OUTLINE")
        frame.count:ClearAllPoints()
        frame.count:SetPoint("BOTTOMRIGHT", overlayLayer, "BOTTOMRIGHT", configs.count_x, configs.count_y)
        frame.count:SetTextColor(1, 1, 0)

        -- 해제 타입 아이콘 설정
        for _, name in ipairs(DISPEL_TYPE_NAMES) do
            local dispelIcon = frame["dispel" .. name]
            if dispelIcon then
                dispelIcon:SetParent(overlayLayer)
                dispelIcon:SetDrawLayer("OVERLAY")
                dispelIcon:SetSize(configs.dispel_size, configs.dispel_size)
                dispelIcon:ClearAllPoints()
                dispelIcon:SetPoint("TOPRIGHT", overlayLayer, "TOPRIGHT", configs.dispel_x, configs.dispel_y)
            end
        end

        if idx == 1 then
            frame:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
        else
            frame:SetPoint("RIGHT", parent.frames[idx - 1], "LEFT", -configs.gap, 0)
        end

        frame:SetScript("OnEnter", on_debuff_enter)
        frame:SetScript("OnLeave", on_debuff_leave)

        -- 마우스 설정 (초기)
        if configs.clickthrough then
            frame:EnableMouse(true)
            if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
        else
            frame:EnableMouse(true)
        end
        frame:Hide()
    end
end

local function create_private_frames(parent)
    if parent.PrivateAuraAnchors == nil then
        parent.PrivateAuraAnchors = {}
    end

    if UnitAffectingCombat("player") then
        return
    end

    bsetupprivate = true

    local w = configs.size
    local h = configs.size * configs.sizerate

    for idx = 1, configs.max_private do
        local frame = CreateFrame("Frame", nil, parent, "dodo_PrivateAuraAnchorTemplate")
        parent.PrivateAuraAnchors[idx] = frame

        frame.auraIndex = idx
        frame:SetSize(w, h)
        frame:ClearAllPoints()
        frame:SetFrameStrata("LOW")
        frame:SetFrameLevel(500)

        -- private는 왼쪽에서 오른쪽으로 (중앙 기준 오른쪽으로 뻗어나감)
        if idx == 1 then
            frame:SetPoint("LEFT", parent, "LEFT", 0, 0)
        else
            frame:SetPoint("LEFT", parent.PrivateAuraAnchors[idx - 1], "RIGHT", configs.gap, 0)
        end

        frame:SetUnit("player")
    end
end

-- ==============================
-- 디버프 로직
-- ==============================

local function set_cooldownframe(cooldown, durationobject, enable)
    if enable and durationobject then
        cooldown:SetCooldownFromDurationObject(durationobject)
        cooldown:Show()
    else
        cooldown:Clear()
        cooldown:Hide()
    end
end

local function update_debuff_frames()
    if UnitIsDeadOrGhost("player") then
        if debuff_frame and debuff_frame.frames then
            for j = 1, 6 do
                if debuff_frame.frames[j] then debuff_frame.frames[j]:Hide() end
            end
        end
        return
    end

    local is_enabled = (dodoDB and dodoDB.useDebuff ~= false)
    if not is_enabled then
        if debuff_frame and debuff_frame.frames then
            for j = 1, configs.max_debuffs do
                if debuff_frame.frames[j] then
                    debuff_frame.frames[j]:Hide()
                end
            end
        end
        return
    end

    local auraList = activeDebuffs["player"]
    if not auraList then return end

    local shown = 0

    for _, aura in ipairs(auraList) do
        shown = shown + 1
        if shown > configs.max_debuffs then
            break
        end

        local frame = debuff_frame.frames[shown]
        if not frame then break end
        frame.unit   = "player"
        frame.auraid = aura.auraInstanceID

        frame.icon:SetTexture(aura.icon)
        frame.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount("player", aura.auraInstanceID, 1, 100))

        local durationobject = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID)
        set_cooldownframe(frame.cooldown, durationobject, true)

        local color = C_UnitAuras.GetAuraDispelTypeColor("player", aura.auraInstanceID, colorcurve)
        if color then
            frame.border:SetVertexColor(color.r, color.g, color.b)
        else
            frame.border:SetVertexColor(0, 0, 0)
        end

        -- 각 타입별 디버프 아이콘 처리 (비교 연산 없이 알파값으로 제어)
        for _, name in ipairs(DISPEL_TYPE_NAMES) do
            local detectColor = C_UnitAuras.GetAuraDispelTypeColor("player", aura.auraInstanceID, detect_curves[name])
            local dispelIcon = frame["dispel" .. name]
            if dispelIcon then
                dispelIcon:SetAlpha(detectColor and detectColor.a or 0)
                dispelIcon:Show()
            end
        end

        frame:Show()
    end

    for j = shown + 1, configs.max_debuffs do
        if debuff_frame.frames[j] then
            debuff_frame.frames[j]:Hide()
        end
    end
end

local function update_auras(updateInfo)
    if is_preview_active then return end
    if not updateInfo or updateInfo.isFullUpdate then
        -- 전체 재스캔
        local auras = C_UnitAuras.GetUnitAuras("player", debufffilter)
        table.wipe(activeDebuffsCache)
        if auras then
            for _, aura in ipairs(auras) do
                local sid = aura.spellId
                local isFiltered = false
                if sid then
                    if not isSecretValue(sid) and filterList[sid] then
                        isFiltered = true
                    end
                end
                if not isFiltered then
                    table.insert(activeDebuffsCache, aura)
                    if #activeDebuffsCache >= configs.max_debuffs then break end
                end
            end
        end
    else
        -- 부분 갱신: 삭제 처리
        if updateInfo.removedAuraInstanceIDs then
            for _, removedID in ipairs(updateInfo.removedAuraInstanceIDs) do
                for i = #activeDebuffsCache, 1, -1 do
                    if activeDebuffsCache[i].auraInstanceID == removedID then
                        table.remove(activeDebuffsCache, i)
                        break
                    end
                end
            end
        end
        -- 부분 갱신: 추가 처리
        if updateInfo.addedAuras then
            for _, aura in ipairs(updateInfo.addedAuras) do
                if aura.isHarmful and #activeDebuffsCache < configs.max_debuffs then
                    local sid = aura.spellId
                    local isFiltered = false
                    if sid then
                        if not isSecretValue(sid) and filterList[sid] then
                            isFiltered = true
                        end
                    end
                    if not isFiltered then
                        table.insert(activeDebuffsCache, aura)
                    end
                end
            end
        end
    end

    activeDebuffs["player"] = activeDebuffsCache
    update_debuff_frames()
end

local function show_preview_data()
    is_preview_active = true

    local fake_debuffs = {
        { icon = 135900, count = 1, dispel = "Magic", color = debuffinfo[1], duration = 15 },
        { icon = 136121, count = 2, dispel = "Curse", color = debuffinfo[2], duration = 10 },
        { icon = 135869, count = 0, dispel = "Disease", color = debuffinfo[3], duration = 8 },
        { icon = 135925, count = 5, dispel = "Poison", color = debuffinfo[4], duration = 12 },
        { icon = 132242, count = 0, dispel = "Bleed", color = debuffinfo[9], duration = 20 },
        { icon = 136183, count = 0, dispel = nil, color = debuffinfo[0], duration = 0 },
    }

    if debuff_frame and debuff_frame.frames then
        for i = 1, configs.max_debuffs do
            local frame = debuff_frame.frames[i]
            local data = fake_debuffs[i]
            if frame and data then
                frame.unit = "player"
                frame.auraid = nil
                frame.icon:SetTexture(data.icon)
                
                if data.count > 0 then
                    frame.count:SetText(data.count)
                else
                    frame.count:SetText("")
                end

                if data.duration > 0 then
                    frame.cooldown:SetCooldown(GetTime(), data.duration)
                    frame.cooldown:Show()
                else
                    frame.cooldown:Clear()
                    frame.cooldown:Hide()
                end

                if data.color then
                    frame.border:SetVertexColor(data.color.r, data.color.g, data.color.b)
                else
                    frame.border:SetVertexColor(0, 0, 0)
                end

                for _, name in ipairs(DISPEL_TYPE_NAMES) do
                    local dispelIcon = frame["dispel" .. name]
                    if dispelIcon then
                        if name == data.dispel then
                            dispelIcon:SetAlpha(1)
                        else
                            dispelIcon:SetAlpha(0)
                        end
                        dispelIcon:Show()
                    end
                end
                frame:Show()
            end
        end
        for j = configs.max_debuffs + 1, #debuff_frame.frames do
            if debuff_frame.frames[j] then debuff_frame.frames[j]:Hide() end
        end
    end

    if private_frame and private_frame.PrivateAuraAnchors then
        local fake_private = {
            { icon = 136209, duration = 12 },
        }

        for i = 1, configs.max_private do
            local frame = private_frame.PrivateAuraAnchors[i]
            local data = (i == 1) and fake_private[1] or nil
            if frame then
                if data then
                    if not frame.previewIcon then
                        frame.previewIcon = frame:CreateTexture(nil, "BACKGROUND")
                        frame.previewIcon:SetAllPoints(true)
                        frame.previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    end
                    frame.previewIcon:SetTexture(data.icon)
                    frame.previewIcon:Show()

                    if not frame.previewBorder then
                        frame.previewBorder = frame:CreateTexture(nil, "ARTWORK")
                        frame.previewBorder:SetTexture("Interface\\Addons\\dodo\\Media\\Texture\\AuraBorder.tga")
                        frame.previewBorder:SetAllPoints(true)
                    end
                    frame.previewBorder:SetVertexColor(1, 0.5, 0)
                    frame.previewBorder:Show()

                    if not frame.previewCooldown then
                        frame.previewCooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
                        frame.previewCooldown:SetAllPoints(true)
                        frame.previewCooldown:SetReverse(true)
                        frame.previewCooldown:SetDrawEdge(false)
                        frame.previewCooldown:SetHideCountdownNumbers(false)
                    end
                    if data.duration > 0 then
                        frame.previewCooldown:SetCooldown(GetTime(), data.duration)
                        frame.previewCooldown:Show()
                    else
                        frame.previewCooldown:Clear()
                        frame.previewCooldown:Hide()
                    end
                else
                    if frame.previewIcon then frame.previewIcon:Hide() end
                    if frame.previewBorder then frame.previewBorder:Hide() end
                    if frame.previewCooldown then
                        frame.previewCooldown:Clear()
                        frame.previewCooldown:Hide()
                    end
                    if frame.previewBg then frame.previewBg:Hide() end
                end
            end
        end
    end
end

local function hide_preview_data()
    is_preview_active = false

    if private_frame and private_frame.PrivateAuraAnchors then
        for i = 1, configs.max_private do
            local frame = private_frame.PrivateAuraAnchors[i]
            if frame then
                if frame.previewIcon then frame.previewIcon:Hide() end
                if frame.previewBorder then frame.previewBorder:Hide() end
                if frame.previewCooldown then
                    frame.previewCooldown:Clear()
                    frame.previewCooldown:Hide()
                end
                if frame.previewBg then frame.previewBg:Hide() end
            end
        end
    end

    update_auras()
end

-- ==============================
-- 위치 저장 및 해제
-- ==============================
local function save_position()
    local x, y = main_frame:GetCenter()
    local scale = main_frame:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    local us = UIParent:GetEffectiveScale()
    local px = (x * scale - ux * us) / us
    local py = (y * scale - uy * us) / us
    dodoDB.Debuff = dodoDB.Debuff or {}
    dodoDB.Debuff.xpoint = px
    dodoDB.Debuff.ypoint = py
    dodoDB.debuffX = px
    dodoDB.debuffY = py
end

local function load_position()
    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("Debuff")
    if not main_frame then return end
    main_frame:ClearAllPoints()
    if anchorFrame then
        -- debuff(좌)가 private(우)보다 넓으므로 anchor center에서 우측으로 offset
        -- offset = (debuff_w - private_1slot_w) / 2
        local slot_w = configs.size + configs.gap
        local offset_x = slot_w * (configs.max_debuffs - 1) / 2
        main_frame:SetPoint("CENTER", anchorFrame, "CENTER", offset_x, 0)
    else
        local targetX = dodoDB.debuffX or (dodoDB.Debuff and dodoDB.Debuff.xpoint) or 350
        local targetY = dodoDB.debuffY or (dodoDB.Debuff and dodoDB.Debuff.ypoint) or 0
        main_frame:SetPoint("CENTER", UIParent, "CENTER", targetX, targetY)
    end
end

-- ==============================
-- 설정 업데이트 (설정창용)
-- ==============================
local function update_debuff_option()
    if not main_frame or not debuff_frame then return end

    configs.size = dodoDB.debuffSize or 56
    configs.max_debuffs = dodoDB.debuffMax or 6
    configs.cool_size = math_max(configs.size - 6, 10)

    if dodoDB.debuffClickthrough ~= nil then
        configs.clickthrough = dodoDB.debuffClickthrough
    else
        configs.clickthrough = true
    end

    load_position()

    local icon_w = configs.size
    local icon_h = configs.size * configs.sizerate
    local debuff_w = (icon_w + configs.gap) * configs.max_debuffs
    local private_w = (icon_w + configs.gap) * configs.max_private

    debuff_frame:SetSize(debuff_w, icon_h)
    if private_frame then
        private_frame:SetSize(private_w, icon_h)
    end

    for idx, frame in pairs(debuff_frame.frames) do
        frame:SetSize(icon_w, icon_h)
        if frame.border then frame.border:SetSize(icon_w, icon_h) end
        if frame.cooldown then frame.cooldown:SetSize(configs.cool_size, configs.cool_size) end

        frame:ClearAllPoints()
        if idx == 1 then
            frame:SetPoint("RIGHT", debuff_frame, "RIGHT", 0, 0)
        else
            frame:SetPoint("RIGHT", debuff_frame.frames[idx - 1], "LEFT", -configs.gap, 0)
        end

        if configs.clickthrough then
            frame:EnableMouse(true)
            if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
            if dodoDB.debuffClickthroughTooltip == false then
                if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(false) end
            else
                if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(true) end
            end
        else
            frame:EnableMouse(true)
            if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(true) end
            if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(true) end
        end
    end

    if private_frame and private_frame.PrivateAuraAnchors then
        for idx, frame in ipairs(private_frame.PrivateAuraAnchors) do
            frame:SetSize(icon_w, icon_h)
            frame:ClearAllPoints()
            if idx == 1 then
                frame:SetPoint("LEFT", private_frame, "LEFT", 0, 0)
            else
                frame:SetPoint("LEFT", private_frame.PrivateAuraAnchors[idx - 1], "RIGHT", configs.gap, 0)
            end
        end
    end

    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("Debuff")
    if anchorFrame then
        anchorFrame:SetSize(debuff_w + (icon_w + configs.gap) + configs.gap * 2, icon_h)
    end

    if is_preview_active then
        show_preview_data()
    end

    local is_enabled = (dodoDB and dodoDB.useDebuff ~= false)
    if is_enabled then
        main_frame:RegisterUnitEvent("UNIT_AURA", "player")
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        main_frame:RegisterEvent("PLAYER_LOGOUT")
        
        if private_frame and private_frame.PrivateAuraAnchors then
            for _, frame in ipairs(private_frame.PrivateAuraAnchors) do
                frame:SetUnit("player")
            end
        end
        update_auras()
    else
        main_frame:UnregisterAllEvents()
        
        if private_frame and private_frame.PrivateAuraAnchors then
            for _, frame in ipairs(private_frame.PrivateAuraAnchors) do
                frame:SetUnit(nil)
            end
        end
        
        if debuff_frame and debuff_frame.frames then
            for j = 1, configs.max_debuffs do
                if debuff_frame.frames[j] then
                    debuff_frame.frames[j]:Hide()
                end
            end
        end
    end
end

-- ==============================
-- 이벤트 핸들러 (가비지 프리 정적 참조)
-- ==============================
local function on_event(self, event, arg1, arg2)
    if event == "UNIT_AURA" and arg1 == "player" then
        update_auras(arg2)
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_auras()
        if not bsetupprivate then
            create_private_frames(private_frame)
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if not bsetupprivate then
            create_private_frames(private_frame)
        end
    elseif event == "PLAYER_LOGOUT" then
        save_position()
    end
end

-- ==============================
-- 초기화
-- ==============================
local function init_frames()
    if dodoDB.Debuff == nil or dodoDB.Debuff.Version ~= Options_Default.Version then
        dodoDB.Debuff = CopyTable(Options_Default)
    end

    configs.size = dodoDB.debuffSize or configs.size
    configs.max_debuffs = dodoDB.debuffMax or configs.max_debuffs
    if dodoDB.debuffClickthrough ~= nil then
        configs.clickthrough = dodoDB.debuffClickthrough
    end

    main_frame:SetFrameStrata("MEDIUM")
    main_frame:SetSize(1, 1)
    load_position()
    main_frame:Show()

    local icon_w = configs.size
    local icon_h = configs.size * configs.sizerate
    local debuff_w = (icon_w + configs.gap) * configs.max_debuffs
    local private_w = (icon_w + configs.gap) * configs.max_private

    debuff_frame = CreateFrame("Frame", nil, main_frame)
    debuff_frame:SetSize(debuff_w, icon_h)
    debuff_frame:SetPoint("RIGHT", main_frame, "CENTER", -configs.gap, 0)
    debuff_frame:Show()
    create_debuff_frames(debuff_frame)

    private_frame = CreateFrame("Frame", nil, main_frame)
    private_frame:SetSize(private_w, icon_h)
    private_frame:SetPoint("LEFT", main_frame, "CENTER", configs.gap, 0)
    private_frame:Show()
    create_private_frames(private_frame)
    dodo.private_frame = private_frame -- CoTankPrivateAura 모듈에서 위치 참조용

    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("Debuff")
    if anchorFrame then
        anchorFrame:SetSize(debuff_w + (icon_w + configs.gap) + configs.gap * 2, icon_h)
    end

    main_frame:SetScript("OnEvent", on_event)
    
    local is_enabled = (dodoDB and dodoDB.useDebuff ~= false)
    if is_enabled then
        main_frame:RegisterUnitEvent("UNIT_AURA", "player")
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        main_frame:RegisterEvent("PLAYER_LOGOUT")
        update_auras()
    else
        main_frame:UnregisterAllEvents()
        if private_frame and private_frame.PrivateAuraAnchors then
            for _, frame in ipairs(private_frame.PrivateAuraAnchors) do
                frame:SetUnit(nil)
            end
        end
    end
end

-- 로그인 이벤트 핸들러 (가비지 프리)
local function on_login_event(self)
    if dodo.EditMode then
        dodo.EditMode:CreateSystem("Debuff", "디버프", "디버프 표시기", UIParent, 120, 60, { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", xOfs = 350, yOfs = 0 }, function(point)
            if dodoDB then
                dodoDB.debuffX = point.xOfs
                dodoDB.debuffY = point.yOfs
            end
            load_position()
        end, function() return dodoDB and dodoDB.useDebuff ~= false end)
    end
    init_frames()
    
    local anchorFrame = _G.dodoEditModeDebuff
    if anchorFrame then
        anchorFrame:HookScript("OnShow", show_preview_data)
        anchorFrame:HookScript("OnHide", hide_preview_data)
    end
    
    self:UnregisterEvent("PLAYER_LOGIN")
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", on_login_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("전투", {
        {
            name = "디버프",
            get = function() return dodoDB and dodoDB.useDebuff ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useDebuff = checked end
                update_debuff_option()
            end
        }
    })
end

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting("Debuff", {
        {
            name = "클릭스루 (클릭 무시)",
            get = function() return dodoDB and dodoDB.debuffClickthrough ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.debuffClickthrough = checked end
                update_debuff_option()
            end,
            disabled = function() return dodoDB and dodoDB.useDebuff == false end,
        },
        {
            name = "클릭스루 시 툴팁 표시",
            get = function() return dodoDB and dodoDB.debuffClickthroughTooltip ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.debuffClickthroughTooltip = checked end
                update_debuff_option()
            end,
            disabled = function() return dodoDB and (dodoDB.useDebuff == false or dodoDB.debuffClickthrough == false) end,
        },
        {
            name = "아이콘 크기",
            type = "slider",
            get = function() return dodoDB and dodoDB.debuffSize or 56 end,
            set = function(val)
                if dodoDB then dodoDB.debuffSize = val end
                update_debuff_option()
            end,
            minVal = 30,
            maxVal = 80,
            step = 2,
            disabled = function() return dodoDB and dodoDB.useDebuff == false end,
        },
        {
            name = "최대 표시 개수",
            type = "slider",
            get = function() return dodoDB and dodoDB.debuffMax or 6 end,
            set = function(val)
                if dodoDB then dodoDB.debuffMax = val end
                update_debuff_option()
            end,
            minVal = 1,
            maxVal = 6,
            step = 1,
            disabled = function() return dodoDB and dodoDB.useDebuff == false end,
        }
    })
end
