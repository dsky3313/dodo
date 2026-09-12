---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local f = CreateFrame("Frame")
f:RegisterEvent("CINEMATIC_START")
f:RegisterEvent("PLAY_MOVIE")
f:SetScript("OnEvent", function(_, event)
    if dodoDB and dodoDB.useCinematicSkip == false then return end
    if not C_ChallengeMode.IsChallengeModeActive() then return end
    if event == "CINEMATIC_START" then
        CinematicFrame_CancelCinematic()
    elseif event == "PLAY_MOVIE" then
        MovieFrame:Hide()
    end
end)
