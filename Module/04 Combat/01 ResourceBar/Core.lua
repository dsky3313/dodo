-- ==============================
-- Inspired
-- ==============================
-- dodo

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

-- 공유 네임스페이스 정의
dodo.ResourceBar = dodo.ResourceBar or {}
local RB = dodo.ResourceBar

RB.Modes = {}
function RB:RegisterMode(name, modeTable)
    self.Modes[name] = modeTable
end

RB.bar1Frame = nil
RB.bar2Frame = nil
RB.isArcaneOrHealer = false
RB.cachedSpecColor = { r = 1.00, g = 0.59, b = 0.20 }
RB.fallbackSpecColor = { r = 1.00, g = 0.59, b = 0.20 }

RB.barConfigs = {
    { name = "ResourceBar1", width = 272, height = 10, y = -227, template = "ResourceBar1Template" },
    { name = "ResourceBar2", width = 272, height = 7, y = -4, template = "ResourceBar2Template" }
}

local anchor_frame = nil

-- ==============================
-- 캐싱
-- ==============================
local C_SpecializationInfo = C_SpecializationInfo
local CreateFrame = CreateFrame
local Enum = Enum
local InCombatLockdown = InCombatLockdown
local math = math
local Mixin = Mixin
local UIParent = UIParent
local UnitClass = UnitClass

-- ==============================
-- 공통 스펙 및 색상 갱신
-- ==============================
local function update_spec_config()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)

    -- 비법 및 힐러 여부 판별
    RB.isArcaneOrHealer = (specID == 62) or (specID == 65) or (specID == 256) or (specID == 257) or (specID == 264) or (specID == 105) or (specID == 270) or (specID == 1468)

    -- 특성 색상 캐싱
    local Colors = dodo.Colors
    RB.cachedSpecColor = (Colors and Colors.Spec and Colors.Spec[englishClass] and Colors.Spec[englishClass][spec]) or RB.fallbackSpecColor

    -- 하위 모듈 설정 갱신 유도
    if RB.UpdatePowerSpec then
        RB.UpdatePowerSpec(englishClass, spec)
    end
    if RB.UpdateTrackingSpec then
        RB.UpdateTrackingSpec(englishClass, spec)
    end
end

RB.UpdateSpecConfig = update_spec_config

-- ==============================
-- 부드러운 증감 보간 모드 (SetValue 인자로 사용, 하위 모듈 공유)
-- ==============================
local function update_smooth()
    local db = dodo.DB or dodoDB
    RB.smoothInterp = (not db or db.useResourceBarSmooth ~= false)
        and Enum.StatusBarInterpolation.ExponentialEaseOut
        or Enum.StatusBarInterpolation.Immediate
end

update_smooth()
RB.UpdateSmooth = update_smooth

-- ==============================
-- 크기 및 위치 업데이트
-- ==============================
local function update_option()
    if not RB.bar1Frame or not RB.bar2Frame then return end

    local db = dodo.DB or dodoDB
    local width = (db and db.resourceBarWidth) or RB.barConfigs[1].width or 272
    local height = (db and db.resourceBarHeight) or RB.barConfigs[1].height or 10
    local height2 = math.max(height - 3, 5)

    -- 프레임 크기 변경
    RB.bar1Frame:SetSize(width, height)
    RB.bar2Frame:SetSize(width, height2)

    -- 폰트 크기 변경
    local fontSize = (db and db.resourceBarFontSize) or dodo.COMBAT_DEFAULTS.resourceBarFontSize
    if RB.bar1Frame.countPower then
        local font, _, flags = RB.bar1Frame.countPower:GetFont()
        if font then
            RB.bar1Frame.countPower:SetFont(font, fontSize, flags)
        end
    end
    if RB.bar2Frame.countStack then
        local font, _, flags = RB.bar2Frame.countStack:GetFont()
        if font then
            RB.bar2Frame.countStack:SetFont(font, fontSize, flags)
        end
    end
    if RB.bar2Frame.countDuration then
        local font, _, flags = RB.bar2Frame.countDuration:GetFont()
        if font then
            RB.bar2Frame.countDuration:SetFont(font, fontSize, flags)
        end
    end

    -- EditMode 가상 앵커 연동 및 물리 격리 배치
    local anchorFrame = anchor_frame
    if anchorFrame then
        -- 앵커 크기 동적 갱신 (두 바의 높이 + 간격 포함)
        anchorFrame:SetSize(width, height + 4 + height2)
        
        RB.bar1Frame:ClearAllPoints()
        RB.bar1Frame:SetPoint("TOP", anchorFrame, "TOP", 0, 0)
    else
        -- 폴백 고정 배치
        local savedX = db and db.resourceBarX or 0
        local savedY = db and db.resourceBarY or RB.barConfigs[1].y
        local savedPoint = db and db.resourceBarPoint or "CENTER"
        RB.bar1Frame:ClearAllPoints()
        RB.bar1Frame:SetPoint(savedPoint, UIParent, savedPoint, savedX, savedY)
    end

    RB.bar2Frame:ClearAllPoints()
    RB.bar2Frame:SetPoint("TOP", RB.bar1Frame, "BOTTOM", 0, -4)
end

RB.UpdateOption = update_option

-- ==============================
-- 모듈 가시성 및 활성화 제어 (자원소모 0 보장)
-- ==============================
local function update_visibility()
    update_option()

    local db = dodo.DB or dodoDB
    local isEnabled = (db and db.enableResourceBarModule ~= false)

    if not isEnabled then
        RB.bar1Frame:Hide()
        RB.bar2Frame:Hide()
        if RB.TogglePowerEvents then RB.TogglePowerEvents(false) end
        if RB.ToggleTrackingEvents then RB.ToggleTrackingEvents(false) end
        if RB.CancelTickers then RB.CancelTickers() end
        return
    end

    -- 자원바1 활성화 제어
    if db and db.useResourceBar1 ~= false then
        RB.bar1Frame:Show()
        if RB.TogglePowerEvents then RB.TogglePowerEvents(true) end
        if RB.UpdateBar1 then RB.UpdateBar1() end
    else
        RB.bar1Frame:Hide()
        if RB.TogglePowerEvents then RB.TogglePowerEvents(false) end
    end

    -- 버프바2 활성화 제어
    if db and db.useResourceBar2 ~= false then
        RB.bar2Frame:Show()
        if RB.ToggleTrackingEvents then RB.ToggleTrackingEvents(true) end
        update_spec_config()
    else
        RB.bar2Frame:Hide()
        if RB.ToggleTrackingEvents then RB.ToggleTrackingEvents(false) end
        if RB.CancelTickers then RB.CancelTickers() end
    end
end

RB.UpdateVisibility = update_visibility

local function update_module_state()
    update_visibility()
end

dodo.UpdateResourceBarModuleState = update_module_state
dodo.UpdateResourceBarVisibility = update_visibility

-- ==============================
-- UI 생성 및 초기화
-- ==============================
local function create_ui()
    if RB.bar1Frame then return end

    local anchorFrame = anchor_frame

    -- 자원바1 생성
    RB.bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, RB.barConfigs[1].template)
    RB.bar1Frame:SetSize(RB.barConfigs[1].width, RB.barConfigs[1].height)
    RB.bar1Frame:SetFrameStrata("LOW")
    RB.bar1Frame:SetFrameLevel(1)

    -- 버프바2 생성
    RB.bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, RB.barConfigs[2].template)
    RB.bar2Frame:SetSize(RB.barConfigs[2].width, RB.barConfigs[2].height)
    RB.bar2Frame:SetFrameStrata("LOW")
    RB.bar2Frame:SetFrameLevel(2)

    update_option()
end

local function initialize()
    create_ui()
end

-- ==============================
-- 이벤트 및 자동 초기화
-- ==============================
local isInitialized = false
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodo.DB or dodoDB
    elseif event == "PLAYER_LOGIN" then
        dodo.DB = dodo.DB or dodoDB or {}
        update_smooth()

        local LEM = LibStub("LibEditMode")
        local _dp = { point="CENTER", relativePoint="CENTER", xOfs=0, yOfs=RB.barConfigs[1].y }
        local _sv = dodoDB.editMode and dodoDB.editMode["ResourceBar"]
        local _pt = (_sv and _sv.point) and _sv or _dp
        anchor_frame = CreateFrame("Frame", "dodoEditModeResourceBar", UIParent)
        anchor_frame:SetSize(272, 21)
        anchor_frame:SetPoint(_pt.point, UIParent, _pt.relativePoint or _pt.point, _pt.xOfs or 0, _pt.yOfs or 0)
        LEM:AddFrame(anchor_frame, function(f, l, p, x, y)
            dodoDB.editMode = dodoDB.editMode or {}
            dodoDB.editMode["ResourceBar"] = { point=p, relativeTo="UIParent", relativePoint=p, xOfs=x, yOfs=y }
            update_option()
        end, { point=_pt.point, x=_pt.xOfs or 0, y=_pt.yOfs or 0 }, "자원바")
        LEM:AddFrameSettings(anchor_frame, {
            { kind=LEM.SettingType.Checkbox, name="직업자원 막대", default=true,
              get=function(l) return dodoDB and dodoDB.useResourceBar1 ~= false end,
              set=function(l,v) if dodoDB then dodoDB.useResourceBar1=v end; if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end end },
            { kind=LEM.SettingType.Checkbox, name="보조자원 막대", default=true,
              get=function(l) return dodoDB and dodoDB.useResourceBar2 ~= false end,
              set=function(l,v) if dodoDB then dodoDB.useResourceBar2=v end; if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end end },
            { kind=LEM.SettingType.Checkbox, name="부드러운 증감", default=true,
              get=function(l) return dodoDB and dodoDB.useResourceBarSmooth ~= false end,
              set=function(l,v) if dodoDB then dodoDB.useResourceBarSmooth=v end; if dodo.ResourceBar and dodo.ResourceBar.UpdateSmooth then dodo.ResourceBar.UpdateSmooth() end end },
            { kind=LEM.SettingType.Slider, name="바 가로 크기", default=272, minValue=200, maxValue=300, valueStep=2,
              get=function(l) return dodoDB and dodoDB.resourceBarWidth or dodo.COMBAT_DEFAULTS.resourceBarWidth end,
              set=function(l,v) if dodoDB then dodoDB.resourceBarWidth=v end; if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end end },
            { kind=LEM.SettingType.Slider, name="바 세로 크기", default=10, minValue=6, maxValue=20, valueStep=1,
              get=function(l) return dodoDB and dodoDB.resourceBarHeight or dodo.COMBAT_DEFAULTS.resourceBarHeight end,
              set=function(l,v) if dodoDB then dodoDB.resourceBarHeight=v end; if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end end },
            { kind=LEM.SettingType.Slider, name="수치 글자 크기", default=12, minValue=8, maxValue=18, valueStep=1,
              get=function(l) return dodoDB and dodoDB.resourceBarFontSize or dodo.COMBAT_DEFAULTS.resourceBarFontSize end,
              set=function(l,v) if dodoDB then dodoDB.resourceBarFontSize=v end; if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end end },
        })

        initialize()

        if not isInitialized then
            isInitialized = true
            -- 하위 모듈 OnLoad 트리거 (믹스인 및 훅 선제 적용)
            if RB.OnLoadPower then RB.OnLoadPower() end
            if RB.OnLoadTracking then RB.OnLoadTracking() end
        end

        update_option()
        update_visibility()

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

initFrame:SetScript("OnEvent", on_event)

