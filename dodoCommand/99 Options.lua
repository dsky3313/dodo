---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 명령어 테이블 (설정창 목록 표시용)
-- ==============================
local command_table = {
    { label = "편집 모드",             desc = "/ed, /ㄷㅇ" },
    { label = "재사용대기시간 관리자", desc = "/cd, /ㅊㅇ" },
    { label = "리로드",                desc = "/re, /ㄱㄷ" },
    { label = "전투준비",              desc = "/11" },
    { label = "파티 탈퇴",             desc = "/vx, /ㅍㅌ" },
    { label = "매크로",                desc = "/ㅡ" },
    { label = "플레이터 / 플레이티",   desc = "/pp, /ㅔㅔ" },
    { label = "MDT",                   desc = "/mdt, /ㅡㅇㅅ" },
    { label = "위크오라",              desc = "/wa, /aw, /ㅈㅁ, /ㅁㅈ" },
    { label = "프레임스택",            desc = "/fs, /ㄹㄴ" },
    { label = "dodo 설정창",           desc = "/dd, /ㅇㅇ" },
    { label = "dodo DB 초기화",        desc = "/ddr" },
    -- { label = "프로파일러",            desc = "/pf, /ㅔㄹ" }, -- 비활성
}

local LINE_H = 20

-- ==============================
-- 목록 프레임
-- ==============================
dodoCommandListMixin = {}

function dodoCommandListMixin:OnLoad()
    for i, info in ipairs(command_table) do
        local y = -(i - 1) * LINE_H - 4
        local label = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", self, "TOPLEFT", 37, y)
        label:SetText(info.label)

        local desc = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        desc:SetPoint("TOPLEFT", self, "TOPLEFT", 220, y)
        desc:SetText(info.desc)
    end
end

dodoCommandListMixin.GetExtent = function()
    return #command_table * LINE_H + 8
end

-- ==============================
-- 설정 등록 — 명령어
-- ==============================
dodo.RegisterOption("명령어", function(category)
    dodo.UI:SettingsAddPreview(category, dodoCommandListMixin)
end, 9800)
