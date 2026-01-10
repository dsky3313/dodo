------------------------------
-- 테이블
------------------------------
-- local addonName, ns = ...

------------------------------
-- 디스플레이
------------------------------
--

------------------------------
-- 동작
------------------------------
-- local function FuncName()
    -- local _, instanceType = GetInstanceInfo()
    -- if instanceType ~= "none" then return end
-- end

-- ns.FuncName = FuncName
------------------------------
-- 이벤트
------------------------------
-- local initFuncName = CreateFrame("Frame")
-- initFuncName:RegisterEvent("PLAYER_LOGIN")
-- initFuncName:SetScript("OnEvent", function(self, event)
--     hodoDB = hodoDB or {}
--     if FuncName then FuncName()
--     end
--     self:UnregisterAllEvents()
-- end)