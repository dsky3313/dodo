-- ==============================
-- Inspired
-- ==============================
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)
-- asDebuffFilter (https://www.curseforge.com/wow/addons/asdebufffilter)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 디버프 설정 모음
local config = {
    iconSize = 50,
    spacing = 2,
    maxIcons = 10,
    maxPrivate = 5,
}

-- 필터링할 디버프 ID (포만, 탈진, 탈영병 등)
local filterList = {
    [57723]  = true, -- 소진 (영웅심)
    [57724]  = true, -- 만족함 (피의 욕망)
    [80354]  = true, -- 시간 변위 (시간왜곡)
    [264689]  = true, -- 피로 (원초적 분노)
    [390435] = true, -- 탈진 (위상의 격노)
    [26013]  = true, -- 탈영병 (Deserter)
}

-- 캐싱
-- 함수 (대소문자 구분 없이 abc 순)
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local isSecretValue = issecretvalue or function() return false end
local ipairs = ipairs
local pairs = pairs
local unpack = unpack

-- 변수
local UIParent = UIParent

-- 디스펠 색상 표
local debuffColorTable = {
    ["Magic"] = {0.2, 0.6, 1},
    ["Curse"] = {0.6, 0, 1},
    ["Disease"] = {0.6, 0.4, 0},
    ["Poison"] = {0, 0.6, 0},
    [""] = {0.7, 0.7, 0.7}, -- None (Default)
}

-- ==============================
-- 디스플레이
-- ==============================
-- 디버프 아이콘들을 담을 메인 프레임
local mainFrame = CreateFrame("Frame", "dodoPlayerDebuffMain", UIParent)
mainFrame:SetSize(1, 1)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- 화면 정중앙
mainFrame:SetFrameStrata("HIGH")

mainFrame.icons = {}
mainFrame.privateAnchors = {}

-- 개별 아이콘 생성 함수
local function CreateAuraFrame(parent, index)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(config.iconSize, config.iconSize)
    
    -- 아이콘 텍스처
    f.icon = f:CreateTexture(nil, "BACKGROUND")
    f.icon:SetAllPoints(f)
    f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- 테두리
    f.border = f:CreateTexture(nil, "OVERLAY")
    f.border:SetAllPoints(f)
    f.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    
    -- 쿨타임
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetDrawEdge(false)
    f.cooldown:SetDrawSwipe(true)
    
    -- 중첩 숫자
    f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    
    -- 마우스 툴팁
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if self.auraInstanceID then
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetUnitDebuffByAuraInstanceID("player", self.auraInstanceID, "HARMFUL")
            _G.GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    
    f:Hide()
    return f
end

-- ==============================
-- 동작 (asDebuffFilter 로직 이관)
-- ==============================

local function UpdateAuras()
    -- C_UnitAuras.GetUnitAuras를 사용하여 통째로 데이터 확보
    local auras = C_UnitAuras and C_UnitAuras.GetUnitAuras("player", "HARMFUL")
    if not auras then return end

    local visibleIndex = 1

    -- 모든 아이콘 숨김 초기화
    for _, icon in ipairs(mainFrame.icons) do icon:Hide() end

    for _, aura in ipairs(auras) do
        local sid = aura.spellId
        
        -- 보안 값(Private Aura)은 블리자드 보안 앵커가 직접 그리므로 일반 루프에선 제외
        if sid and not isSecretValue(sid) then
            -- 필터 리스트 적용
            if not filterList[sid] then
                local icon = mainFrame.icons[visibleIndex]
                if icon then
                    -- 데이터 캐싱
                    icon.auraInstanceID = aura.auraInstanceID
                    icon.icon:SetTexture(aura.icon)
                    
                    -- 중첩 숫자 및 쿨타임 (에러 방지를 위해 문자열 비교 없이 직접 대입)
                    -- minDisplayCount=2 를 통해 1중첩은 숨기기 처리
                    local count = C_UnitAuras.GetAuraApplicationDisplayCount("player", aura.auraInstanceID, 2, 100)
                    icon.count:SetText(count or "")
                    
                    local durationObj = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID)
                    if durationObj then
                        icon.cooldown:Show()
                        icon.cooldown:SetCooldownFromDurationObject(durationObj)
                    else
                        icon.cooldown:Hide()
                    end
                    
                    -- 디스펠 타입별 테두리 색상
                    local color = debuffColorTable[aura.dispelName or ""] or debuffColorTable[""]
                    icon.border:SetVertexColor(color[1], color[2], color[3])
                    
                    -- 위치 설정 (보안 앵커 뒤에 연속해서 배치)
                    local totalIdx = visibleIndex + config.maxPrivate
                    icon:ClearAllPoints()
                    icon:SetPoint("LEFT", mainFrame, "LEFT", (totalIdx - 1) * (config.iconSize + config.spacing), 0)
                    icon:Show()
                    
                    visibleIndex = visibleIndex + 1
                    if visibleIndex > (config.maxIcons - config.maxPrivate) then break end
                end
            end
        end
    end
end

-- 초기화 과정 (지연 실행으로 로딩 시 차단 방지)
local function Init()
    -- 1. 보안 오라 앵커 생성 (asDebuffFilter 방식 핵심)
    for i = 1, config.maxPrivate do
        local anchor = CreateFrame("Frame", nil, mainFrame)
        anchor:SetSize(config.iconSize, config.iconSize)
        anchor:SetPoint("LEFT", mainFrame, "LEFT", (i - 1) * (config.iconSize + config.spacing), 0)
        
        C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = "player",
            auraIndex = i,
            parent = anchor,
            showCountdownFrame = true,
            showCountdownNumbers = true,
            isContainer = false,
            iconInfo = {
                iconAnchor = { 
                    point = "CENTER", 
                    relativeTo = anchor, 
                    relativePoint = "CENTER", 
                    offsetX = 0, 
                    offsetY = 0 
                },
                iconWidth = config.iconSize - 2,
                iconHeight = config.iconSize - 2,
            },
        })
        mainFrame.privateAnchors[i] = anchor
    end

    -- 2. 일반 디버프 아이콘 생성
    for i = 1, config.maxIcons do
        mainFrame.icons[i] = CreateAuraFrame(mainFrame, i)
    end

    -- 3. 주기적 업데이트 티커 등록 (0.2초마다 보충 업데이트)
    C_Timer.NewTicker(0.2, UpdateAuras)
    
    -- 초기 데이터 로드
    UpdateAuras()
end

-- ==============================
-- 이벤트
-- ==============================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event)
    UpdateAuras()
end)

-- 로딩 1초 후 안정적으로 초기화 실행
C_Timer.After(1, Init)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.DebuffUpdate = UpdateAuras