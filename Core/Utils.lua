-- ==============================
-- Inspired
-- ==============================
-- RefineUI (https://github.com/Enkiduke/RefineUI)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local tostring = tostring
local type = type

-- ==============================
-- 기능 1: Debounce (디바운스 - 제로가비지 방식)
-- ==============================
-- C_Timer.NewTimer 객체를 반복적으로 Cancel하고 생성하면 대량의 메모리 가비지(GC 스파이크)가 튑니다.
-- 문자열 결합 연산(..) 조차 배제하여 가비지를 원천 제거한 중첩 테이블 기반 제로가비지 디바운스입니다.
local debounces = {}
function dodo.Debounce(key, func, delay)
    local delayTime = delay or 0.1
    local targetTime = GetTime() + delayTime
    
    local state = debounces[key]
    if not state then
        state = { target = 0, running = false }
        debounces[key] = state
    end
    state.target = targetTime

    if not state.running then
        state.running = true
        
        local function run()
            local now = GetTime()
            local target = state.target
            if not target then
                state.running = false
                return
            end

            if now >= target - 0.005 then
                state.running = false
                state.target = nil
                func()
            else
                C_Timer.After(target - now, run)
            end
        end
        
        C_Timer.After(delayTime, run)
    end
end

-- ==============================
-- 기능 2: Throttle (쓰로틀 - Zero-Timer 방식)
-- ==============================
-- 타이머 자체를 전혀 생성하지 않는 완벽한 제로가비지 쓰로틀입니다.
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
-- 기능 3: HookOnce (단일 secure 훅)
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

-- ==============================
-- 기능 4: Profile (정밀 성능 측정)
-- ==============================
-- 특정 함수 실행 시간 측정. 2ms(0.002초) 초과 시 경고 출력.
-- 가비지 생성을 최소화하기 위해 가변 리턴 완벽 지원.
local GetTimePreciseSec = GetTimePreciseSec
function dodo.Profile(name, func, ...)
    local start = GetTimePreciseSec()
    local function pass(success, ...)
        local elapsed = GetTimePreciseSec() - start
        if elapsed > 0.001 then
            print(string.format("|cffff3333[DodoProfile]|r %s 느림: %.4f초", name, elapsed))
        end
        if not success then
            error(...)
        end
        return ...
    end
    return pass(pcall(func, ...))
end
