-- ==============================
-- WorldMap Custom Icon Module (Pure Lua)
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Config = {
    mapID = 2393, -- 실버문
    x = 0.4816, -- 경매장 X 비율
    y = 0.7546, -- 경매장 Y 비율
    size = 24, -- 아이콘 픽셀 크기
    atlas = "Auctioneer", -- 경매장 아틀라스
    name = "실버문 경매장",
}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local WorldMapFrame = WorldMapFrame

-- ==============================
-- 상태 관리
-- ==============================
local init_frame = CreateFrame("Frame")
local pin = nil

-- ==============================
-- 기능 1: 핀 크기 스케일 보정 (OnUpdate)
-- ==============================
-- 캔버스 줌 상태와 무관하게 핀의 픽셀 크기(Config.size)를 화면상 일정하게 보정
local function pin_on_update(self)
    local canvas = WorldMapFrame:GetCanvas()
    if canvas then
        local canvasScale = canvas:GetScale()
        if canvasScale > 0 then
            self:SetScale(1 / canvasScale)
        end
    end
end

-- ==============================
-- 기능 2: 핀 마우스 호버 툴팁
-- ==============================
local function pin_on_enter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Config.name)
    GameTooltip:Show()
end

local function pin_on_leave()
    GameTooltip:Hide()
end

-- ==============================
-- 기능 3: 핀 위치 및 표시 업데이트
-- ==============================
local function update_pin_position()
    local is_enabled = (dodoDB and dodoDB.enableWorldMapIcon ~= false)
    if not is_enabled then
        if pin then pin:Hide() end
        return
    end

    if not pin then return end

    local map_id = WorldMapFrame:GetMapID()
    if map_id == Config.mapID and WorldMapFrame:IsVisible() then
        local canvas = WorldMapFrame:GetCanvas()
        local cw, ch = canvas:GetSize()
        if cw > 0 and ch > 0 then
            pin:ClearAllPoints()
            -- 캔버스 원점(TOPLEFT) 기준으로 비율 오프셋 적용해 CENTER 정렬
            pin:SetPoint("CENTER", canvas, "TOPLEFT", Config.x * cw, -Config.y * ch)
            pin:Show()
        else
            -- 캔버스 렌더링 대기 후 재시도
            C_Timer.After(0.05, update_pin_position)
        end
    else
        pin:Hide()
    end
end

-- ==============================
-- 기능 4: UI 프레임 생성
-- ==============================
local function create_pin()
    if pin then return end

    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end

    pin = CreateFrame("Button", "dodoWorldMapAuctioneerPin", canvas)
    pin:SetSize(Config.size, Config.size)
    pin:SetFrameStrata("HIGH")
    pin:SetFrameLevel(5000)

    pin.texture = pin:CreateTexture(nil, "ARTWORK")
    pin.texture:SetAllPoints(pin)
    pin.texture:SetAtlas(Config.atlas, true)

    -- 스크립트 연결 (가비지 프리)
    pin:SetScript("OnUpdate", pin_on_update)
    pin:SetScript("OnEnter", pin_on_enter)
    pin:SetScript("OnLeave", pin_on_leave)

    pin:Hide()
end

local function update_visual()
    local is_enabled = (dodoDB and dodoDB.enableWorldMapIcon ~= false)
    if is_enabled then
        create_pin()
        update_pin_position()
    else
        if pin then pin:Hide() end
    end
end

local function initialize()
    if dodoDB and dodoDB.enableWorldMapIcon == nil then
        dodoDB.enableWorldMapIcon = true
    end
    update_visual()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        initialize()
        
        -- WorldMapFrame 이벤트 훅 (순정 프레임 연동)
        WorldMapFrame:HookScript("OnShow", update_pin_position)
        hooksecurefunc(WorldMapFrame, "OnMapChanged", update_pin_position)

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("지도", {
        {
            name = "월드맵 커스텀 아이콘 활성화",
            get = function() return dodoDB and dodoDB.enableWorldMapIcon ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableWorldMapIcon = checked end
                update_visual()
            end
        }
    })
end
