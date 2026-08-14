---@diagnostic disable: redundant-parameter, lowercase-global, param-type-mismatch, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local configs = {
    size           = 56,
    sizerate       = 1,
    max_debuffs    = 6,
    max_private    = 6,
    gap            = 2,
    cool_fontsize  = 18,
    count_fontsize = 18,
    count_x        = 0,
    count_y        = 0,
    dispel_size    = 20,
    dispel_x       = 1,
    dispel_y       = 1,
    clickthrough   = false,
}

local Options_Default = {
    Version = 1,
    xpoint  = 350,
    ypoint  = 0,
}

local excluded_spell_ids = {
    [26013]  = true, -- 탈영병
    [71041]  = true, -- 탈영병 (인스턴스)
    [57723]  = true, -- 소진
    [57724]  = true, -- 만족함
    [80354]  = true, -- 시간 변위
    [95809]  = true, -- 포만감
    [160455] = true, -- 만족함
    [264689] = true, -- 피로
    [390435] = true, -- 탈진
    [97821]  = true, -- 죽기 디버프
}

local DISPEL_TYPE_NAMES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

local PREVIEW_BORDER_COLORS = {
    Magic   = {0.32, 0.66, 1.00},
    Curse   = {0.67, 0.16, 1.00},
    Disease = {0.70, 0.47, 0.00},
    Poison  = {0.00, 1.00, 0.00},
    Bleed   = {1.00, 0.29, 0.17},
}

local CopyTable           = CopyTable
local CreateFrame         = CreateFrame
local GetTime             = GetTime
local UnitAffectingCombat = UnitAffectingCombat
local math_max            = math.max
local next                = next
local ipairs              = ipairs

local is_preview_active   = false
local bsetupprivate       = false
local debuff_container
local debuff_anchor
local debuff_buttons      = {}
local debuff_preview_frames
local main_frame          = CreateFrame("Frame", nil, UIParent)
local private_frame

-- ==============================
-- dispel 컬러맵 (lazy)
-- ==============================
local dispel_color_map
local function get_dispel_color_map()
    if not dispel_color_map then
        dispel_color_map = {}
        for _, t in ipairs(DISPEL_TYPE_NAMES) do
            dispel_color_map[t] = AuraUtil.GetAuraBorderColor(t)
        end
    end
    return dispel_color_map
end

-- ==============================
-- Private Aura Mixin
-- ==============================
dodo_PrivateAuraAnchorMixin = {}

function dodo_PrivateAuraAnchorMixin:SetUnit(unit)
    if unit == self.unit then return end
    self.unit = unit
    if self.anchorID then
        C_UnitAuras.RemovePrivateAuraAnchor(self.anchorID)
        self.anchorID = nil
    end
    if unit then
        self.anchorID = C_UnitAuras.AddPrivateAuraAnchor({
            unitToken            = unit,
            auraIndex            = self.auraIndex,
            parent               = self,
            showCountdownFrame   = true,
            showCountdownNumbers = true,
            isContainer          = false,
            iconInfo = {
                iconAnchor = { point="CENTER", relativeTo=self, relativePoint="CENTER", offsetX=0, offsetY=0 },
                iconWidth  = self:GetWidth(),
                iconHeight = self:GetHeight(),
                borderScale = 2.0,
            },
            durationAnchor = nil,
        })
    end
end

-- ==============================
-- AuraButton 설정 콜백
-- ==============================
local function configure_button(button)
    local w = configs.size
    local h = configs.size * configs.sizerate
    button:SetSize(w, h)

    -- 아이콘 (BACKGROUND → 테두리보다 아래 레이어)
    if not button._dodo_icon then
        button._dodo_icon = button:CreateTexture(nil, "BACKGROUND")
        button._dodo_icon:SetAllPoints(button)
        button:SetIcon(button._dodo_icon)
    end
    button._dodo_icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- 기본 border (항상 표시, 회색 = 해제불가 디버프)
    if not button._dodo_base_border then
        button._dodo_base_border = button:CreateTexture(nil, "ARTWORK", nil, 6)
        button._dodo_base_border:SetTexture("Interface\\Addons\\dodo\\Media\\Texture\\AuraBorder.tga")
    end
    button._dodo_base_border:ClearAllPoints()
    button._dodo_base_border:SetPoint("TOPLEFT",     button, "TOPLEFT",     -4,  4)
    button._dodo_base_border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT",  4, -4)
    button._dodo_base_border:SetVertexColor(0.5, 0.5, 0.5, 1)

    -- dispel 컬러 border (타입 있을 때만 표시, 기본 border 위에 덮음)
    if not button._dodo_dispel_border then
        button._dodo_dispel_border = button:CreateTexture(nil, "ARTWORK", nil, 7)
        button._dodo_dispel_border:SetTexture("Interface\\Addons\\dodo\\Media\\Texture\\AuraBorder.tga")
        button:AddDispelTypeTexture(button._dodo_dispel_border, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
            customDispelColorMap = get_dispel_color_map(),
            showWhenHarmful  = true,
            showWhenHelpful  = false,
        })
    end
    button._dodo_dispel_border:ClearAllPoints()
    button._dodo_dispel_border:SetPoint("TOPLEFT",     button, "TOPLEFT",     -4,  4)
    button._dodo_dispel_border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT",  4, -4)

    -- overlay (swipe 위 텍스트/아이콘 레이어)
    if not button._dodo_overlay then
        button._dodo_overlay = CreateFrame("Frame", nil, button)
        button._dodo_overlay:SetAllPoints(button)
    end
    button._dodo_overlay:SetFrameLevel(button:GetFrameLevel() + 3)

    -- 스택 카운트 (SetFont 먼저, 그 후 SetApplicationCount — 등록 즉시 SetText 트리거 방지)
    local count_new = not button._dodo_count
    if count_new then
        button._dodo_count = button._dodo_overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    end
    button._dodo_count:SetFont(STANDARD_TEXT_FONT, configs.count_fontsize, "OUTLINE")
    button._dodo_count:ClearAllPoints()
    button._dodo_count:SetPoint("BOTTOMRIGHT", button._dodo_overlay, "BOTTOMRIGHT", configs.count_x, configs.count_y)
    button._dodo_count:SetTextColor(1, 1, 0)
    if count_new then
        button:SetApplicationCount(button._dodo_count, {})
    end

    -- 쿨다운 swipe
    if not button._dodo_cooldown then
        button._dodo_cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button._dodo_cooldown:SetAllPoints(button._dodo_icon)
        button._dodo_cooldown:SetDrawEdge(false)
        button._dodo_cooldown:SetDrawSwipe(true)
        button._dodo_cooldown:SetHideCountdownNumbers(false)
        button._dodo_cooldown:SetReverse(true)
        button:SetDurationCooldown(button._dodo_cooldown)
    end
    for _, r in next, { button._dodo_cooldown:GetRegions() } do
        if r:GetObjectType() == "FontString" then
            r:SetFont(STANDARD_TEXT_FONT, configs.cool_fontsize, "OUTLINE")
            r:SetDrawLayer("OVERLAY")
            break
        end
    end

    -- dispel 타입 아이콘 (우상단)
    if not button._dodo_dispel_icon then
        local ov = CreateFrame("Frame", nil, button)
        ov:SetAllPoints(button)
        ov:SetFrameLevel(button:GetFrameLevel() + 4)
        button._dodo_dispel_icon_ov = ov
        button._dodo_dispel_icon = ov:CreateTexture(nil, "OVERLAY")
        button:AddDispelTypeTexture(button._dodo_dispel_icon, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.Icon,
            showWhenHarmful = true,
            showWhenHelpful = false,
        })
    end
    button._dodo_dispel_icon:SetSize(configs.dispel_size, configs.dispel_size)
    button._dodo_dispel_icon:ClearAllPoints()
    button._dodo_dispel_icon:SetPoint("TOPRIGHT", button._dodo_dispel_icon_ov, "TOPRIGHT", configs.dispel_x, configs.dispel_y)

    -- 마우스 (AuraButton 자동 툴팁)
    local show_tooltip = not configs.clickthrough or (dodoDB and dodoDB.debuffClickthroughTooltip ~= false)
    button:SetMouseMotionEnabled(show_tooltip)
    if button.SetMouseClickEnabled then
        button:SetMouseClickEnabled(not configs.clickthrough)
    end
end

-- ==============================
-- AuraContainer 생성 / 갱신
-- ==============================
local function build_container()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end

    local w       = configs.size
    local h       = configs.size * configs.sizerate
    local spacing = configs.gap
    local limit   = configs.max_debuffs

    if not debuff_anchor then
        debuff_anchor = CreateFrame("Frame", nil, main_frame)
    end
    debuff_anchor:SetSize(w, h)
    debuff_anchor:SetPoint("RIGHT", main_frame, "CENTER", -spacing, 0)

    if not debuff_container then
        debuff_container = CreateFrame("AuraContainer", nil, main_frame, "CustomAuraContainerTemplate")
    end

    local row_width = math_max(w, w * limit + spacing * math_max(limit - 1, 0))
    debuff_container:SetSize(w, h)
    debuff_container:SetUnit("player")
    debuff_container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    debuff_container:SetFlowLayoutAnchorPoint("TOPRIGHT")
    debuff_container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
    debuff_container:SetFlowLayoutMaximumLineSize(row_width)
    debuff_container:ClearAllPoints()
    debuff_container:SetPoint("TOPRIGHT", debuff_anchor, "TOPRIGHT", 0, 0)

    local group_key         = "dodo_player_debuffs"
    local filter_string     = AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful)
    local candidate_filters = { excludeSpellIDs = excluded_spell_ids }
    local layout = {
        elementWidth   = w,
        elementHeight  = h,
        elementSpacing = spacing,
        lineSpacing    = spacing,
    }

    if debuff_container:HasAuraGroup(group_key) then
        debuff_container:SetAuraGroupMaxFrameCount(group_key, limit)
        debuff_container:SetAuraGroupCandidateFilters(group_key, candidate_filters)
        debuff_container:SetAuraGroupLayout(group_key, layout)
    else
        debuff_container:AddAuraGroup(group_key, filter_string, {
            maxFrameCount    = limit,
            sortMethod       = AuraContainerSortMethod.AuraInstanceIDOnly,
            sortDirection    = AuraContainerSortDirection.Normal,
            initializeFrame  = function(button)
                debuff_buttons[button] = true
                configure_button(button)
            end,
            candidateFilters = candidate_filters,
            layout           = layout,
        })
    end

    local is_enabled = (dodoDB and dodoDB.useDebuff ~= false) and not is_preview_active
    debuff_container:SetEnabled(is_enabled)
    debuff_container:SetShown(is_enabled)
    debuff_anchor:SetShown(is_enabled)
end

-- ==============================
-- Private Aura 프레임 생성
-- ==============================
local function create_private_frames(parent)
    if parent.PrivateAuraAnchors == nil then
        parent.PrivateAuraAnchors = {}
    end
    if UnitAffectingCombat("player") then return end

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
        if idx == 1 then
            frame:SetPoint("LEFT", parent, "LEFT", 0, 0)
        else
            frame:SetPoint("LEFT", parent.PrivateAuraAnchors[idx - 1], "RIGHT", configs.gap, 0)
        end
        frame:SetUnit("player")
    end
end

-- ==============================
-- 미리보기 (Edit Mode용)
-- ==============================
local function show_preview_data()
    is_preview_active = true
    if debuff_container then
        debuff_container:SetEnabled(false)
        debuff_container:Hide()
    end
    if debuff_anchor then debuff_anchor:Hide() end

    local w = configs.size
    local h = configs.size * configs.sizerate

    if not debuff_preview_frames then
        debuff_preview_frames = {}
        for i = 1, 6 do
            local frame = CreateFrame("Button", nil, main_frame, "dodo_DebuffFrameTemplate")
            debuff_preview_frames[i] = frame
            frame.cooldown:SetDrawEdge(false)
            frame.cooldown:SetDrawSwipe(true)
            frame.cooldown:SetHideCountdownNumbers(false)
            frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local ov = CreateFrame("Frame", nil, frame)
            ov:SetAllPoints(frame)
            ov:SetFrameLevel(frame:GetFrameLevel() + 2)
            frame.overlayLayer = ov
            frame.border:SetParent(ov)
            frame.border:SetDrawLayer("ARTWORK")
            frame.count:SetParent(ov)
            frame.count:SetDrawLayer("OVERLAY")
            frame.count:SetFont(STANDARD_TEXT_FONT, configs.count_fontsize, "OUTLINE")
            frame.count:SetTextColor(1, 1, 0)
            for _, name in ipairs(DISPEL_TYPE_NAMES) do
                local di = frame["dispel" .. name]
                if di then
                    di:SetParent(ov)
                    di:SetSize(configs.dispel_size, configs.dispel_size)
                end
            end
        end
    end

    local fake = {
        { icon=135900, count=1, dispel="Magic",   duration=15 },
        { icon=136121, count=2, dispel="Curse",   duration=10 },
        { icon=135869, count=0, dispel="Disease", duration=8  },
        { icon=135925, count=5, dispel="Poison",  duration=12 },
        { icon=132242, count=0, dispel="Bleed",   duration=20 },
        { icon=136183, count=0, dispel=nil,        duration=0  },
    }

    for i = 1, configs.max_debuffs do
        local frame = debuff_preview_frames[i]
        local data  = fake[i] or {}
        frame:SetSize(w, h)
        frame.border:SetSize(w, h)
        frame:ClearAllPoints()
        if i == 1 then
            frame:SetPoint("RIGHT", main_frame, "CENTER", -configs.gap, 0)
        else
            frame:SetPoint("RIGHT", debuff_preview_frames[i - 1], "LEFT", -configs.gap, 0)
        end
        frame.icon:SetTexture(data.icon)
        frame.count:SetText((data.count and data.count > 0) and data.count or "")
        local c = data.dispel and PREVIEW_BORDER_COLORS[data.dispel]
        if c then
            frame.border:SetVertexColor(c[1], c[2], c[3])
        else
            frame.border:SetVertexColor(0.5, 0.5, 0.5)
        end
        if data.duration and data.duration > 0 then
            frame.cooldown:SetCooldown(GetTime(), data.duration)
            frame.cooldown:Show()
        else
            frame.cooldown:Clear()
            frame.cooldown:Hide()
        end
        for _, name in ipairs(DISPEL_TYPE_NAMES) do
            local di = frame["dispel" .. name]
            if di then
                di:SetAlpha(name == data.dispel and 1 or 0)
                di:Show()
            end
        end
        frame:Show()
    end
    for i = configs.max_debuffs + 1, 6 do
        if debuff_preview_frames[i] then debuff_preview_frames[i]:Hide() end
    end

    if private_frame and private_frame.PrivateAuraAnchors then
        for i = 1, configs.max_private do
            local frame = private_frame.PrivateAuraAnchors[i]
            local data  = i == 1 and { icon=136209, duration=12 } or nil
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
                    frame.previewCooldown:SetCooldown(GetTime(), data.duration)
                    frame.previewCooldown:Show()
                else
                    if frame.previewIcon     then frame.previewIcon:Hide() end
                    if frame.previewBorder   then frame.previewBorder:Hide() end
                    if frame.previewCooldown then
                        frame.previewCooldown:Clear()
                        frame.previewCooldown:Hide()
                    end
                end
            end
        end
    end
end

local function hide_preview_data()
    is_preview_active = false
    if debuff_preview_frames then
        for _, f in ipairs(debuff_preview_frames) do f:Hide() end
    end
    if private_frame and private_frame.PrivateAuraAnchors then
        for i = 1, configs.max_private do
            local frame = private_frame.PrivateAuraAnchors[i]
            if frame then
                if frame.previewIcon     then frame.previewIcon:Hide() end
                if frame.previewBorder   then frame.previewBorder:Hide() end
                if frame.previewCooldown then
                    frame.previewCooldown:Clear()
                    frame.previewCooldown:Hide()
                end
            end
        end
    end
    local is_enabled = dodoDB and dodoDB.useDebuff ~= false
    if debuff_container then
        debuff_container:SetEnabled(is_enabled)
        debuff_container:SetShown(is_enabled)
    end
    if debuff_anchor then debuff_anchor:SetShown(is_enabled) end
end

-- ==============================
-- 위치 저장 / 복원
-- ==============================
local function save_position()
    local x, y   = main_frame:GetCenter()
    local scale  = main_frame:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    local us     = UIParent:GetEffectiveScale()
    local px     = (x * scale - ux * us) / us
    local py     = (y * scale - uy * us) / us
    dodoDB.Debuff        = dodoDB.Debuff or {}
    dodoDB.Debuff.xpoint = px
    dodoDB.Debuff.ypoint = py
    dodoDB.debuffX       = px
    dodoDB.debuffY       = py
end

local function load_position()
    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("Debuff")
    if not main_frame then return end
    main_frame:ClearAllPoints()
    if anchorFrame then
        local slot_w   = configs.size + configs.gap
        local offset_x = slot_w * (configs.max_debuffs - 1) / 2
        main_frame:SetPoint("CENTER", anchorFrame, "CENTER", offset_x, 0)
    else
        local tx = dodoDB.debuffX or (dodoDB.Debuff and dodoDB.Debuff.xpoint) or 350
        local ty = dodoDB.debuffY or (dodoDB.Debuff and dodoDB.Debuff.ypoint) or 0
        main_frame:SetPoint("CENTER", UIParent, "CENTER", tx, ty)
    end
end

-- ==============================
-- 설정 업데이트
-- ==============================
local function update_debuff_option()
    if not main_frame then return end

    configs.size        = dodoDB.debuffSize or 56
    configs.max_debuffs = dodoDB.debuffMax  or 6
    if dodoDB.debuffClickthrough ~= nil then
        configs.clickthrough = dodoDB.debuffClickthrough
    else
        configs.clickthrough = true
    end

    load_position()

    local w  = configs.size
    local h  = configs.size * configs.sizerate
    local dw = (w + configs.gap) * configs.max_debuffs
    local pw = (w + configs.gap) * configs.max_private

    if private_frame then
        private_frame:SetSize(pw, h)
        if private_frame.PrivateAuraAnchors then
            for idx, frame in ipairs(private_frame.PrivateAuraAnchors) do
                frame:SetSize(w, h)
                frame:ClearAllPoints()
                if idx == 1 then
                    frame:SetPoint("LEFT", private_frame, "LEFT", 0, 0)
                else
                    frame:SetPoint("LEFT", private_frame.PrivateAuraAnchors[idx - 1], "RIGHT", configs.gap, 0)
                end
            end
        end
    end

    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("Debuff")
    if anchorFrame then
        anchorFrame:SetSize(dw + (w + configs.gap) + configs.gap * 2, h)
    end

    local is_enabled = dodoDB and dodoDB.useDebuff ~= false
    if is_enabled then
        build_container()
        for button in pairs(debuff_buttons) do
            configure_button(button)
        end
        if private_frame and private_frame.PrivateAuraAnchors then
            for _, frame in ipairs(private_frame.PrivateAuraAnchors) do
                frame:SetUnit("player")
            end
        end
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        main_frame:RegisterEvent("PLAYER_LOGOUT")
    else
        if debuff_container then
            debuff_container:SetEnabled(false)
            debuff_container:Hide()
        end
        if debuff_anchor then debuff_anchor:Hide() end
        if private_frame and private_frame.PrivateAuraAnchors then
            for _, frame in ipairs(private_frame.PrivateAuraAnchors) do
                frame:SetUnit(nil)
            end
        end
        main_frame:UnregisterAllEvents()
    end

    if is_preview_active then show_preview_data() end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
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

    configs.size        = dodoDB.debuffSize or configs.size
    configs.max_debuffs = dodoDB.debuffMax  or configs.max_debuffs
    if dodoDB.debuffClickthrough ~= nil then
        configs.clickthrough = dodoDB.debuffClickthrough
    end

    main_frame:SetFrameStrata("MEDIUM")
    main_frame:SetSize(1, 1)
    load_position()
    main_frame:Show()

    local w  = configs.size
    local h  = configs.size * configs.sizerate
    local pw = (w + configs.gap) * configs.max_private

    private_frame = CreateFrame("Frame", nil, main_frame)
    private_frame:SetSize(pw, h)
    private_frame:SetPoint("LEFT", main_frame, "CENTER", configs.gap, 0)
    private_frame:Show()
    create_private_frames(private_frame)
    dodo.private_frame = private_frame

    local dw          = (w + configs.gap) * configs.max_debuffs
    local anchorFrame = dodo.EditMode and dodo.EditMode:GetSystem("Debuff")
    if anchorFrame then
        anchorFrame:SetSize(dw + (w + configs.gap) + configs.gap * 2, h)
    end

    main_frame:SetScript("OnEvent", on_event)

    if dodoDB and dodoDB.useDebuff ~= false then
        build_container()
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        main_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        main_frame:RegisterEvent("PLAYER_LOGOUT")
    end
end

local function on_login_event(self)
    if dodo.EditMode then
        dodo.EditMode:CreateSystem("Debuff", "디버프", "디버프 표시기", UIParent, 120, 60,
            { point="RIGHT", relativeTo="UIParent", relativePoint="CENTER", xOfs=396, yOfs=0 },
            function(point)
                if dodoDB then
                    dodoDB.debuffX = point.xOfs
                    dodoDB.debuffY = point.yOfs
                end
                load_position()
            end,
            function() return dodoDB and dodoDB.useDebuff ~= false end
        )
    end
    init_frames()

    local em = _G.dodoEditModeDebuff
    if em then
        em:HookScript("OnShow", show_preview_data)
        em:HookScript("OnHide", hide_preview_data)
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
            get  = function() return dodoDB and dodoDB.useDebuff ~= false end,
            set  = function(checked)
                if dodoDB then dodoDB.useDebuff = checked end
                update_debuff_option()
            end,
        },
    })
end

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting("Debuff", {
        {
            name     = "클릭스루 (클릭 무시)",
            get      = function() return dodoDB and dodoDB.debuffClickthrough ~= false end,
            set      = function(checked)
                if dodoDB then dodoDB.debuffClickthrough = checked end
                update_debuff_option()
            end,
            disabled = function() return dodoDB and dodoDB.useDebuff == false end,
        },
        {
            name     = "클릭스루 시 툴팁 표시",
            get      = function() return dodoDB and dodoDB.debuffClickthroughTooltip ~= false end,
            set      = function(checked)
                if dodoDB then dodoDB.debuffClickthroughTooltip = checked end
                update_debuff_option()
            end,
            disabled = function() return dodoDB and (dodoDB.useDebuff == false or dodoDB.debuffClickthrough == false) end,
        },
        {
            name     = "아이콘 크기",
            type     = "slider",
            get      = function() return dodoDB and dodoDB.debuffSize or 56 end,
            set      = function(val)
                if dodoDB then dodoDB.debuffSize = val end
                update_debuff_option()
            end,
            minVal   = 30,
            maxVal   = 80,
            step     = 2,
            disabled = function() return dodoDB and dodoDB.useDebuff == false end,
        },
        {
            name     = "최대 표시 개수",
            type     = "slider",
            get      = function() return dodoDB and dodoDB.debuffMax or 6 end,
            set      = function(val)
                if dodoDB then dodoDB.debuffMax = val end
                update_debuff_option()
            end,
            minVal   = 1,
            maxVal   = 6,
            step     = 1,
            disabled = function() return dodoDB and dodoDB.useDebuff == false end,
        },
    })
end
