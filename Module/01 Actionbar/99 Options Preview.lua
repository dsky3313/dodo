---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local math_ceil   = math.ceil
local math_floor  = math.floor

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

local _preview_ref        = nil
local _per_bar_refresh_fn = nil

dodoActionbarPreviewMixin = {}

-- 현재 선택 바의 실제 버튼 크기·행수 기반 동적 높이 반환
dodoActionbarPreviewMixin.GetExtent = function()
    local barName    = (dodoDB and dodoDB.actionbarOptionSelectedBar) or "MainActionBar"
    local barFrame   = _G[barName]
    local num_rows   = math.max(1, (barFrame and barFrame.numRows) or 1)
    local spacing    = (barFrame and barFrame.buttonPadding) or 2
    local btn_size   = 36
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
    local BAR_ORDER = dodo.AB_BAR_ORDER
    local info = BAR_ORDER and BAR_ORDER[tabIndex]
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
    local PADDING_DB_KEYS  = dodo.AB_DB_KEYS.padding
    local PADDING_VAL_KEYS = dodo.AB_DB_KEYS.paddingVal
    local PADDING_DEFAULTS = dodo.AB_DEFAULTS.padding
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
    local off_x  = (self:GetWidth()  - grid_w) / 2
    local off_y  = 40

    -- 색상 시뮬레이션 여부
    local sim_color_enabled = false
    do
        local keys = dodo.AB_DB_KEYS.color
        local defs = dodo.AB_DEFAULTS.color
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
        local keys = dodo.AB_DB_KEYS.cdm
        local defs = dodo.AB_DEFAULTS.cdm
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
dodo.ActionbarRefreshPreview = refresh_preview

function dodo.ActionbarSetPerBarRefreshFn(fn)
    _per_bar_refresh_fn = fn
end
