-- ==============================
-- dodo Core Utilities (Zero-Garbage Optimized)
-- ==============================
-- RefineUI 기반 코어 유틸리티의 가비지 컬렉션(GC) 및 프레임 스파이크 방지 최적화 버전

local addonName, dodo = ...

local C_Timer = C_Timer
local hooksecurefunc = hooksecurefunc
local tostring = tostring
local GetTime = GetTime
local type = type

-- ==============================
-- 1. Debounce (디바운스 - 무가비 방식)
-- ==============================
-- C_Timer.NewTimer 객체를 반복적으로 Cancel하고 생성하면 대량의 메모리 가비지(GC 스파이크)가 튑니다.
-- NewTimer 대신 GetTime 스탬프 비교와 최소한의 C_Timer.After 틱 구조를 활용하여 가비지를 원천 제거합니다.
local debounces = {}
function dodo.Debounce(key, func, delay)
    local delayTime = delay or 0.1
    local targetTime = GetTime() + delayTime
    debounces[key] = targetTime

    if not debounces[key .. "_running"] then
        debounces[key .. "_running"] = true
        
        local function run()
            local now = GetTime()
            local target = debounces[key]
            if not target then
                debounces[key .. "_running"] = nil
                return
            end

            if now >= target - 0.005 then
                debounces[key .. "_running"] = nil
                debounces[key] = nil
                func()
            else
                C_Timer.After(target - now, run)
            end
        end
        
        C_Timer.After(delayTime, run)
    end
end

-- ==============================
-- 2. Throttle (쓰로틀 - Zero-Timer 방식)
-- ==============================
-- 타이머 자체를 전혀 생성하지 않는 완벽한 무가비 쓰로틀입니다.
-- 단순히 최근 실행 완료 시간 스탬프를 저장하여 지정 간격 내 추가 실행 요구를 즉각 거부합니다.
local throttles = {}
function dodo.Throttle(key, func, interval)
    local now = GetTime()
    local last = throttles[key] or 0
    if now - last >= (interval or 0.1) then
        throttles[key] = now
        func()
    end
end

-- ==============================
-- 3. HookOnce (단일 secure 훅)
-- ==============================
local hooked = {}
function dodo.HookOnce(tbl, funcName, hookFunc)
    if type(tbl) == "string" and not hookFunc then
        hookFunc = funcName
        funcName = tbl
        tbl = nil
    end

    local key = (tbl and tostring(tbl) or "_G") .. "_" .. funcName
    if hooked[key] then return end
    hooked[key] = true

    if tbl and tbl[funcName] then
        hooksecurefunc(tbl, funcName, hookFunc)
    else
        hooksecurefunc(funcName, hookFunc)
    end
end
