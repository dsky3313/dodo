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
local module = {}
dodo:RegisterModule("Debuff", module)

local LibEditMode = LibStub and LibStub("LibEditMode", true)

local DEFAULT_SIZE = 56

local configs = {
    size           = DEFAULT_SIZE,
    sizerate       = 1,
    max_debuffs    = 5,
    max_private    = 5,
    gap            = 2,    -- 아이콘 간격
    cool_fontsize  = 18,   -- 쿨다운
    cool_x         = 0,
    cool_y         = 0,
    count_fontsize = 18,   -- 스택
    count_x        = 0,
    count_y        = 0,
    dispel_size    = 20, -- 해제 아이콘
    dispel_x       = 1,
    dispel_y       = 1,
}

local debuffinfo = {
    [0]  = CreateColor(0.8, 0.8, 0.8), -- 일반 디버프
    [1]  = DEBUFF_TYPE_MAGIC_COLOR,
    [2]  = DEBUFF_TYPE_CURSE_COLOR,
    [3]  = DEBUFF_TYPE_DISEASE_COLOR,
    [4]  = DEBUFF_TYPE_POISON_COLOR,
    [9]  = DEBUFF_TYPE_BLEED_COLOR,
    [11] = DEBUFF_TYPE_BLEED_COLOR,
}

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
    [97821]  = true, -- 죽기 전부 디버프
}

-- ==============================
-- 프레임 및 이벤트
-- ==============================
local bsetupprivate = false
local debuff_frame
local main_frame
local private_frame

-- ==============================
-- 캐싱
-- ==============================
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local isSecretValue = issecretvalue or function() return false end
local math_max = math.max
local math_min = math.min
local next = next
local pairs = pairs
local table_wipe = table.wipe
local UIParent = UIParent
local UnitAffectingCombat = UnitAffectingCombat

-- C_UnitAuras functions cached for high performance
local AddPrivateAuraAnchor = C_UnitAuras.AddPrivateAuraAnchor
local GetAuraApplicationDisplayCount = C_UnitAuras.GetAuraApplicationDisplayCount
local GetAuraDispelTypeColor = C_UnitAuras.GetAuraDispelTypeColor
local GetAuraDuration = C_UnitAuras.GetAuraDuration
local GetUnitAuras = C_UnitAuras.GetUnitAuras
local RemovePrivateAuraAnchor = C_UnitAuras.RemovePrivateAuraAnchor

local activeDebuffs = {}
local activeDebuffsCache = {}
local debufffilter = AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful)
local DISPEL_TYPE_NAMES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
local STANDARD_TEXT_FONT = NumberFontNormal:GetFont()

local DISPEL_ICON_KEYS = {}
for _, name in ipairs(DISPEL_TYPE_NAMES) do
    DISPEL_ICON_KEYS[name] = "dispel" .. name
end

local colorcurve = C_CurveUtil.CreateColorCurve()
colorcurve:SetType(Enum.LuaCurveType.Step)
for dispeltype, v in pairs(debuffinfo) do
    colorcurve:AddPoint(dispeltype, v)
end

-- 탐지용 커브 생성 도우미 함수
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

local mockDebuffs = {
    {
        isMock = true,
        auraInstanceID = 99991,
        icon = 135903, -- 마법
        applications = 1,
        duration = 30,
        dispelType = 1, -- Magic
        dispelTypeName = "Magic",
    },
    {
        isMock = true,
        auraInstanceID = 99992,
        icon = 136116, -- 저주
        applications = 3,
        duration = 60,
        dispelType = 2, -- Curse
        dispelTypeName = "Curse",
    },
    {
        isMock = true,
        auraInstanceID = 99993,
        icon = 136122, -- 질병
        applications = 1,
        duration = 15,
        dispelType = 3, -- Disease
        dispelTypeName = "Disease",
    },
    {
        isMock = true,
        auraInstanceID = 99994,
        icon = 132108, -- 독
        applications = 1,
        duration = 8,
        dispelType = 4, -- Poison
        dispelTypeName = "Poison",
    },
    {
        isMock = true,
        auraInstanceID = 99995,
        icon = 132291, -- 출혈
        applications = 5,
        duration = 18,
        dispelType = 9, -- Bleed
        dispelTypeName = "Bleed",
    },
    {
        isMock = true,
        auraInstanceID = 99996,
        icon = 135898, -- 마법
        applications = 1,
        duration = 45,
        dispelType = 1, -- Magic
        dispelTypeName = "Magic",
    },
    {
        isMock = true,
        auraInstanceID = 99997,
        icon = 136115, -- 저주
        applications = 2,
        duration = 20,
        dispelType = 2, -- Curse
        dispelTypeName = "Curse",
    },
    {
        isMock = true,
        auraInstanceID = 99998,
        icon = 136120, -- 질병
        applications = 1,
        duration = 12,
        dispelType = 3, -- Disease
        dispelTypeName = "Disease",
    },
    {
        isMock = true,
        auraInstanceID = 99999,
        icon = 132117, -- 독
        applications = 1,
        duration = 24,
        dispelType = 4, -- Poison
        dispelTypeName = "Poison",
    },
    {
        isMock = true,
        auraInstanceID = 100000,
        icon = 132316, -- 출혈
        applications = 4,
        duration = 30,
        dispelType = 9, -- Bleed
        dispelTypeName = "Bleed",
    },
}

-- ==============================
-- 기능 1: Private Aura Mixin
-- ==============================
dodo_PrivateAuraAnchorMixin = {}

function dodo_PrivateAuraAnchorMixin:SetUnit(unit)
    if unit == self.unit then
        return
    end
    self.unit = unit

    if self.anchorID then
        RemovePrivateAuraAnchor(self.anchorID)
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

        self.anchorID = AddPrivateAuraAnchor(args)
    end
end

-- ==============================
-- 기능 2: UI 생성 헬퍼
-- ==============================
local function create_debuff_frames(parent)
    if parent.frames == nil then
        parent.frames = {}
    end

    local w = configs.size
    local h = configs.size * configs.sizerate

    for idx = 1, 10 do
        local frame = CreateFrame("Button", nil, parent, "dodo_DebuffFrameTemplate")
        parent.frames[idx] = frame

        frame.cooldown:SetDrawEdge(false)
        frame.cooldown:SetDrawSwipe(true)
        frame.cooldown:SetHideCountdownNumbers(false)
        frame.cooldown:ClearAllPoints()
        frame.cooldown:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
        local cool_size = math_max(w - 6, 10)
        frame.cooldown:SetSize(cool_size, cool_size)
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

        frame.border:ClearAllPoints()
        frame.border:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.border:SetSize(w, h)

        frame.count:SetFont(STANDARD_TEXT_FONT, configs.count_fontsize, "OUTLINE")
        frame.count:ClearAllPoints()
        frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", configs.count_x, configs.count_y)
        frame.count:SetTextColor(1, 1, 0)

        frame:SetSize(w, h)
        frame:ClearAllPoints()

        -- 해제 타입 아이콘
        for _, name in ipairs(DISPEL_TYPE_NAMES) do
            local dispelIcon = frame[DISPEL_ICON_KEYS[name]]
            if dispelIcon then
                dispelIcon:SetSize(configs.dispel_size, configs.dispel_size)
                dispelIcon:ClearAllPoints()
                dispelIcon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", configs.dispel_x, configs.dispel_y)
            end
        end

        local growDir = dodo.DB and dodo.DB.debuffGrow or "RIGHT_TO_LEFT"
        if growDir == "LEFT_TO_RIGHT" then
            if idx == 1 then
                frame:SetPoint("LEFT", parent, "LEFT", 0, 0)
            else
                frame:SetPoint("LEFT", parent.frames[idx - 1], "RIGHT", configs.gap, 0)
            end
        else -- "RIGHT_TO_LEFT"
            if idx == 1 then
                frame:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
            else
                frame:SetPoint("RIGHT", parent.frames[idx - 1], "LEFT", -configs.gap, 0)
            end
        end

        frame:SetScript("OnEnter", function(self)
            if self.auraid then
                GameTooltip_SetDefaultAnchor(GameTooltip, self)
                GameTooltip:SetUnitDebuffByAuraInstanceID(self.unit, self.auraid, debufffilter)
            end
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

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

        local privateGrow = dodo.DB and dodo.DB.privateGrow or "LEFT_TO_RIGHT"
        if privateGrow == "RIGHT_TO_LEFT" then
            if idx == 1 then
                frame:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
            else
                frame:SetPoint("RIGHT", parent.PrivateAuraAnchors[idx - 1], "LEFT", -configs.gap, 0)
            end
        else -- "LEFT_TO_RIGHT"
            if idx == 1 then
                frame:SetPoint("LEFT", parent, "LEFT", 0, 0)
            else
                frame:SetPoint("LEFT", parent.PrivateAuraAnchors[idx - 1], "RIGHT", configs.gap, 0)
            end
        end

        frame:SetUnit("player")
    end
end

-- ==============================
-- 기능 3: 디버프 로직
-- ==============================
local function set_cooldown_frame(cooldown, durationobject, enable)
    if enable and durationobject then
        cooldown:SetCooldownFromDurationObject(durationobject)
        cooldown:Show()
    else
        cooldown:Clear()
        cooldown:Hide()
    end
end

local function update_debuff_frames()
    local auraList = activeDebuffs["player"]
    if not auraList then return end

    local shown = 0

    for _, aura in ipairs(auraList) do
        shown = shown + 1
        if shown > configs.max_debuffs then
            break
        end

        local frame = debuff_frame.frames[shown]
        frame.unit   = "player"
        frame.auraid = aura.auraInstanceID

        frame.icon:SetTexture(aura.icon)

        if aura.isMock then
            local appCount = aura.applications or 1
            frame.count:SetText(appCount > 1 and appCount or "")

            frame.cooldown:SetCooldown(GetTime(), aura.duration)
            frame.cooldown:Show()

            local color = debuffinfo[aura.dispelType]
            if color then
                frame.border:SetVertexColor(color.r, color.g, color.b)
            else
                frame.border:SetVertexColor(0, 0, 0)
            end

            for _, name in ipairs(DISPEL_TYPE_NAMES) do
                local dispelIcon = frame[DISPEL_ICON_KEYS[name]]
                if dispelIcon then
                    dispelIcon:SetAlpha(aura.dispelTypeName == name and 1 or 0)
                    dispelIcon:Show()
                end
            end
        else
            frame.count:SetText(GetAuraApplicationDisplayCount("player", aura.auraInstanceID, 1, 100))

            local durationobject = GetAuraDuration("player", aura.auraInstanceID)
            set_cooldown_frame(frame.cooldown, durationobject, true)

            local color = GetAuraDispelTypeColor("player", aura.auraInstanceID, colorcurve)
            if color then
                frame.border:SetVertexColor(color.r, color.g, color.b)
            else
                frame.border:SetVertexColor(0, 0, 0)
            end

            for _, name in ipairs(DISPEL_TYPE_NAMES) do
                local detectColor = GetAuraDispelTypeColor("player", aura.auraInstanceID, detect_curves[name])
                local dispelIcon = frame[DISPEL_ICON_KEYS[name]]
                if dispelIcon then
                    dispelIcon:SetAlpha(detectColor and detectColor.a or 0)
                    dispelIcon:Show()
                end
            end
        end

        frame:Show()
    end

    for j = shown + 1, #debuff_frame.frames do
        if debuff_frame.frames[j] then
            debuff_frame.frames[j]:Hide()
        end
    end
end

local activeMocksCache = {}
local function update_auras(updateInfo)
    if LibEditMode and LibEditMode:IsInEditMode() then
        table_wipe(activeMocksCache)
        local n = math_min(#mockDebuffs, configs.max_debuffs)
        for i = 1, n do
            activeMocksCache[i] = mockDebuffs[i]
        end
        activeDebuffs["player"] = activeMocksCache
        update_debuff_frames()
        return
    end

    local useFilter = true
    if dodo.DB and dodo.DB.useDebuffFilter == false then
        useFilter = false
    end

    if not updateInfo or updateInfo.isFullUpdate then
        local auras = GetUnitAuras("player", debufffilter)
        table_wipe(activeDebuffsCache)
        if auras then
            for _, aura in ipairs(auras) do
                local sid = aura.spellId
                local isFiltered = false
                if sid and useFilter and not isSecretValue(sid) and filterList[sid] then
                    isFiltered = true
                end
                if not isFiltered then
                    activeDebuffsCache[#activeDebuffsCache + 1] = aura
                    if #activeDebuffsCache >= configs.max_debuffs then break end
                end
            end
        end
    else
        if updateInfo.removedAuraInstanceIDs then
            for _, removedID in ipairs(updateInfo.removedAuraInstanceIDs) do
                local n = #activeDebuffsCache
                for i = n, 1, -1 do
                    if activeDebuffsCache[i].auraInstanceID == removedID then
                        activeDebuffsCache[i] = activeDebuffsCache[n]
                        activeDebuffsCache[n] = nil
                        break
                    end
                end
            end
        end
        if updateInfo.addedAuras then
            for _, aura in ipairs(updateInfo.addedAuras) do
                if aura.isHarmful and #activeDebuffsCache < configs.max_debuffs then
                    local sid = aura.spellId
                    local isFiltered = sid and useFilter and not isSecretValue(sid) and filterList[sid]
                    if not isFiltered then
                        activeDebuffsCache[#activeDebuffsCache + 1] = aura
                    end
                end
            end
        end
    end

    activeDebuffs["player"] = activeDebuffsCache
    update_debuff_frames()
end

-- ==============================
-- 기능 4: 위치 저장 및 로드
-- ==============================
local function save_frame_position(f, keyPrefix, growKey)
    if not f then return end
    local grow = dodo.DB[growKey] or (keyPrefix == "debuff" and "RIGHT_TO_LEFT" or "LEFT_TO_RIGHT")
    local scale = f:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()
    local screenW = UIParent:GetWidth()
    
    local x, y, point
    if grow == "RIGHT_TO_LEFT" then
        local r = f:GetRight()
        local b = f:GetBottom()
        if r and b and scale and us and screenW then
            x = (r * scale - screenW * us) / us
            y = (b * scale) / us
            point = "BOTTOMRIGHT"
        end
    else -- LEFT_TO_RIGHT
        local l = f:GetLeft()
        local b = f:GetBottom()
        if l and b and scale and us then
            x = (l * scale) / us
            y = (b * scale) / us
            point = "BOTTOMLEFT"
        end
    end
    
    if x and y and point then
        dodo.DB[keyPrefix .. "Point"] = point
        dodo.DB[keyPrefix .. "RelativePoint"] = point
        dodo.DB[keyPrefix .. "X"] = x
        dodo.DB[keyPrefix .. "Y"] = y
    end
end

local function save_position()
    save_frame_position(main_frame, "debuff", "debuffGrow")
    save_frame_position(private_frame, "private", "privateGrow")
end

local function load_position()
    if main_frame then
        local point = dodo.DB.debuffPoint or "BOTTOMRIGHT"
        local targetX = dodo.DB.debuffX
        local targetY = dodo.DB.debuffY
        
        if not targetX then
            local icon_w = configs.size
            local icon_h = configs.size * configs.sizerate
            local debuff_w = (icon_w + configs.gap) * configs.max_debuffs
            targetX = -(UIParent:GetWidth()/2 - 335 - debuff_w/2)
            targetY = -8 - icon_h/2
            point = "BOTTOMRIGHT"
        end
        
        main_frame:ClearAllPoints()
        main_frame:SetPoint(point, UIParent, dodo.DB.debuffRelativePoint or point, targetX, targetY)
    end

    if private_frame then
        local point = dodo.DB.privatePoint or "BOTTOMLEFT"
        local targetX = dodo.DB.privateX
        local targetY = dodo.DB.privateY
        
        if not targetX then
            local icon_w = configs.size
            local icon_h = configs.size * configs.sizerate
            local private_w = (icon_w + configs.gap) * configs.max_private
            targetX = 335 - private_w/2
            targetY = -8 - icon_h/2
            point = "BOTTOMLEFT"
        end
        
        private_frame:ClearAllPoints()
        private_frame:SetPoint(point, UIParent, dodo.DB.privateRelativePoint or point, targetX, targetY)
    end
end

-- ==============================
-- 기능 5: 설정 업데이트
-- ==============================
local function update_feature()
    if not main_frame or not debuff_frame then return end

    configs.size = dodo.DB.debuffSize or DEFAULT_SIZE
    configs.max_debuffs = dodo.DB.debuffMax or 5

    load_position()

    local icon_w = configs.size
    local icon_h = configs.size * configs.sizerate
    local debuff_w = (icon_w + configs.gap) * configs.max_debuffs
    local private_w = (icon_w + configs.gap) * configs.max_private

    debuff_frame:SetSize(debuff_w, icon_h)
    if private_frame then
        private_frame:SetSize(private_w, icon_h)
    end
    main_frame:SetSize(debuff_w, icon_h)

    debuff_frame:ClearAllPoints()
    local debuffGrow = dodo.DB.debuffGrow or "RIGHT_TO_LEFT"
    if debuffGrow == "LEFT_TO_RIGHT" then
        debuff_frame:SetPoint("LEFT", main_frame, "LEFT", 0, 0)
    else
        debuff_frame:SetPoint("RIGHT", main_frame, "RIGHT", 0, 0)
    end

    for idx, frame in ipairs(debuff_frame.frames) do
        frame:SetSize(icon_w, icon_h)
        if frame.border then frame.border:SetSize(icon_w, icon_h) end
        if frame.cooldown then
            local cool_size = math_max(icon_w - 6, 10)
            frame.cooldown:SetSize(cool_size, cool_size)
        end
        
        frame:ClearAllPoints()
        if debuffGrow == "LEFT_TO_RIGHT" then
            if idx == 1 then
                frame:SetPoint("LEFT", debuff_frame, "LEFT", 0, 0)
            else
                frame:SetPoint("LEFT", debuff_frame.frames[idx - 1], "RIGHT", configs.gap, 0)
            end
        else -- "RIGHT_TO_LEFT"
            if idx == 1 then
                frame:SetPoint("RIGHT", debuff_frame, "RIGHT", 0, 0)
            else
                frame:SetPoint("RIGHT", debuff_frame.frames[idx - 1], "LEFT", -configs.gap, 0)
            end
        end
        
        local clickthrough = (dodo.DB.useDebuffClickthrough ~= false)
        if clickthrough then
            frame:EnableMouse(true)
            if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
            if dodo.DB.useDebuffClickthroughTooltip == false then
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

    if private_frame and private_frame.PrivateAuraAnchors and not InCombatLockdown() then
        local privateGrow = dodo.DB.privateGrow or "LEFT_TO_RIGHT"
        for idx, frame in ipairs(private_frame.PrivateAuraAnchors) do
            frame:SetSize(icon_w, icon_h)
            frame:ClearAllPoints()
            if privateGrow == "RIGHT_TO_LEFT" then
                if idx == 1 then
                    frame:SetPoint("RIGHT", private_frame, "RIGHT", 0, 0)
                else
                    frame:SetPoint("RIGHT", private_frame.PrivateAuraAnchors[idx - 1], "LEFT", -configs.gap, 0)
                end
            else -- "LEFT_TO_RIGHT"
                if idx == 1 then
                    frame:SetPoint("LEFT", private_frame, "LEFT", 0, 0)
                else
                    frame:SetPoint("LEFT", private_frame.PrivateAuraAnchors[idx - 1], "RIGHT", configs.gap, 0)
                end
            end
        end
    end

    -- 설정 변경 후 표시 갱신
    if LibEditMode and LibEditMode:IsInEditMode() then
        update_auras()
    else
        update_debuff_frames()
    end
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function OnEvent(self, event, arg1, arg2)
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

local function update_module_state()
    local enabled = true
    if dodo.DB and dodo.DB.enableDebuffModule ~= nil then
        enabled = dodo.DB.enableDebuffModule
    end

    if not enabled then
        main_frame:Hide()
        main_frame:UnregisterAllEvents()
        if private_frame then
            private_frame:Hide()
        end
        if LibEditMode and LibEditMode.frameSelections then
            if LibEditMode.frameSelections[main_frame] then
                LibEditMode.frameSelections[main_frame]:Hide()
            end
            if LibEditMode.frameSelections[private_frame] then
                LibEditMode.frameSelections[private_frame]:Hide()
            end
        end
    else
        main_frame:Show()
        if private_frame then
            private_frame:Show()
        end
        
        main_frame:RegisterUnitEvent("UNIT_AURA", "player")
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        main_frame:RegisterEvent("PLAYER_LOGOUT")
        main_frame:SetScript("OnEvent", OnEvent)
        
        update_auras()
        
        if LibEditMode and LibEditMode:IsInEditMode() and LibEditMode.frameSelections then
            if LibEditMode.frameSelections[main_frame] then
                LibEditMode.frameSelections[main_frame]:ShowHighlighted()
            end
            if LibEditMode.frameSelections[private_frame] then
                LibEditMode.frameSelections[private_frame]:ShowHighlighted()
            end
        end
    end
end

dodo.UpdateDebuffModuleState = update_module_state

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
    local icon_w = configs.size
    local icon_h = configs.size * configs.sizerate
    local debuff_w = (icon_w + configs.gap) * configs.max_debuffs
    local private_w = (icon_w + configs.gap) * configs.max_private

    main_frame = CreateFrame("Frame", "dodo_DebuffMainFrame", UIParent)
    main_frame:SetFrameStrata("MEDIUM")
    main_frame:SetSize(debuff_w, icon_h)

    debuff_frame = CreateFrame("Frame", nil, main_frame)
    debuff_frame:SetSize(debuff_w, icon_h)
    debuff_frame:SetPoint("CENTER", main_frame, "CENTER", 0, 0)
    debuff_frame:Show()
    create_debuff_frames(debuff_frame)

    private_frame = CreateFrame("Frame", "dodo_PrivateAuraMainFrame", UIParent)
    private_frame:SetFrameStrata("MEDIUM")
    private_frame:SetSize(private_w, icon_h)
    private_frame:Show()
    create_private_frames(private_frame)
    dodo.private_frame = private_frame -- CoTankPrivateAura 모듈에서 위치 참조용
end

local function initialize()
    if dodo.DB.debuffGrow == nil then
        dodo.DB.debuffGrow = "RIGHT_TO_LEFT"
    end
    if dodo.DB.privateGrow == nil then
        dodo.DB.privateGrow = "LEFT_TO_RIGHT"
    end

    configs.size = dodo.DB.debuffSize or configs.size
    configs.max_debuffs = dodo.DB.debuffMax or configs.max_debuffs

    create_ui()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    update_feature()
    update_module_state()

    -- LibEditMode 등록
    main_frame.editModeName = "dodo 플레이어 디버프"
    private_frame.editModeName = "dodo 프라이빗 오라"
    if LibEditMode then
        -- 디버프 프레임 등록
        LibEditMode:AddFrame(
            main_frame,
            function(frame, layoutName, point, x, y)
                save_frame_position(frame, "debuff", "debuffGrow")
            end,
            {
                point = "CENTER",
                x = 190,
                y = -8,
            },
            "dodo 플레이어 디버프"
        )

        LibEditMode:AddFrameSettings(main_frame, {
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "클릭 무시",
                desc = "디버프 아이콘 클릭을 무시하여 뒤에 있는 대상을 클릭할 수 있게 합니다.",
                default = true,
                get = function()
                    return dodo.DB.useDebuffClickthrough ~= false
                end,
                set = function(_, newValue)
                    dodo.DB.useDebuffClickthrough = newValue
                    update_feature()
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "툴팁 표시",
                desc = "마우스를 올렸을 때 툴팁을 표시합니다.",
                default = true,
                get = function()
                    return dodo.DB.useDebuffClickthroughTooltip ~= false
                end,
                set = function(_, newValue)
                    dodo.DB.useDebuffClickthroughTooltip = newValue
                    update_feature()
                end,
                disabled = function()
                    return not (dodo.DB.useDebuffClickthrough ~= false)
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "디버프 필터링",
                desc = "불필요한 디버프(탈영병, 소진, 포만감 등)를 숨깁니다.",
                default = true,
                get = function()
                    return dodo.DB.useDebuffFilter ~= false
                end,
                set = function(_, newValue)
                    dodo.DB.useDebuffFilter = newValue
                    update_feature()
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "아이콘 크기",
                desc = "디버프 아이콘의 크기를 조절합니다.\n(추천: " .. DEFAULT_SIZE .. ")",
                default = DEFAULT_SIZE,
                minValue = 30,
                maxValue = 80,
                valueStep = 2,
                get = function()
                    return dodo.DB.debuffSize or DEFAULT_SIZE
                end,
                set = function(_, newValue)
                    dodo.DB.debuffSize = newValue
                    update_feature()
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "최대 표시 개수",
                desc = "최대로 표시할 디버프 개수를 설정합니다.",
                default = 5,
                minValue = 1,
                maxValue = 10,
                valueStep = 1,
                get = function()
                    return dodo.DB.debuffMax or 5
                end,
                set = function(_, newValue)
                    dodo.DB.debuffMax = newValue
                    update_feature()
                end,
            },
            {
                kind = LibEditMode.SettingType.Dropdown,
                name = "아이콘 방향",
                desc = "디버프 아이콘이 표시되어 뻗어나갈 방향을 결정합니다.",
                default = "RIGHT_TO_LEFT",
                get = function()
                    return dodo.DB.debuffGrow or "RIGHT_TO_LEFT"
                end,
                set = function(_, newValue)
                    dodo.DB.debuffGrow = newValue
                    save_frame_position(main_frame, "debuff", "debuffGrow")
                    update_feature()
                end,
                values = {
                    { text = "오른쪽에서 왼쪽", value = "RIGHT_TO_LEFT" },
                    { text = "왼쪽에서 오른쪽", value = "LEFT_TO_RIGHT" },
                }
            },
        })

        -- 프라이빗 오라 프레임 등록
        LibEditMode:AddFrame(
            private_frame,
            function(frame, layoutName, point, x, y)
                save_frame_position(frame, "private", "privateGrow")
            end,
            {
                point = "CENTER",
                x = 480,
                y = -8,
            },
            "dodo 플레이어 프라이빗 오라"
        )

        LibEditMode:AddFrameSettings(private_frame, {
            {
                kind = LibEditMode.SettingType.Dropdown,
                name = "아이콘 방향",
                desc = "프라이빗 오라 아이콘이 표시되어 뻗어나갈 방향을 결정합니다.",
                default = "LEFT_TO_RIGHT",
                get = function()
                    return dodo.DB.privateGrow or "LEFT_TO_RIGHT"
                end,
                set = function(_, newValue)
                    dodo.DB.privateGrow = newValue
                    save_frame_position(private_frame, "private", "privateGrow")
                    update_feature()
                end,
                values = {
                    { text = "왼쪽에서 오른쪽", value = "LEFT_TO_RIGHT" },
                    { text = "오른쪽에서 왼쪽", value = "RIGHT_TO_LEFT" },
                }
            },
        })

        LibEditMode:RegisterCallback("enter", function()
            update_auras()
        end)
        LibEditMode:RegisterCallback("exit", function()
            update_auras()
        end)
    end

    update_auras()

    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("전투", {
            {
                name = "플레이어 디버프",
                get = function() return dodo.DB and dodo.DB.enableDebuffModule ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.enableDebuffModule = checked end
                    update_module_state()
                end
            }
        })
    end
end