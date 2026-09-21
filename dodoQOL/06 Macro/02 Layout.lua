-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo

local BASE_WIDTH   = 338
local BASE_HEIGHT  = 424
local TARGET_WIDTH = 500

-- ==============================
-- 캐싱
-- ==============================
local SetUIPanelAttribute    = SetUIPanelAttribute
local UpdateUIPanelPositions = UpdateUIPanelPositions
local math_floor             = math.floor

-- ==============================
-- 유틸
-- ==============================
local function clamp(v, mn, mx)
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end

-- ==============================
-- BASE 크기로 복원
-- ==============================
local function reset_macro_frame_layout()
    if not MacroFrame then return end

    MacroFrame:SetSize(BASE_WIDTH, BASE_HEIGHT)

    if MacroFrame.MacroSelector then
        local sel = MacroFrame.MacroSelector
        sel:SetSize(BASE_WIDTH - 19, 146)
        sel:ClearAllPoints()
        sel:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 12, -66)
        if sel.SetCustomPadding then sel:SetCustomPadding(5, 5, 5, 5, 13, 13) end
        if sel.SetCustomStride  then sel:SetCustomStride(6)                   end
        if sel.initialized and sel.Init then
            sel.initialized = false; sel:Init()
        elseif sel.UpdateSelections then
            sel:UpdateSelections()
        end
    end

    if MacroHorizontalBarLeft then
        MacroHorizontalBarLeft:SetWidth(BASE_WIDTH - 82)
        MacroHorizontalBarLeft:ClearAllPoints()
        MacroHorizontalBarLeft:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 2, -210)
    end

    if MacroFrameSelectedMacroBackground then
        MacroFrameSelectedMacroBackground:ClearAllPoints()
        MacroFrameSelectedMacroBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 5, -218)
    end

    if MacroFrameSelectedMacroName then
        MacroFrameSelectedMacroName:SetWidth(BASE_WIDTH - 82)
        MacroFrameSelectedMacroName:ClearAllPoints()
        MacroFrameSelectedMacroName:SetPoint("TOPLEFT", MacroFrameSelectedMacroBackground, "TOPRIGHT", -4, -10)
    end

    if MacroFrameTextBackground then
        MacroFrameTextBackground:SetSize(BASE_WIDTH - 16, 95)
        MacroFrameTextBackground:ClearAllPoints()
        MacroFrameTextBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 6, -289)
    end

    if MacroFrameScrollFrame then
        local sw = BASE_WIDTH - 52
        MacroFrameScrollFrame:SetSize(sw, 85)
        MacroFrameScrollFrame:ClearAllPoints()
        MacroFrameScrollFrame:SetPoint("TOPLEFT", MacroFrameSelectedMacroBackground, "BOTTOMLEFT", 11, -13)
        if MacroFrameText       then MacroFrameText:SetSize(sw, 85)       end
        if MacroFrameTextButton then MacroFrameTextButton:SetSize(sw, 85) end
    end

    SetUIPanelAttribute(MacroFrame, "width", BASE_WIDTH)
    if MacroFrame:IsShown() then UpdateUIPanelPositions(MacroFrame) end
end

-- ==============================
-- 가로 확장
-- ==============================
local function apply_macro_frame_layout()
    if not MacroFrame then return end

    if dodoDB and dodoDB.enableMacro == false then
        reset_macro_frame_layout()
        return
    end

    MacroFrame:SetSize(TARGET_WIDTH, BASE_HEIGHT)

    if MacroFrame.MacroSelector then
        local selector_width = TARGET_WIDTH - 19
        MacroFrame.MacroSelector:SetSize(selector_width, 146)
        MacroFrame.MacroSelector:ClearAllPoints()
        MacroFrame.MacroSelector:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 12, -66)

        local selector      = MacroFrame.MacroSelector
        local usable_width  = selector_width - 32
        local target_stride = 10
        local button_size   = 36
        local min_spacing   = 2
        local max_spacing   = 20
        local horiz_spacing = math_floor((usable_width - target_stride * button_size) / (target_stride - 1))
        local stride        = target_stride

        if horiz_spacing < min_spacing then
            horiz_spacing = min_spacing
            stride = clamp(
                math_floor((usable_width + horiz_spacing) / (button_size + horiz_spacing)),
                6, target_stride
            )
        elseif horiz_spacing > max_spacing then
            horiz_spacing = max_spacing
        end

        if selector.SetCustomPadding then selector:SetCustomPadding(5, 5, 5, 5, horiz_spacing, 13) end
        if selector.SetCustomStride  then selector:SetCustomStride(stride) end
        if selector.initialized and selector.Init then
            selector.initialized = false
            selector:Init()
        elseif selector.UpdateSelections then
            selector:UpdateSelections()
        end
    end

    if MacroHorizontalBarLeft then
        MacroHorizontalBarLeft:SetWidth(TARGET_WIDTH - 82)
        MacroHorizontalBarLeft:ClearAllPoints()
        MacroHorizontalBarLeft:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 2, -210)
    end

    if MacroFrameSelectedMacroBackground then
        MacroFrameSelectedMacroBackground:ClearAllPoints()
        MacroFrameSelectedMacroBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 5, -218)
    end

    if MacroFrameSelectedMacroName then
        MacroFrameSelectedMacroName:SetWidth(TARGET_WIDTH - 82)
        MacroFrameSelectedMacroName:ClearAllPoints()
        MacroFrameSelectedMacroName:SetPoint("TOPLEFT", MacroFrameSelectedMacroBackground, "TOPRIGHT", -4, -10)
    end

    if MacroFrameTextBackground then
        MacroFrameTextBackground:SetSize(TARGET_WIDTH - 16, 95)
        MacroFrameTextBackground:ClearAllPoints()
        MacroFrameTextBackground:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 6, -289)
    end

    if MacroFrameScrollFrame then
        local sw = TARGET_WIDTH - 52
        MacroFrameScrollFrame:SetSize(sw, 85)
        MacroFrameScrollFrame:ClearAllPoints()
        MacroFrameScrollFrame:SetPoint("TOPLEFT", MacroFrameSelectedMacroBackground, "BOTTOMLEFT", 11, -13)
        if MacroFrameText       then MacroFrameText:SetSize(sw, 85)       end
        if MacroFrameTextButton then MacroFrameTextButton:SetSize(sw, 85) end
    end

    SetUIPanelAttribute(MacroFrame, "width", TARGET_WIDTH)
    if MacroFrame:IsShown() then UpdateUIPanelPositions(MacroFrame) end
end

-- ==============================
-- 훅 설치
-- ==============================
local layout_hooks_installed = false

local function install_layout_hooks()
    if layout_hooks_installed or not MacroFrame then return end
    layout_hooks_installed = true
    MacroFrame:HookScript("OnShow", apply_macro_frame_layout)
    apply_macro_frame_layout()
end

dodo.Macro.ApplyLayout        = apply_macro_frame_layout
dodo.Macro.ResetLayout        = reset_macro_frame_layout
dodo.Macro.InstallLayoutHooks = install_layout_hooks
