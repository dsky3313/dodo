---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local C_ChallengeMode = C_ChallengeMode
local CreateFrame = CreateFrame

local f = CreateFrame("Frame")

local function on_event(_, event)
    if not C_ChallengeMode.IsChallengeModeActive() then return end
    if event == "CINEMATIC_START" then
        CinematicFrame_CancelCinematic()
    elseif event == "PLAY_MOVIE" then
        MovieFrame:Hide()
    end
end

local function update_visual()
    local is_enabled = (dodoDB and dodoDB.useCinematicSkip ~= false)
    if is_enabled then
        f:RegisterEvent("CINEMATIC_START")
        f:RegisterEvent("PLAY_MOVIE")
        f:SetScript("OnEvent", on_event)
    else
        f:UnregisterAllEvents()
        f:SetScript("OnEvent", nil)
    end
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    if dodoDB and dodoDB.useCinematicSkip == nil then dodoDB.useCinematicSkip = true end
    update_visual()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

dodo.CinematicSkipUpdateVisual = update_visual
