------------------------------
-- 테이블
------------------------------
colorTable = {
    { name = "white", color = { r = 1, g = 1, b = 1 } },
    { name = "gold", color = { r = 1, g = 1, b = 1 } },
    { name = "gray", color = { r = 1, g = 1, b = 1 } },
    { name = "graylight", color = { r = 1, g = 1, b = 1 } },
    { name = "red", color = { r = 1, g = 1, b = 1 } },
    { name = "golddark", color = { r = 1, g = 1, b = 1 } },
    { name = "zoneSanctuary", color = { r = 0.41, g = 0.8, b = 0.94 } }, -- cyan
    { name = "zoneFriendly", color = { r = 0.1, g = 1.0, b = 0.1 } }, -- green ?
    { name = "zoneContested", color = { r = 1.0, g = 0.7, b = 0 } }, -- orange ?
    { name = "zoneCombat", color = { r = 1.0, g = 0.1, b = 0.1 } }, -- red, = Arena, Hostile
    { name = "", color = { r = , g = , b =  } },
}

fontTable = {
    { name = "GameFontHighlight", color = "white" , height="12" }, -- 지도 퀘스트목록(퀘스트 마우스오버) / GameFontNormal 하이라이트

}

local fontTable = {
    { name = "GameFontNormalSmall" },        -- 10pt, 황금색, 표준
    { name = "GameFontNormal" },             -- 12pt
    { name = "GameFontNormalMed1" },         -- 13pt
    { name = "GameFontNormalMed2" },         -- 14pt
    { name = "GameFontNormalMed3" },         -- 15pt
    { name = "GameFontNormalLarge" },        -- 16pt
    { name = "GameFontNormalHuge" },         -- 20pt
    { name = "GameFontNormalSmallOutline" },     -- 10pt, 아웃라인
    { name = "GameFontNormalOutline" },          -- 12pt
    { name = "GameFontNormalLargeOutline" },     -- 16pt
    { name = "GameFontNormalHugeOutline" },      -- 20pt, zoneText

    { name = "GameFontHighlightSmall" },     -- 10pt, 흰색, 강조
    { name = "GameFontHighlight" },          -- 12pt
    { name = "GameFontHighlightMedium" },    -- 14pt
    { name = "GameFontHighlightLarge" },     -- 16pt
    { name = "GameFontHighlightHuge" },      -- 20pt
    { name = "GameFontHighlightSmallOutline" },  -- 10pt, 아웃라인
    { name = "GameFontHighlightOutline" },       -- 12pt
    { name = "GameFontHighlightMed2Outline" }, -- 14pt
    { name = "GameFontHighlightLargeOutline" },  -- 16pt

    -- [ SystemFont 계열: 시스템 기본 ]
    { name = "SystemFont_Tiny" },            -- 9pt, 시스템 기본, 매우 작음
    { name = "SystemFont_Small" },           -- 10pt, 시스템 기본
    { name = "SystemFont_Med1" },            -- 12pt, 시스템 기본
    { name = "SystemFont_Med3" },            -- 14pt, 시스템 기본
    { name = "SystemFont_Large" },           -- 16pt, 시스템 기본
    { name = "SystemFont_Huge1" },           -- 20pt, 시스템 기본

    -- [ Shadow 계열: 그림자 포함 ]
    { name = "SystemFont_Shadow_Small" },    -- 10pt, 그림자 보정
    { name = "SystemFont_Shadow_Med1" },     -- 12pt, 그림자 보정
    { name = "SystemFont_Shadow_Med3" },     -- 14pt, 그림자 보정
    { name = "SystemFont_Shadow_Large" },    -- 16pt, 그림자 보정
    { name = "SystemFont_Shadow_Huge1" },    -- 20pt, 그림자 보정
}

uiTable = {
    { name = "ActionButtonTemplate"}, -- 행동단축바 테두리
    { name = "AutoCompleteEditBoxTemplate"}, -- 텍스트입력 자동완성
    { name = "BackdropTemplate"}, -- 프레임 생성 (배경, 테두리)
    { name = "ButtonFrameTemplate"}, -- 닫기버튼 있는 기본창 + 포트레잇
    { name = "CharacterFrameTabButtonTemplate"}, -- 캐릭터창 하단 탭
    { name = "ChatConfigCheckButtonTemplate"}, -- 채팅창 체크박스?
    { name = "CooldownFrameTemplate"}, -- 쿨타임 애니메이션
    { name = "DefaultPanelTemplate"}, -- 기본창 (닫기 X)
    { name = "DefaultPanelBaseTemplate"}, -- 기본창 (배경,닫기 x)

    { name = "DialogBorderDarkTemplate"}, -- 아이템파괴창
    { name = "DialogBorderOpaqueTemplate"}, -- 불투명 배경


    
    { name = "FauxScrollFrameTemplate"}, -- 가짜 스크롤? > HybridScrollBarTemplate
    { name = "GameMenuButtonTemplate"}, -- ESC 메뉴
    { name = "GameTooltipTemplate"}, -- 툴팁
    { name = "HybridScrollBarTemplate"}, -- 가짜 스크롤?
    { name = "HybridScrollFrameTemplate"}, -- 행동단축바 테두리
    { name = "InputBoxTemplate"}, -- 텍스트 입력창
    { name = "InsetFrameTemplate"}, -- 창 안의 또 다른 영역(내용물 표시 구역)
    { name = "InterfaceOptionsCheckButtonTemplate"}, -- 기존 설정창(Interface Options)에서 표준적으로 사용되던 체크박스 템플릿
    { name = "OptionsBaseCheckButtonTemplate"}, -- 원형에 가까운(Base) 체크박스 기능만을 담고 있는 템플릿
    { name = "OptionsListButtonTemplate"}, -- 설정창 왼쪽 사이드바
    { name = "OptionsSliderTemplate"},
    { name = "SearchBoxTemplate"}, -- 돋보기 아이콘이 포함된 검색창
    { name = "SecureActionButtonTemplate"}, -- 전투 중 사용 가능한 버튼
    { name = "SecureHandlerClickTemplate"}, -- 전투 중에도 복잡한 로직을 안전하게 처리할 수 있는 리모컨
    { name = "SecureHandlerStateTemplate"}, -- 가장 강력하면서도 가장 복잡한 보안 템플릿
    { name = "SecureUnitButtonTemplate"}, -- 특정 유닛(대상, 파티원, 자신 등)을 클릭하거나 타겟팅하는 동작
    { name = "UICheckButtonTemplate"}, -- 체크박스 템플릿
    { name = "UIDropDownMenuTemplate"}, -- 드롭다운 메뉴
    { name = "UIMenuButtonStretchTemplate"}, -- 버튼의 크기에 맞춰 배경 그래픽이 유연하게 늘어나는
    { name = "UIPanelButtonTemplate"}, -- 클래식한 버튼
    { name = "UIPanelDialogTemplate"}, -- 클래식한 대화 상자 템플릿
    { name = "UIPanelScrollBarTemplate"}, -- 가장 표준적인 세로 스크롤 바
    { name = "UIPanelScrollDownButtonTemplate"}, -- 맨 아래에 위치한 '아래로 가기' 화살표 버튼
    { name = "UIPanelScrollFrameTemplate"}, -- 내용물이 프레임 크기보다 클 때, 위아래로 움직여서 볼 수 있게 해주는 주머니
    { name = "UIRaidButtonTemplate"}, -- 공격대(Raid) 관리창이나 공격대원 목록
    { name = "WowScrollBox"}, -- 가장 현대적이고 강력한 스크롤 라이브러리
    { name = "WowScrollBoxList"}, -- 리스트 형태(목록)
    { name = ""}, -- 
    -- https://github.com/Ketho/BlizzardInterfaceResources/blob/mainline/Resources/Templates.lua
}

local Bobber = CreateFrame("Button", "BobberButton", ProfessionsBookFrame, "wowscrollbox")

CreateFrame("Frame", "PartyClassFrame", UIParent, "DefaultPanelBaseTemplate")
SetFrameStrata = {
    "PARENT",
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",
}

------------------------------
-- func
------------------------------
------------------------------
-- 이벤트
------------------------------
------------------------------
-- 폰트
------------------------------