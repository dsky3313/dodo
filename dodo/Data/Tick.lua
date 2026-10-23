-- ==============================
-- Inspired
-- ==============================
-- EllesmereUI_Ticker.lua (Tick.NewAnimTicker)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- 기능 1: AnimationGroup 루프 티커
-- ==============================
-- 고정 주기 반복 갱신용. 타이밍은 C 엔진, 틱당 Lua 콜백 1회, 재사용으로 할당 0.
-- 생성만 담당. 시작/정지는 사용 모듈에서:
--   if not ticker:IsPlaying() then ticker:Play() end / ticker:Stop()
-- 사용 모듈의 파일 스코프에서 호출할 것 (CPU 집계가 호출 애드온으로 잡힘).
-- fn: 정적 local 함수 (OnLoop 인자 self, loopState 전달됨)
-- interval: 주기(초). 기본 1/30 (30Hz)
-- 반환: ticker(AnimationGroup), anim(Animation — 정지 상태에서 SetDuration으로 주기 변경)
function dodo.LoopTicker(fn, interval)
    -- 전용 프레임 (부모 없음): 애니메이션은 부모 숨김 시 정지하므로
    local ticker = CreateFrame("Frame"):CreateAnimationGroup()
    ticker:SetLooping("REPEAT")
    local anim = ticker:CreateAnimation("Animation")
    anim:SetDuration(interval or 1 / 30)
    ticker:SetScript("OnLoop", fn)
    return ticker, anim
end
