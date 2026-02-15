-- ===================================================================
-- PainSuppressionTracker.lua
-- ArcUI 패턴: ID 캐시 유지 및 pcall 보안 비교 적용
-- FIX: pcall 반환값 방식으로 변경
-- ===================================================================

local ADDON_NAME = "PainSuppressionTracker"
local SPELL_ID = 190456
local MAX_STACKS = 100

-- ===================================================================
-- 프레임 생성
-- ===================================================================
local frame = CreateFrame("Frame", "PainSuppressionFrame", UIParent, "BackdropTemplate")
frame:SetSize(200, 30)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetBackdrop({
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.5)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)

-- 상태 바 (StatusBar)
frame.bar = CreateFrame("StatusBar", nil, frame)
frame.bar:SetPoint("TOPLEFT", 6, -6)
frame.bar:SetPoint("BOTTOMRIGHT", -6, 6)
frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
frame.bar:SetStatusBarColor(0.2, 0.8, 0.2)
frame.bar:SetMinMaxValues(0, MAX_STACKS)
frame.bar:SetValue(0)

-- 바 배경
frame.barBG = frame.bar:CreateTexture(nil, "BACKGROUND")
frame.barBG:SetAllPoints()
frame.barBG:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
frame.barBG:SetVertexColor(0.1, 0.1, 0.1, 0.5)

-- 스택 텍스트
frame.stackText = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.stackText:SetPoint("CENTER", 0, 0)
frame.stackText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
frame.stackText:SetText("0") -- 기본값

-- 상시 표시 (Hide 하지 않음)
frame:Show()

-- ===================================================================
-- 상태 변수
-- ===================================================================
local cachedAuraInstanceID = nil

-- ===================================================================
-- 핵심 업데이트 함수 (FIX: 캐시 무효화 추가)
-- ===================================================================
local function UpdateStacks()
  local auraData = nil
  
  -- 1. 캐시된 ID로 데이터 조회
  if cachedAuraInstanceID then
    auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", cachedAuraInstanceID)
    
    -- ★ 캐시된 ID가 더 이상 유효하지 않으면 무효화
    if not auraData then
      cachedAuraInstanceID = nil
    end
  end
  
  -- 2. 캐시가 없거나 무효화된 경우 → 전체 스캔
  if not auraData then
    for i = 1, 40 do
      local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
      -- spellId는 비밀값이 아니므로 직접 비교 가능!
      if data and data.spellId == SPELL_ID then
        auraData = data
        cachedAuraInstanceID = data.auraInstanceID -- 새로운 ID 캐싱
        break
      end
    end
  end

  -- 3. UI 업데이트
  if auraData then
    local stacks = auraData.applications or 1
    
    -- ★ 비밀값도 SetValue/SetText로 직접 전달
    frame.bar:SetValue(stacks)
    frame.stackText:SetText(stacks)
    
    -- 색상 변경 (pcall로 보호)
    pcall(function()
      if stacks >= 80 then
        frame.bar:SetStatusBarColor(1, 0, 0)
      elseif stacks >= 50 then
        frame.bar:SetStatusBarColor(1, 0.5, 0)
      else
        frame.bar:SetStatusBarColor(0.2, 0.8, 0.2)
      end
    end)
  else
    -- ★ 버프 없음: 캐시도 초기화 (중요!)
    cachedAuraInstanceID = nil
    frame.bar:SetValue(0)
    frame.stackText:SetText("0")
    frame.bar:SetStatusBarColor(0.5, 0.5, 0.5, 0.5)
  end
end

-- ===================================================================
-- 이벤트 및 폴링
-- ===================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", UpdateStacks)

-- 0.1초 폴링 (전투 중 실시간 감지)
C_Timer.NewTicker(0.1, UpdateStacks)

-- 초기 실행
C_Timer.After(1, UpdateStacks)

-- ===================================================================
-- 디버그 명령어
-- ===================================================================
SLASH_PAINDBG1 = "/paindbg"
SlashCmdList["PAINDBG"] = function()
  print("|cff00ccff[고통감내 디버그]|r")
  print("  cachedAuraInstanceID: " .. tostring(cachedAuraInstanceID))
  print("  InCombat: " .. tostring(InCombatLockdown()))
  
  -- 수동 스캔
  local found = false
  for i = 1, 40 do
    local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if data then
      local ok, isMatch = pcall(function()
        return data.spellId == SPELL_ID
      end)
      if ok and isMatch then
        print(string.format("  ★ 발견! Index=%d, auraInstanceID=%s, stacks=%s", 
          i, tostring(data.auraInstanceID), tostring(data.applications)))
        found = true
        break
      end
    end
  end
  if not found then
    print("  버프 없음")
  end
end