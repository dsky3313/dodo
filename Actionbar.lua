------------------------------
-- 테이블
------------------------------
local addonName, ns = ...
dodoDB = dodoDB or {}


local isEnabled = (dodoDB and dodoDB.use123 ~= false) -- DB

------------------------------
-- 디스플레이
------------------------------

------------------------------
-- 동작
------------------------------
local function FuncName()
    if isIns() then return end
end

ns.FuncName = FuncName
------------------------------
-- 이벤트
------------------------------
local initFuncName = CreateFrame("Frame")
initFuncName:RegisterEvent("PLAYER_LOGIN")
initFuncName:SetScript("OnEvent", function(self, event)
    if FuncName then FuncName()
    end
    self:UnregisterAllEvents()
end)