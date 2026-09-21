-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

dodo.Macro = {}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer     = C_Timer
local CreateFrame = CreateFrame

-- ==============================
-- 즉시 적용 토글 (설정창 on/off → 바로 반영)
-- ==============================
local function update_macro_visual()
    local enabled = not (dodoDB and dodoDB.enableMacro == false)
    if enabled then
        if MacroFrame then
            if dodo.Macro.InstallLayoutHooks  then dodo.Macro.InstallLayoutHooks()  end
            if dodo.Macro.InstallSearchHooks  then dodo.Macro.InstallSearchHooks()  end
            if dodo.Macro.InstallFactoryHooks then dodo.Macro.InstallFactoryHooks() end
            if MacroFrame:IsShown() then
                if dodo.Macro.ApplyLayout then dodo.Macro.ApplyLayout() end
                if dodo.Macro.ShowPanel   then dodo.Macro.ShowPanel()   end
            end
        end
    else
        if dodo.Macro.ResetLayout then dodo.Macro.ResetLayout() end
        if dodo.Macro.HidePanel   then dodo.Macro.HidePanel()   end
        if MacroPopupFrame and MacroPopupFrame.ExMacroEnhSearchBox then
            MacroPopupFrame.ExMacroEnhSearchBox:Hide()
        end
    end
end
dodo.ToggleMacroEnhancement = update_macro_visual

-- ==============================
-- 진입점
-- ADDON_LOADED → dodoQOL: dodoDB 초기화
--             → Blizzard_MacroUI: 훅 설치
-- PLAYER_LOGIN / SPELLS_CHANGED → 스펠 아이콘 맵 빌드
-- ==============================
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("SPELLS_CHANGED")

init:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "dodoQOL" then
            dodoDB = dodoDB or {}
            dodoDB.macroFactory = dodoDB.macroFactory or {}
        elseif arg1 == "Blizzard_MacroUI" then
            if dodoDB and dodoDB.enableMacro ~= false then
                C_Timer.After(0, function()
                    if dodo.Macro.InstallLayoutHooks  then dodo.Macro.InstallLayoutHooks()  end
                    if dodo.Macro.InstallSearchHooks  then dodo.Macro.InstallSearchHooks()  end
                    if dodo.Macro.InstallFactoryHooks then dodo.Macro.InstallFactoryHooks() end
                end)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        if dodo.Macro.RebuildSpellMap then dodo.Macro.RebuildSpellMap() end
    elseif event == "SPELLS_CHANGED" then
        if dodo.Macro.RebuildSpellMap then dodo.Macro.RebuildSpellMap() end
    end
end)
