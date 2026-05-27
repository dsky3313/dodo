-- ==============================
-- Rules
-- ==============================
-- 1. 네임스페이스 통일: local addonName, dodo = ... 를 사용하여 코어와 DB(dodo.DB) 공유.
-- 2. 생명주기 관리: 핵심 로직 작동 및 LibEditMode 등록은 반드시 OnEnable() 내부에서 수행.
-- 3. 스코프 최적화 (Lexical Scoping): 라이브러리 및 캐싱 변수는 파일 상단에 한 번만 선언하여 모든 함수가 공유.
-- 4. 네이밍 및 표기 규칙:
--    - 로컬 헬퍼 및 메인 동작 함수: snake_case (예: update_feature(), create_ui())
--    - 이벤트 핸들러 및 콜백: On + EventName (예: OnUnitTooltip(), OnClick())
--    - 내부 모듈 상태 제어: snake_case (예: update_module_state())
--    - 외부 API 노출 (Option.lua 연동): PascalCase (예: dodo.TemplateApplyFeature)
--    - 모듈 전체 활성/비활성 마스터 DB 키: enable[모듈명]Module (예: enableMinimapModule)
--    - 모듈 세부 옵션/가벼운 기능 DB 키: use[기능명] (예: useMinimapSquare, useQuickBobber)
--    - 일반 로컬 변수 및 DB 설정 키: camelCase (예: isEnabled, positionX)

-- ==============================
-- Inspired
-- ==============================
-- Addon Name (https://curseforge.com/...)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Template", module) -- 모듈 이름에 맞게 수정

local LibIcon = dodo.LibIcon -- 라이브러리 사용하면 확인하기 쉽게 한줄 띄우기.
local LibEditMode = LibStub and LibStub("LibEditMode", true)

-- ==============================
-- 프레임 및 이벤트 핸들러 정의 (필요 시 주석 해제하여 사용)
-- ==============================
-- local main_frame = CreateFrame("Frame", "dodoTemplateFrame", UIParent)
-- local eventFrame = CreateFrame("Frame")

-- ==============================
-- 캐싱
-- ==============================
-- abc 가나다 순으로 정렬
local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs

-- ==============================
-- 기능 1
-- ==============================
-- 디스플레이, 동작, 이벤트 순으로 작성하는 것을 선호함. 안되면 어쩔 수 없고.
local function update_feature()
    -- 모든 설정값은 dodo.DB 네임스페이스를 참조하며, 체크박스 기본값은 false로 정의합니다.
    local isEnabled = (dodo.DB and dodo.DB.useTemplateFeature == true)

    if isEnabled then
        -- 활성화 시 기능 동작 로직
    else
        -- 비활성화/초기 상태 복구 로직
    end
end

-- ==============================
-- 기능 2
-- ==============================

-- ==============================
-- 모듈 On/Off 활성화 상태 제어 (편집 모드 모듈 설정 창과 연동 시 사용)
-- ==============================
local function update_module_state()
    local enabled = false
    if dodo.DB and dodo.DB.enableTemplateModule ~= nil then
        enabled = dodo.DB.enableTemplateModule
    end

    if not enabled then
        -- 비활성화 시: 프레임 숨김, 이벤트 감지 완전히 해제(CPU 소모 방지), 편집 모드 테두리 상자 숨김
        main_frame:Hide()
        main_frame:UnregisterAllEvents()
        
        if LibEditMode and LibEditMode.frameSelections and LibEditMode.frameSelections[main_frame] then
            LibEditMode.frameSelections[main_frame]:Hide()
        end
    else
        -- 활성화 시: 프레임 노출, 이벤트 재등록, 편집 모드 중일 때 노란 격자 테두리 표시
        main_frame:Show()
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        update_feature()
        
        if LibEditMode and LibEditMode:IsInEditMode() and LibEditMode.frameSelections and LibEditMode.frameSelections[main_frame] then
            LibEditMode.frameSelections[main_frame]:ShowHighlighted()
        end
    end
end

dodo.UpdateTemplateModuleState = update_module_state -- 주석 해제하여 설정 패널과 연동
dodo.TemplateApplyFeature = update_feature -- Option.lua 연동용 외부 노출

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
    -- UI 프레임 생성 로직 (예: main_frame = CreateFrame("Frame", ...))
end

local function initialize()
    -- 1. DB 설정 초기값 세팅 등
    if dodo.DB and dodo.DB.useTemplateFeature == nil then
        dodo.DB.useTemplateFeature = false
    end
    
    -- 2. UI 생성 호출 (UI가 없는 모듈은 이 라인을 생략하거나 create_ui 함수 자체를 생략)
    create_ui()
end

-- ==============================
-- 모듈 등록 및 생명주기
-- ==============================
function module:OnEnable()
    -- eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initialize() -- 1. 모듈 초기화 (DB 초기값 세팅 및 create_ui 호출)
    update_feature() -- 2. 기능 적용 및 데이터 갱신
    update_module_state() -- 3. On/Off 상태 및 이벤트 연동 갱신 (사용 시 주석 해제)

    if LibEditMode then
        -- 0. Editmode.lua에 모듈 활성화 체크박스 등록 먼저하기.
        -- 1. 편집 모드 프레임 등록
        LibEditMode:AddFrame(
            yourFrame, -- 대상 프레임 (반드시 전역 이름이나 frame.editModeName이 있어야 합니다)
            function(frame, layoutName, point, x, y)
                dodo.DB.yourFeatureX = x
                dodo.DB.yourFeatureY = y
                dodo.DB.yourFeaturePoint = point
                update_feature()
            end,
            {
                point = "CENTER", -- 기본 위치
                x = 0,
                y = 0,
            },
            "화면에 표시될 프레임 이름"
        )
    
        -- 2. 프레임 전용 설정창 등록 (클릭 시 나타나는 블리자드 순정 옵션 팝업)
        LibEditMode:AddFrameSettings(yourFrame, {
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "체크박스 옵션명",
                desc = "옵션 툴팁 설명입니다.",
                default = false,
                get = function() return dodo.DB.yourFeatureOption or false end,
                set = function(_, newValue)
                    dodo.DB.yourFeatureOption = newValue
                    update_feature()
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "슬라이더 옵션명",
                desc = "슬라이더 툴팁 설명입니다.",
                default = 50,
                minValue = 10,
                maxValue = 100,
                valueStep = 5,
                get = function() return dodo.DB.yourFeatureSize or 50 end,
                set = function(_, newValue)
                    dodo.DB.yourFeatureSize = newValue
                    update_feature()
                end,
            },
        })
    end
end

-- ==============================
-- 설정
-- ==============================
-- 만약 LibEditMode로 설정을 추가했다면 사용하지 말것.
function module:CreateOptions()
    if not dodo.mainCategory then return end
    if self.optionsCreated then return end

    local Settings = Settings
    local SettingsPanel = SettingsPanel

    -- 하위 카테고리 등록 (필요에 따라 subCategoryGeneral, subCategoryInterface 등 선택)
    local subCategory = Settings.RegisterVerticalLayoutSubcategory(dodo.mainCategory, "템플릿")
    local layout = SettingsPanel:GetLayout(subCategory)

    -- 옵션 섹션 헤더 생성
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("옵션 그룹"))
    
    -- 체크박스 기본값은 false, 슬라이더 기본값은 1로 작성합니다.
    dodo.UI.Checkbox(subCategory, "useTemplateFeature", "체크박스 이름", "옵션 설명입니다.", false, update_feature)
    dodo.UI.Slider(subCategory, "templateSlider", "슬라이더 이름", "슬라이더 설명입니다.", 1, 10, 1, 1, "Integer", update_feature)

    self.optionsCreated = true
end

-- 옵션창 열릴 때 카테고리가 안전하게 자동 등록되도록 훅을 추가합니다.
if SettingsPanel then
    SettingsPanel:HookScript("OnShow", function()
        module:CreateOptions()
    end)
end