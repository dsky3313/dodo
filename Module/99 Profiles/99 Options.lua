---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local IsControlKeyDown = IsControlKeyDown
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local UIParent = UIParent
local _G = _G

-- ==============================
-- 레이아웃 코드 복사 팝업
-- ==============================
local function hide_copy_popup()
    local popup = _G["dodo_LayoutCopyPopup"]
    if popup then popup:Hide() end
end

local function show_copy_popup(text, title)
    local popup = _G["dodo_LayoutCopyPopup"]
    if not popup then
        popup = CreateFrame("Frame", "dodo_LayoutCopyPopup", UIParent, "PortraitFrameTemplate")
        _G.ButtonFrameTemplate_HidePortrait(popup)
        popup:SetSize(300, 80)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("DIALOG")
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

        local eb = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        eb:SetPoint("BOTTOMLEFT",  25, 15)
        eb:SetPoint("BOTTOMRIGHT", -15, 15)
        eb:SetHeight(24)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed",    function() popup:Hide() end)
        eb:SetScript("OnEnterPressed",     function() popup:Hide() end)
        eb:SetScript("OnEditFocusGained",  function(self) self:HighlightText() end)
        eb:SetScript("OnKeyDown", function(self, key)
            if IsControlKeyDown() and key == "C" then
                PlaySound(SOUNDKIT.TELL_MESSAGE)
                C_Timer.After(0.1, hide_copy_popup)
            end
        end)
        popup.editBox = eb
    end

    popup.TitleContainer.TitleText:SetText(title or "텍스트 복사 (Ctrl+C)")
    popup.editBox:SetText(text)
    popup:Show()
    popup.editBox:SetFocus()
    popup.editBox:HighlightText()
end

-- ==============================
-- /dd 설정 등록
-- ==============================
dodo.RegisterOption("프로필", function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not (layout and CreateSettingsButtonInitializer) then return end

    dodo.UI:SettingsSectionHeader(category, "편집모드")
    layout:AddInitializer(CreateSettingsButtonInitializer(
        "", "코드 복사",
        function() show_copy_popup(dodo.Profile.editmode, "편집모드 복사 (Ctrl+C)") end,
        "", false
    ))
    layout:AddInitializer(CreateSettingsButtonInitializer(
        "", "편집모드 가져오기",
        function()
            HideUIPanel(SettingsPanel)
            EditModeManagerFrame:Show()
            local function try_show()
                if not EditModeImportLayoutDialog:IsShown() then
                    EditModeImportLayoutDialog:ShowImportLayoutDialog()
                end
            end
            C_Timer.After(0.1, try_show)
            C_Timer.After(0.5, try_show)
            C_Timer.After(1.0, try_show)
        end,
        "", false
    ))

    dodo.UI:SettingsSectionHeader(category, "플레이터")
    layout:AddInitializer(CreateSettingsButtonInitializer(
        "", "코드 복사",
        function() show_copy_popup(dodo.Profile.plater, "플레이터 복사 (Ctrl+C)") end,
        "", false
    ))
    layout:AddInitializer(CreateSettingsButtonInitializer(
        "", "플레이터 가져오기",
        function()
            if not (Plater and Plater.OpenOptionsPanel) then return end
            Plater.OpenOptionsPanel(22)
            local function try_import()
                local f = _G["PlaterOptionsPanelContainerProfileManagement"]
                if f and f.ImportProfile and not f.IsImporting then
                    f.ImportProfile()
                end
            end
            C_Timer.After(0.1, try_import)
            C_Timer.After(0.5, try_import)
            C_Timer.After(1.0, try_import)
        end,
        "", false
    ))

    dodo.UI:SettingsSectionHeader(category, "CVar")
    layout:AddInitializer(CreateSettingsButtonInitializer(
        "", "적용",
        function() dodo:SetupCVars() end,
        "", false
    ))
end, 9900)
