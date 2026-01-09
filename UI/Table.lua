------------------------------
-- 테이블
------------------------------
local White = { r = 1, g = 1, b = 1 }
local Gold = { r = 1, g = 0.82, b = 0 }
local Gray = { r = 0.5, g = 0.5, b = 0.5 }
local GrayLight = { r = 0.6, g = 0.6, b = 0.6 }
local Red = { r = 1, g = 0.1, b = 0.1 }
local GoldDark = { r = 1, g = 0.78, b = 0 }

fontTable = {
    { name = "GameFontHighlight", color = White , height="12" }, -- 지도 퀘스트목록(퀘스트 마우스오버) / GameFontNormal 하이라이트
    { name = "GameFontHighlight_NoShadow", color = White },
    { name = "GameFontNormal", color = Gold, height="12" }, -- 지도 퀘스트목록(퀘스트)
    { name = "GameFontNormalSmall", color = Gold, height="10" },
    { name = "GameFontNormalSmallOutline", color = Gold, height="10" },

    { name = "GameFontNormalMed2Outline", color = Gold },
    { name = "GameFontNormalShadowOutline22", color = Gold },
    { name = "GameFontHighlightShadowOutline22", color = White },
    { name = "QuestFontNormalLarge", color = Gold },
    { name = "QuestFontNormalHuge", color = Gold },
    { name = "QuestFontHighlightHuge", color = White },
    { name = "GameFontWhiteSmall", color = White },
    { name = "GameFontHighlightMed2Outline", color = White },
    { name = "GameFontNormalMed3Outline", color = Gold },
    { name = "GameFontDisableMed3", color = Gray },
    { name = "GameFontDisableMed2", color = Gray },
    { name = "GameFontHighlightHuge2", color = White },
    { name = "GameFontNormalHuge2Outline", color = Gold },
    { name = "GameFontHighlightShadowHuge2", color = White },
    { name = "GameFontNormalOutline22", color = GoldDark },
    { name = "GameFontHighlightOutline22", color = White },
    { name = "GameFontDisableOutline22", color = Gray },
    { name = "GameFontNormalHugeOutline", color = Gold },
    { name = "GameFontHighlightHugeOutline", color = White },
    { name = "GameFont72Normal", color = Gold },
    { name = "GameFont72Highlight", color = White },
    { name = "GameFont72NormalShadow", color = Gold },
    { name = "GameFont72HighlightShadow", color = White },
    { name = "NumberFontNormalLarge", color = White },
    { name = "NumberFontNormalLargeRight", color = White },
    { name = "NumberFontNormalLargeRightRed", color = Red },
    { name = "NumberFontNormalLargeRightYellow", color = Gold },
    { name = "NumberFontNormalLargeRightGray", color = GrayLight },
}

uiTable = {
    { name = "DefaultPanelTemplate"}, -- 기본창
    { name = "DefaultPanelBaseTemplate"}, -- 기본창 배경 x
    { name = "SettingsFrameTemplate"}, -- 설정창
    { name = "ButtonFrameTemplate"}, -- 기본창 + 포트레잇 +
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