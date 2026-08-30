---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local math_ceil = math.ceil
local math_floor = math.floor

-- ==============================
-- 바 목록
-- ==============================
local BAR_ORDER = {
    { name = "MainActionBar",       label = "행동 단축바 1 (메인)", count = 12 },
    { name = "MultiBarBottomLeft",  label = "행동 단축바 2",        count = 12 },
    { name = "MultiBarBottomRight", label = "행동 단축바 3",        count = 12 },
    { name = "MultiBarRight",       label = "행동 단축바 4",        count = 12 },
    { name = "MultiBarLeft",        label = "행동 단축바 5",        count = 12 },
    { name = "MultiBar5",           label = "행동 단축바 6",        count = 12 },
    { name = "MultiBar6",           label = "행동 단축바 7",        count = 12 },
    { name = "MultiBar7",           label = "행동 단축바 8",        count = 12 },
    { name = "StanceBar",           label = "태세 막대",           count = 10 },
    { name = "PetActionBar",        label = "소환수 단축바",       count = 10 },
}

-- ==============================
-- 미리보기 Mixin
-- ==============================
local _preview_ref = nil
local _per_bar_refresh_fn = nil

-- 아이콘 색상 시뮬레이션 인덱스 맵 (12버튼 기준, nil = 풀컬러)
local SIM_COLORS = {
    [1]  = "gray",
    [2]  = "blue",
    [4]  = "red",
    [6]  = "blue",
    [8]  = "red",
    [10] = "blue",
    [12] = "gray",
}
local CDM_PREVIEW_BTNS = { [2] = true, [6] = true }

dodoActionbarPreviewMixin = {}

-- 현재 선택 바의 실제 버튼 크기·행수 기반 동적 높이 반환
dodoActionbarPreviewMixin.GetExtent = function()
    local barName   = (dodoDB and dodoDB.actionbarOptionSelectedBar) or "MainActionBar"
    local barFrame  = _G[barName]
    local num_rows  = math.max(1, (barFrame and barFrame.numRows) or 1)
    local spacing   = (barFrame and barFrame.buttonPadding) or 2
    -- 실제 버튼 컨테이너 크기 읽기 (Edit Mode 스케일 반영)
    local btn_size  = 36
    local containers = barFrame and barFrame.shownButtonContainers
    if containers and containers[1] then
        local w = math_floor(containers[1]:GetWidth() + 0.5)
        if w > 0 then btn_size = w end
    end
    return num_rows * btn_size + (num_rows - 1) * spacing + 112
end

function dodoActionbarPreviewMixin:OnLoad()
    _preview_ref = self
    self.btn_frames = {}
    for i = 1, 12 do
        local bf = CreateFrame("Frame", nil, self)
        bf:Hide()

        -- 슬롯 배경 (SlotBackground)
        local slot_bg = bf:CreateTexture(nil, "BACKGROUND", nil, -1)
        slot_bg:SetAllPoints()
        slot_bg:SetAtlas("UI-HUD-ActionBar-IconFrame-Background", false)

        -- 슬롯 아트 (SlotArt)
        local slot_art = bf:CreateTexture(nil, "BACKGROUND", nil, 0)
        slot_art:SetAllPoints()
        slot_art:SetAtlas("ui-hud-actionbar-iconframe-slot", false)

        -- 아이콘 (2px inset: border OVERLAY의 모서리 장식이 icon 모서리를 덮음)
        local icon = bf:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT",     bf, "TOPLEFT",     2, -2)
        icon:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -2,  2)

        -- 테두리 (NormalTexture 동일 아틀라스)
        local border = bf:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetAtlas("UI-HUD-ActionBar-IconFrame", false)

        -- CDM 미리보기 overlay (InnerGlow + time + stack)
        local cdm_f = CreateFrame("Frame", nil, bf)
        cdm_f:SetAllPoints(bf)
        cdm_f:Hide()

        local cdm_glow = cdm_f:CreateTexture(nil, "OVERLAY", nil, 2)
        cdm_glow:SetAllPoints()
        cdm_glow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", false)
        cdm_glow:SetVertexColor(0, 1, 0, 1)

        local cdm_time = cdm_f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        cdm_time:SetPoint("TOPLEFT", cdm_f, "TOPLEFT", 5, -5)
        cdm_time:SetTextColor(0, 1, 0, 1)
        cdm_time:SetText("12")

        local cdm_count = cdm_f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        cdm_count:SetPoint("BOTTOMRIGHT", cdm_f, "BOTTOMRIGHT", -5, 5)
        cdm_count:SetTextColor(1, 1, 0, 1)
        cdm_count:SetText("2")

        self.btn_frames[i] = { frame = bf, icon = icon, cdm_overlay = cdm_f }
    end
end

function dodoActionbarPreviewMixin:OnTabSelected(tabIndex)
    local info = BAR_ORDER[tabIndex]
    if info and dodoDB then
        dodoDB.actionbarOptionSelectedBar = info.name
    end
    if _per_bar_refresh_fn then _per_bar_refresh_fn() end
end

function dodoActionbarPreviewMixin:Update()
    local barName  = (dodoDB and dodoDB.actionbarOptionSelectedBar) or "MainActionBar"
    local barFrame = _G[barName]

    -- shownButtonContainers 기반: 실제 바 순서·개수 그대로
    local containers = barFrame and barFrame.shownButtonContainers
    local count = containers and #containers or 0
    if count == 0 then
        for i = 1, 12 do self.btn_frames[i].frame:Hide() end
        return
    end

    local num_rows   = barFrame.numRows or 1
    if num_rows < 1 then num_rows = 1 end

    -- 실제 바와 같은 stride 계산
    local is_horiz  = barFrame.isHorizontal ~= false
    local add_right = barFrame.addButtonsToRight ~= false
    local add_top   = barFrame.addButtonsToTop == true

    local cols, rows
    if is_horiz then
        cols = math_ceil(count / num_rows)
        rows = num_rows
    else
        rows = math_ceil(count / num_rows)
        cols = num_rows
    end

    -- 패딩 값 반영
    local spacing = 2
    local PADDING_DB_KEYS  = dodo.AB_PADDING_DB_KEYS
    local PADDING_VAL_KEYS = dodo.AB_PADDING_VAL_KEYS
    local PADDING_DEFAULTS = dodo.AB_PADDING_DEFAULTS
    if PADDING_DB_KEYS and PADDING_VAL_KEYS then
        local en_key  = PADDING_DB_KEYS[barName]
        local val_key = PADDING_VAL_KEYS[barName]
        local enabled = dodoDB and en_key and dodoDB[en_key]
        if enabled == nil and PADDING_DEFAULTS then enabled = PADDING_DEFAULTS[barName] end
        if enabled and val_key and dodoDB then
            local v = dodoDB[val_key]
            if v ~= nil then spacing = v end
        end
    end

    -- 실제 버튼 컨테이너 크기 (Edit Mode 스케일 반영)
    local BTN_SIZE = 36
    if containers[1] then
        local w = math_floor(containers[1]:GetWidth() + 0.5)
        if w > 0 then BTN_SIZE = w end
    end

    local grid_w = cols * BTN_SIZE + (cols - 1) * spacing
    local grid_h = rows * BTN_SIZE + (rows - 1) * spacing
    -- self 기준 중앙정렬 오프셋 (InitFrame 이후라 GetWidth/GetHeight 유효)
    local off_x  = (self:GetWidth()  - grid_w) / 2
    local off_y  = 40

    -- 색상 시뮬레이션 여부
    local sim_color_enabled = false
    do
        local keys = dodo.AB_COLOR_DB_KEYS
        local defs = dodo.AB_COLOR_DEFAULTS
        if keys then
            local dbKey = keys[barName]
            local val   = dodoDB and dbKey and dodoDB[dbKey]
            if val == nil then val = defs and defs[barName] or false end
            sim_color_enabled = val == true
        end
    end
    local sim_range_c = (dodo.Colors and dodo.Colors.ActionbarIconColor and dodo.Colors.ActionbarIconColor.Range)
                     or { r = 0.77, g = 0.12, b = 0.23 }
    local sim_mana_c  = (dodo.Colors and dodo.Colors.ActionbarIconColor and dodo.Colors.ActionbarIconColor.Mana)
                     or { r = 0.10, g = 0.30, b = 1.00 }

    -- CDM 미리보기 여부
    local sim_cdm_enabled = false
    do
        local keys = dodo.AB_CDM_DB_KEYS
        local defs = dodo.AB_CDM_DEFAULTS
        if keys then
            local dbKey = keys[barName]
            local val   = dodoDB and dbKey and dodoDB[dbKey]
            if val == nil then val = defs and defs[barName] or false end
            sim_cdm_enabled = val == true
        end
    end

    for i = 1, 12 do
        local entry = self.btn_frames[i]
        local container = containers[i]
        if container then
            -- 행·열 인덱스 (0-based)
            local col_idx, row_idx
            if is_horiz then
                col_idx = (i - 1) % cols
                row_idx = math_floor((i - 1) / cols)
            else
                row_idx = (i - 1) % rows
                col_idx = math_floor((i - 1) / rows)
            end

            -- 방향 반전
            if not add_right then col_idx = cols - 1 - col_idx end
            if add_top       then row_idx = rows - 1 - row_idx end

            local x =  col_idx * (BTN_SIZE + spacing)
            local y = -(row_idx * (BTN_SIZE + spacing))

            entry.frame:SetSize(BTN_SIZE, BTN_SIZE)
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", self, "TOPLEFT", off_x + x, -(32 + off_y) + y)
            entry.frame:Show()

            -- 아이콘: container 자체가 버튼이거나 첫 번째 자식이 버튼
            local btn = container.icon and container
                     or (container.GetChildren and select(1, container:GetChildren()))
            local tex = btn and btn.icon and btn.icon:GetTexture()
            if tex then
                entry.icon:SetTexture(tex)
                if sim_color_enabled then
                    local state = SIM_COLORS[i]
                    if state == "gray" then
                        entry.icon:SetVertexColor(1, 1, 1)
                        entry.icon:SetDesaturation(1)
                    elseif state == "blue" then
                        entry.icon:SetVertexColor(sim_mana_c.r, sim_mana_c.g, sim_mana_c.b)
                        entry.icon:SetDesaturation(1)
                    elseif state == "red" then
                        entry.icon:SetVertexColor(sim_range_c.r, sim_range_c.g, sim_range_c.b)
                        entry.icon:SetDesaturation(1)
                    else
                        entry.icon:SetVertexColor(1, 1, 1)
                        entry.icon:SetDesaturation(0)
                    end
                else
                    entry.icon:SetDesaturation(btn.icon:GetDesaturation() or 0)
                    local r, g, b = btn.icon:GetVertexColor()
                    entry.icon:SetVertexColor(r or 1, g or 1, b or 1)
                end
            else
                entry.icon:SetTexture(nil)
            end

            -- CDM 강화효과 미리보기: CDM_PREVIEW_BTNS 버튼에 overlay 표시
            if sim_cdm_enabled and CDM_PREVIEW_BTNS[i] and tex then
                entry.cdm_overlay:Show()
            else
                entry.cdm_overlay:Hide()
            end
        else
            entry.frame:Hide()
            entry.cdm_overlay:Hide()
        end
    end
end

local function refresh_preview()
    if _preview_ref and _preview_ref.Update then
        _preview_ref:Update()
    end
end

-- 다른 모듈에서 미리보기 갱신 트리거용 (색상/패딩 apply 후 호출)
dodo.ActionbarRefreshPreview = refresh_preview

-- ==============================
-- /dd 설정 등록
-- ==============================
dodo.RegisterOption("행동 단축바", function(category)
    local COLOR_DB_KEYS    = dodo.AB_COLOR_DB_KEYS
    local HOTKEY_DB_KEYS   = dodo.AB_HOTKEY_DB_KEYS
    local MACRO_DB_KEYS    = dodo.AB_MACRO_DB_KEYS
    local PADDING_DB_KEYS  = dodo.AB_PADDING_DB_KEYS
    local PADDING_VAL_KEYS = dodo.AB_PADDING_VAL_KEYS
    local PADDING_DEFAULTS = dodo.AB_PADDING_DEFAULTS
    local PADDING_VAL_DEF  = dodo.AB_PADDING_VAL_DEFAULTS
    local CDM_DB_KEYS      = dodo.AB_CDM_DB_KEYS
    local INTR_DB_KEYS     = dodo.AB_INTERRUPT_DB_KEYS
    local POT_DB_KEYS      = dodo.AB_POTION_DB_KEYS

    -- 마스터 토글
    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableActionbar", "행동 단축바 모듈 활성화",
        "행동 단축바와 관련된 추가적인 기능을 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableActionbar = val end
            if dodo.ActionbarUpdateVisual then dodo.ActionbarUpdateVisual() end
            refresh_preview()
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    local per_bar_refresh = nil

    -- 미리보기 프레임 (커스텀 initializer: InitFrame 시점에 올바른 폭/높이)
    T(dodo.UI:SettingsTabbedPreview(category, {
        "바1(메인)", "바2", "바3", "바4", "바5", "바6", "바7", "바8", "태세", "소환수",
    }, dodoActionbarPreviewMixin))

    -- 바 설정 섹션 (선택된 바 기준 프록시)
    T(dodo.UI:SettingsSectionHeader(category, "바 설정"))

    local function get_selected_bar()
        return (dodoDB and dodoDB.actionbarOptionSelectedBar) or "MainActionBar"
    end

    if PADDING_DB_KEYS then
        local pad_en_setting = Settings.RegisterProxySetting(
            category, "dodo_ab_pad_en_sel", Settings.VarType.Boolean, "아이콘 간격",
            false,
            function()
                local bar = get_selected_bar()
                local key = PADDING_DB_KEYS[bar]
                if not key or not dodoDB then return PADDING_DEFAULTS and PADDING_DEFAULTS[bar] or false end
                local v = dodoDB[key]
                return v == nil and (PADDING_DEFAULTS and PADDING_DEFAULTS[bar] or false) or v
            end,
            function(val)
                local bar = get_selected_bar()
                local key = PADDING_DB_KEYS[bar]
                if key and dodoDB then dodoDB[key] = val end
                local frame = _G[bar]
                if frame and dodo.ActionbarUpdatePadding then dodo.ActionbarUpdatePadding(frame) end
                refresh_preview()
            end
        )

        local pad_val_setting = Settings.RegisterProxySetting(
            category, "dodo_ab_pad_val_sel", Settings.VarType.Number, "아이콘 간격 값",
            0,
            function()
                local bar = get_selected_bar()
                local key = PADDING_VAL_KEYS and PADDING_VAL_KEYS[bar]
                if not key or not dodoDB then return PADDING_VAL_DEF and PADDING_VAL_DEF[bar] or 0 end
                local v = dodoDB[key]
                return v == nil and (PADDING_VAL_DEF and PADDING_VAL_DEF[bar] or 0) or v
            end,
            function(val)
                local bar = get_selected_bar()
                local key = PADDING_VAL_KEYS and PADDING_VAL_KEYS[bar]
                if key and dodoDB then dodoDB[key] = val end
                local frame = _G[bar]
                if frame and dodo.ActionbarUpdatePadding then dodo.ActionbarUpdatePadding(frame) end
                refresh_preview()
            end
        )

        local sliderOptions = Settings.CreateSliderOptions(-5, 10, 1)
        sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(v) return tostring(math_floor((v or 0) + 0.5)) end)

        local pad_data = {
            name          = "아이콘 간격",
            tooltip       = "버튼 사이 간격(px)을 조정합니다.",
            cbSetting     = pad_en_setting,
            sliderSetting = pad_val_setting,
            sliderOptions = sliderOptions,
        }
        local layout = SettingsPanel:GetLayout(category)
        local pad_init = Settings.CreateSettingInitializer("dodoCheckboxSliderTemplate", pad_data)
        if layout then layout:AddInitializer(pad_init) end
        T(pad_init)

        local function read_src_padding()
            local src = get_selected_bar()
            local en_key  = PADDING_DB_KEYS[src]
            local val_key = PADDING_VAL_KEYS and PADDING_VAL_KEYS[src]
            local en_val  = (dodoDB and en_key and dodoDB[en_key])
            if en_val == nil then en_val = PADDING_DEFAULTS and PADDING_DEFAULTS[src] or false end
            local pad_val = (dodoDB and val_key and dodoDB[val_key])
            if pad_val == nil then pad_val = PADDING_VAL_DEF and PADDING_VAL_DEF[src] or 0 end
            return en_val, pad_val
        end

        local function apply_padding_to(bar_name, en_val, pad_val)
            local en_key  = PADDING_DB_KEYS[bar_name]
            local val_key = PADDING_VAL_KEYS and PADDING_VAL_KEYS[bar_name]
            if en_key  and dodoDB then dodoDB[en_key]  = en_val  end
            if val_key and dodoDB then dodoDB[val_key] = pad_val end
            if dodo.ActionbarUpdatePadding then dodo.ActionbarUpdatePadding(_G[bar_name]) end
        end

        -- 모두 적용 버튼
        local all_apply_init
        if layout and CreateSettingsButtonInitializer then
            all_apply_init = CreateSettingsButtonInitializer(
                "", "모두 적용",
                function()
                    local en_val, pad_val = read_src_padding()
                    for _, info in ipairs(BAR_ORDER) do
                        if PADDING_DB_KEYS[info.name] then
                            apply_padding_to(info.name, en_val, pad_val)
                        end
                    end
                    refresh_preview()
                end,
                "현재 바의 아이콘 간격을 모든 액션바에 적용합니다.", false
            )
            layout:AddInitializer(all_apply_init)
            T(all_apply_init)
            if all_apply_init and pad_init and all_apply_init.SetParentInitializer then
                all_apply_init:SetParentInitializer(pad_init, function()
                    return pad_en_setting:GetValue() == true
                end)
            end
        end

        per_bar_refresh = function()
            pad_en_setting:SetValue(pad_en_setting:GetValue())
            pad_val_setting:SetValue(pad_val_setting:GetValue())
        end
        _per_bar_refresh_fn = per_bar_refresh
    end

    -- 아이콘 섹션
    T(dodo.UI:SettingsSectionHeader(category, "아이콘"))

    if COLOR_DB_KEYS then
        local color_items = {}
        for _, info in ipairs(BAR_ORDER) do
            if COLOR_DB_KEYS[info.name] then
                color_items[#color_items + 1] = { text = info.label, key = COLOR_DB_KEYS[info.name] }
            end
        end
        if #color_items > 0 then
            T(dodo.UI:SettingsMultiDropDown(category, "아이콘 색상", color_items, function(key, selected)
                if dodoDB then dodoDB[key] = selected end
                if dodo.ActionbarApplyColor then dodo.ActionbarApplyColor() end
                refresh_preview()
            end))
        end
    end

    if CDM_DB_KEYS then
        local cdm_items = {}
        for _, info in ipairs(BAR_ORDER) do
            if CDM_DB_KEYS[info.name] then
                cdm_items[#cdm_items + 1] = { text = info.label, key = CDM_DB_KEYS[info.name] }
            end
        end
        if #cdm_items > 0 then
            T(dodo.UI:SettingsMultiDropDown(category, "강화 효과 표시", cdm_items, function(key, selected)
                if dodoDB then dodoDB[key] = selected end
                if dodo.BuildSpecialButtonCache then dodo.BuildSpecialButtonCache() end
                if dodo.ActionbarApplyCDM then dodo.ActionbarApplyCDM() end
            end))
        end
    end

    if INTR_DB_KEYS then
        local intr_items = {}
        for _, info in ipairs(BAR_ORDER) do
            if INTR_DB_KEYS[info.name] then
                intr_items[#intr_items + 1] = { text = info.label, key = INTR_DB_KEYS[info.name] }
            end
        end
        if #intr_items > 0 then
            T(dodo.UI:SettingsMultiDropDown(category, "차단 알림", intr_items, function(key, selected)
                if dodoDB then dodoDB[key] = selected end
                if dodo.ActionbarApplyInterrupt then dodo.ActionbarApplyInterrupt() end
            end))
        end
    end

    if POT_DB_KEYS then
        local pot_items = {}
        for _, info in ipairs(BAR_ORDER) do
            if POT_DB_KEYS[info.name] then
                pot_items[#pot_items + 1] = { text = info.label, key = POT_DB_KEYS[info.name] }
            end
        end
        if #pot_items > 0 then
            T(dodo.UI:SettingsMultiDropDown(category, "물약 사용가능 알림", pot_items, function(key, selected)
                if dodoDB then dodoDB[key] = selected end
                if dodo.ActionbarApplyPotionProc then dodo.ActionbarApplyPotionProc() end
            end))
        end
    end

    -- 문자 섹션
    T(dodo.UI:SettingsSectionHeader(category, "문자"))

    if HOTKEY_DB_KEYS then
        local hk_items = {}
        for _, info in ipairs(BAR_ORDER) do
            if HOTKEY_DB_KEYS[info.name] then
                hk_items[#hk_items + 1] = { text = info.label, key = HOTKEY_DB_KEYS[info.name] }
            end
        end
        if #hk_items > 0 then
            T(dodo.UI:SettingsMultiDropDown(category, "단축키 숨기기", hk_items, function(key, selected)
                if dodoDB then dodoDB[key] = selected end
                if dodo.ActionbarApplyText then dodo.ActionbarApplyText() end
            end))
        end
    end

    if MACRO_DB_KEYS then
        local macro_items = {}
        for _, info in ipairs(BAR_ORDER) do
            if MACRO_DB_KEYS[info.name] then
                macro_items[#macro_items + 1] = { text = info.label, key = MACRO_DB_KEYS[info.name] }
            end
        end
        if #macro_items > 0 then
            T(dodo.UI:SettingsMultiDropDown(category, "매크로명 숨기기", macro_items, function(key, selected)
                if dodoDB then dodoDB[key] = selected end
                if dodo.ActionbarApplyText then dodo.ActionbarApplyText() end
            end))
        end
    end

    local function _shown() return master_setting:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 1000)
