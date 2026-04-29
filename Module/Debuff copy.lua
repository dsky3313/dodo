-- ==============================
-- Inspired
-- ==============================
-- asDebuffFilter (https://www.curseforge.com/wow/addons/asdebufffilter)
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local configs = {
    size           = 56,
    sizerate       = 1,
    max_debuffs    = 6,
    max_private    = 6,
    gap            = 4,    -- 아이콘 간격
    cool_size      = 50,   -- 쿨다운 크기
    cool_fontsize  = 18,   -- 쿨다운
    cool_x         = 0,
    cool_y         = 0,
    count_fontsize = 18,   -- 스택
    count_x        = 0,
    count_y        = 0,
    dispel_size    = 20, -- 해제 아이콘
    dispel_x       = 1,
    dispel_y       = 1,
    clickthrough   = true, -- 클릭 무시 (true시 뒤에 있는 NPC 클릭 가능)
};

local Options_Default = {
    Version = 1,
    xpoint  = 350,         -- 위치
    ypoint  = 0,
};

local debuffinfo = {
    [0]  = CreateColor(0.8, 0.8, 0.8), -- 일반 디버프
    [1]  = DEBUFF_TYPE_MAGIC_COLOR,
    [2]  = DEBUFF_TYPE_CURSE_COLOR,
    [3]  = DEBUFF_TYPE_DISEASE_COLOR,
    [4]  = DEBUFF_TYPE_POISON_COLOR,
    [9]  = DEBUFF_TYPE_BLEED_COLOR,
    [11] = DEBUFF_TYPE_BLEED_COLOR,
};

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
};

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local activeDebuffs = {};
local bsetupprivate = false;
local debuff_frame;
local debufffilter = AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful);
local main_frame = CreateFrame("Frame", nil, UIParent);
local private_frame;

-- 변수
local isSecretValue = issecretvalue or function() return false end

local colorcurve = C_CurveUtil.CreateColorCurve();
colorcurve:SetType(Enum.LuaCurveType.Step);
for dispeltype, v in pairs(debuffinfo) do
    colorcurve:AddPoint(dispeltype, v);
end

-- 탐지용 커브 생성 도우미 함수 (비교 연산 에러 방지용)
local function create_dispel_curve(type_id, alt_type_id)
    local curve = C_CurveUtil.CreateColorCurve();
    curve:SetType(Enum.LuaCurveType.Step);
    curve:AddPoint(0, CreateColor(0, 0, 0, 0));
    curve:AddPoint(type_id, CreateColor(1, 1, 1, 1));
    curve:AddPoint(type_id + 1, CreateColor(0, 0, 0, 0));
    if alt_type_id then
        curve:AddPoint(alt_type_id, CreateColor(1, 1, 1, 1));
        curve:AddPoint(alt_type_id + 1, CreateColor(0, 0, 0, 0));
    end
    return curve
end

local detect_curves = {
    Magic   = create_dispel_curve(1),
    Curse   = create_dispel_curve(2),
    Disease = create_dispel_curve(3),
    Poison  = create_dispel_curve(4),
    Bleed   = create_dispel_curve(9, 11),
};

-- ==============================
-- Private Aura Mixin
-- ==============================
dodo_PrivateAuraAnchorMixin = {};

function dodo_PrivateAuraAnchorMixin:SetUnit(unit)
    if unit == self.unit then
        return;
    end
    self.unit = unit;

    if self.anchorID then
        C_UnitAuras.RemovePrivateAuraAnchor(self.anchorID);
        self.anchorID = nil;
    end

    if unit then
        local iconAnchor = {
            point         = "CENTER",
            relativeTo    = self,
            relativePoint = "CENTER",
            offsetX       = 0,
            offsetY       = 0,
        };

        local args = {};
        args.unitToken            = unit;
        args.auraIndex            = self.auraIndex;
        args.parent               = self;
        args.showCountdownFrame   = true;
        args.showCountdownNumbers = true;
        args.isContainer          = false;
        args.iconInfo = {
            iconAnchor  = iconAnchor,
            iconWidth   = self:GetWidth(),
            iconHeight  = self:GetHeight(),
            borderScale = 2.0,
        };
        args.durationAnchor = nil;

        self.anchorID = C_UnitAuras.AddPrivateAuraAnchor(args);
    end
end


-- ==============================
-- UI 생성
-- ==============================
local function create_debuff_frames(parent)
    if parent.frames == nil then
        parent.frames = {};
    end

    local w = configs.size;
    local h = configs.size * configs.sizerate;

    for idx = 1, configs.max_debuffs do
        local frame = CreateFrame("Button", nil, parent, "dodo_DebuffFrameTemplate");
        parent.frames[idx] = frame;

        frame.cooldown:SetDrawSwipe(true);
        frame.cooldown:SetHideCountdownNumbers(false);
        frame.cooldown:ClearAllPoints();
        frame.cooldown:SetPoint("CENTER", frame.icon, "CENTER", 0, 0);
        frame.cooldown:SetSize(configs.cool_size, configs.cool_size);
        for _, r in next, { frame.cooldown:GetRegions() } do
            if r:GetObjectType() == "FontString" then
                r:SetFont(STANDARD_TEXT_FONT, configs.cool_fontsize, "OUTLINE");
                r:ClearAllPoints();
                r:SetPoint("CENTER", configs.cool_x, configs.cool_y);
                r:SetDrawLayer("OVERLAY");
                break;
            end
        end

        frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
        frame.icon:ClearAllPoints();
        frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4);
        frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4);
        frame.border:ClearAllPoints();
        frame.border:SetPoint("CENTER", frame, "CENTER", 0, 0);
        frame.border:SetSize(w, h);

        frame.count:SetFont(STANDARD_TEXT_FONT, configs.count_fontsize, "OUTLINE");
        frame.count:ClearAllPoints();
        frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", configs.count_x, configs.count_y);
        frame.count:SetTextColor(1, 1, 0);

        frame:SetSize(w, h);
        frame:ClearAllPoints();

        -- 해제 타입 아이콘 설정
        local typeNames = { "Magic", "Curse", "Disease", "Poison", "Bleed" };
        for _, name in ipairs(typeNames) do
            local dispelIcon = frame["dispel" .. name];
            if dispelIcon then
                dispelIcon:SetSize(configs.dispel_size, configs.dispel_size);
                dispelIcon:ClearAllPoints();
                dispelIcon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", configs.dispel_x, configs.dispel_y);
            end
        end

        if idx == 1 then
            frame:SetPoint("RIGHT", parent, "RIGHT", 0, 0);
        else
            frame:SetPoint("RIGHT", parent.frames[idx - 1], "LEFT", -configs.gap, 0);
        end

        frame:SetScript("OnEnter", function(self)
            if self.auraid then
                GameTooltip_SetDefaultAnchor(GameTooltip, self);
                GameTooltip:SetUnitDebuffByAuraInstanceID(self.unit, self.auraid, debufffilter);
            end
        end);
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);

        if configs.clickthrough then
            frame:EnableMouse(false);
            if frame.SetMouseClickEnabled then
                frame:SetMouseClickEnabled(false);
            end
            -- 클릭스루 상태에서도 툴팁을 보고 싶다면 아래 값을 true로 변경
            frame:SetMouseMotionEnabled(true);
        else
            frame:EnableMouse(true);
            frame:SetMouseMotionEnabled(true);
        end
        frame:Hide();
    end
end

local function create_private_frames(parent)
    if parent.PrivateAuraAnchors == nil then
        parent.PrivateAuraAnchors = {};
    end

    if UnitAffectingCombat("player") then
        return;
    end

    bsetupprivate = true;

    local w = configs.size;
    local h = configs.size * configs.sizerate;

    for idx = 1, configs.max_private do
        local frame = CreateFrame("Frame", nil, parent, "dodo_PrivateAuraAnchorTemplate");
        parent.PrivateAuraAnchors[idx] = frame;

        frame.auraIndex = idx;
        frame:SetSize(w, h);
        frame:ClearAllPoints();

        -- private는 왼쪽에서 오른쪽으로 (중앙 기준 오른쪽으로 뻗어나감)
        if idx == 1 then
            frame:SetPoint("LEFT", parent, "LEFT", 0, 0);
        else
            frame:SetPoint("LEFT", parent.PrivateAuraAnchors[idx - 1], "RIGHT", configs.gap, 0);
        end

        frame:SetUnit("player");
    end
end

-- ============================================================
-- 디버프 로직
-- ============================================================

local function set_cooldownframe(cooldown, durationobject, enable)
    if enable and durationobject then
        cooldown:SetDrawEdge(false);
        cooldown:ClearAllPoints();
        cooldown:SetPoint("CENTER", cooldown:GetParent().icon or cooldown:GetParent(), "CENTER", 0, 0);
        cooldown:SetSize(configs.cool_size, configs.cool_size);
        for _, r in next, { cooldown:GetRegions() } do
            if r:GetObjectType() == "FontString" then
                r:SetFont(STANDARD_TEXT_FONT, configs.cool_fontsize, "OUTLINE");
                r:ClearAllPoints();
                r:SetPoint("CENTER", configs.cool_x, configs.cool_y);
                r:SetDrawLayer("OVERLAY");
                break;
            end
        end

        cooldown:SetCooldownFromDurationObject(durationobject);
        cooldown:Show();
    else
        cooldown:Clear();
        cooldown:Hide();
    end
end

local function update_debuff_frames()
    local auraList = activeDebuffs["player"];
    if not auraList then return end

    local shown = 0;

    for _, aura in ipairs(auraList) do
        shown = shown + 1;
        if shown > configs.max_debuffs then
            break;
        end

        local frame = debuff_frame.frames[shown];
        frame.unit   = "player";
        frame.auraid = aura.auraInstanceID;

        frame.icon:SetTexture(aura.icon);
        frame.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount("player", aura.auraInstanceID, 1, 100));

        local durationobject = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID);
        set_cooldownframe(frame.cooldown, durationobject, true);

        local color = C_UnitAuras.GetAuraDispelTypeColor("player", aura.auraInstanceID, colorcurve);
        if color then
            frame.border:SetVertexColor(color.r, color.g, color.b);
        else
            frame.border:SetVertexColor(0, 0, 0);
        end

        -- 각 타입별 디버프 아이콘 처리 (비교 연산 없이 알파값으로 제어)
        local typeNames = { "Magic", "Curse", "Disease", "Poison", "Bleed" };
        for _, name in ipairs(typeNames) do
            local detectColor = C_UnitAuras.GetAuraDispelTypeColor("player", aura.auraInstanceID, detect_curves[name]);
            local dispelIcon = frame["dispel" .. name];
            if dispelIcon then
                dispelIcon:SetAlpha(detectColor and detectColor.a or 0);
                dispelIcon:Show();
            end
        end

        frame:Show();
    end

    for j = shown + 1, configs.max_debuffs do
        if debuff_frame.frames[j] then
            debuff_frame.frames[j]:Hide();
        end
    end
end

local function update_auras()
    local auras = C_UnitAuras.GetUnitAuras("player", debufffilter);
    local filteredAuras = {};
    
    if auras then
        for _, aura in ipairs(auras) do
            local sid = aura.spellId
            local isFiltered = false
            
            if sid then
                -- 비밀값 우회: 문자열 변환 후 다시 숫자로 변경하여 필터 체크
                local safeSid = tonumber(tostring(sid));
                if safeSid and filterList[safeSid] then
                    isFiltered = true;
                end
            end
            
            if not isFiltered then
                table.insert(filteredAuras, aura);
                if #filteredAuras >= configs.max_debuffs then
                    break;
                end
            end
        end
    end
    
    activeDebuffs["player"] = filteredAuras;
    update_debuff_frames();
end

-- ==============================
-- 위치 저장
-- ==============================
local function save_position()
    local x, y = main_frame:GetCenter();
    local scale = main_frame:GetEffectiveScale();
    local ux, uy = UIParent:GetCenter();
    local us = UIParent:GetEffectiveScale();
    dodoDB.Debuff.xpoint = (x * scale - ux * us) / us;
    dodoDB.Debuff.ypoint = (y * scale - uy * us) / us;
    dodoDB.dodo_debuffX = dodoDB.Debuff.xpoint;
    dodoDB.dodo_debuffY = dodoDB.Debuff.ypoint;
end

local function load_position()
    local targetX = dodoDB.dodo_debuffX or (dodoDB.Debuff and dodoDB.Debuff.xpoint) or 350;
    local targetY = dodoDB.dodo_debuffY or (dodoDB.Debuff and dodoDB.Debuff.ypoint) or 0;
    main_frame:SetPoint("CENTER", UIParent, "CENTER", targetX, targetY);
end

-- ==============================
-- 설정 업데이트 (설정창용)
-- ==============================
function dodo.UpdateDebuffOption()
    if not main_frame or not debuff_frame then return end

    configs.size = dodoDB.dodo_debuffSize or 56
    configs.max_debuffs = dodoDB.dodo_debuffMax or 6
    if dodoDB.dodo_debuffClickthrough ~= nil then
        configs.clickthrough = dodoDB.dodo_debuffClickthrough
    else
        configs.clickthrough = true
    end

    load_position()

    local icon_w = configs.size
    local icon_h = configs.size * configs.sizerate
    local debuff_w = (icon_w + configs.gap) * configs.max_debuffs
    local private_w = (icon_w + configs.gap) * configs.max_private

    debuff_frame:SetSize(debuff_w, icon_h)
    private_frame:SetSize(private_w, icon_h)

    for idx, frame in pairs(debuff_frame.frames) do
        frame:SetSize(icon_w, icon_h)
        if frame.border then frame.border:SetSize(icon_w, icon_h) end
        if idx > 1 then
            frame:ClearAllPoints()
            frame:SetPoint("RIGHT", debuff_frame.frames[idx - 1], "LEFT", -configs.gap, 0)
        end
        if configs.clickthrough then
            frame:EnableMouse(false)
            if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
            frame:SetMouseMotionEnabled(false)
        else
            frame:EnableMouse(true)
            frame:SetMouseMotionEnabled(true)
        end
    end
    update_auras()
end

-- ==============================
-- 이벤트
-- ==============================
local function on_event(self, event, arg1)
    if event == "UNIT_AURA" then
        update_auras();
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_auras();
        if not bsetupprivate then
            create_private_frames(private_frame);
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if not bsetupprivate then
            create_private_frames(private_frame);
        end
    elseif event == "PLAYER_LOGOUT" then
        save_position();
    end
end

local function on_update()
    update_auras();
end

-- ==============================
-- 초기화
-- ==============================
local function init_frames()
    if dodoDB.Debuff == nil or dodoDB.Debuff.Version ~= Options_Default.Version then
        dodoDB.Debuff = CopyTable(Options_Default);
    end

    -- 초기 설정 불러오기
    configs.size = dodoDB.dodo_debuffSize or configs.size
    configs.max_debuffs = dodoDB.dodo_debuffMax or configs.max_debuffs
    if dodoDB.dodo_debuffClickthrough ~= nil then
        configs.clickthrough = dodoDB.dodo_debuffClickthrough
    end

    main_frame:SetFrameStrata("LOW");
    main_frame:SetSize(1, 1);
    load_position();
    main_frame:Show();

    local icon_w = configs.size;
    local icon_h = configs.size * configs.sizerate;
    local debuff_w = (icon_w + configs.gap) * configs.max_debuffs;
    local private_w = (icon_w + configs.gap) * configs.max_private;

    -- debuff_frame: 중앙 왼쪽
    debuff_frame = CreateFrame("Frame", nil, main_frame);
    debuff_frame:SetSize(debuff_w, icon_h);
    debuff_frame:SetPoint("RIGHT", main_frame, "CENTER", -configs.gap, 0);
    debuff_frame:Show();
    create_debuff_frames(debuff_frame);

    -- private_frame: 중앙 오른쪽
    private_frame = CreateFrame("Frame", nil, main_frame);
    private_frame:SetSize(private_w, icon_h);
    private_frame:SetPoint("LEFT", main_frame, "CENTER", configs.gap, 0);
    private_frame:Show();
    create_private_frames(private_frame);

    main_frame:RegisterUnitEvent("UNIT_AURA", "player");
    main_frame:RegisterEvent("PLAYER_ENTERING_WORLD");
    main_frame:RegisterEvent("PLAYER_REGEN_ENABLED");
    main_frame:RegisterEvent("PLAYER_REGEN_DISABLED");
    main_frame:RegisterEvent("PLAYER_LOGOUT");
    main_frame:SetScript("OnEvent", on_event);

    -- Ticker (0.2s) - asDebuffFilter 방식
    C_Timer.NewTicker(0.2, on_update);

    update_auras();
end

C_Timer.After(1, init_frames);