---@diagnostic disable: undefined-global
local addonName, dodo = ...

-- ==============================
-- 탭 & 페이지 헬퍼
-- ==============================
local function make_tab(settings, anchor_to, display_mode, tooltip, atlas, icon_size)
    local tab = CreateFrame("CheckButton", nil, settings, "LargeSideTabButtonTemplate")
    tab.displayMode   = display_mode
    tab.activeAtlas   = atlas
    tab.inactiveAtlas = atlas
    tab.tooltipText   = tooltip
    if icon_size then
        if tab.Icon then tab.Icon:Hide() end
        local tex = tab:CreateTexture(nil, "ARTWORK")
        tex:SetAtlas(atlas, false)
        tex:SetSize(icon_size, icon_size)
        tex:SetPoint("CENTER", tab, "CENTER", -5, 0)
    elseif tab.Icon then
        tab.Icon:SetAtlas(atlas, true)
    end
    tab:SetPoint("TOP", anchor_to, "BOTTOM", 0, -3)
    tab:SetCustomOnMouseUpHandler(function(t, button, upInside)
        if button == "LeftButton" and upInside then
            settings:SetDisplayMode(t.displayMode)
        end
    end)
    table.insert(settings.TabButtons, tab)
    return tab
end

local function make_page(settings)
    local scroll = settings.CooldownScroll
    local page   = CreateFrame("Frame", nil, settings)
    page:SetPoint("TOPLEFT",     scroll, "TOPLEFT")
    page:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT")
    page:Hide()
    return page
end

local function hook_set_display_mode(settings)
    local orig = settings.SetDisplayMode
    settings.SetDisplayMode = function(self, displayMode)
        local is_dodo = displayMode == "dodoPageA" or displayMode == "dodoPageB"

        if is_dodo then
            if self.displayMode == displayMode then return end

            if self.dodoPageA then self.dodoPageA:Hide() end
            if self.dodoPageB then self.dodoPageB:Hide() end

            CooldownViewerSettingsEditAlert:Hide()
            GroupBuffFilterEditVisualAlert:Hide()

            self.displayMode = displayMode
            for _, frame in ipairs(self.TabButtons) do
                frame:SetChecked(frame.displayMode == displayMode)
            end
            self.CooldownScroll:Hide()
            self.GroupBuffFilter:Hide()
            if self.dodoPageA then self.dodoPageA:SetShown(displayMode == "dodoPageA") end
            if self.dodoPageB then self.dodoPageB:SetShown(displayMode == "dodoPageB") end
        else
            if self.dodoPageA then self.dodoPageA:Hide() end
            if self.dodoPageB then self.dodoPageB:Hide() end
            orig(self, displayMode)
        end
    end
end

-- ==============================
-- 초기화
-- ==============================
local function setup()
    local settings = _G.CooldownViewerSettings
    if not settings then return end

    settings.dodoPageA = make_page(settings)
    settings.dodoPageB = make_page(settings)

    local tab_a = make_tab(settings, settings.GroupBuffsTab, "dodoPageA", "행동단축바 강조효과 강조", "Ping_Chat_Attack", 26)
    make_tab(settings, tab_a, "dodoPageB", "dodo B", "Ping_Chat_Assist", 26)

    hook_set_display_mode(settings)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    setup()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
