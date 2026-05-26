-- ==============================
-- Inspired
-- ==============================
-- 

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

local ModuleMixin = {}
function ModuleMixin:Print(...) print("|cffaaffaadodo [" .. self.Name .. "]:|r", ...) end

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local geterrorhandler = geterrorhandler
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert
local xpcall = xpcall

-- ==============================
-- 기능 1: 모듈 등록 및 구동 제어
-- ==============================
function dodo:RegisterModule(name, module)
    module = module or {}
    for k, v in pairs(ModuleMixin) do module[k] = v end
    module.Name = name
    dodo.Modules[name] = module
    table_insert(dodo.ModuleRegistry, module)
    return module
end

local function safe_on_enable(module)
    module:OnEnable()
end

function dodo:EnableModules()
    for _, module in ipairs(dodo.ModuleRegistry) do
        if module.OnEnable then
            local ok, err = xpcall(safe_on_enable, geterrorhandler(), module)
            if not ok then
                print("|cffff0000dodo 모듈 실행 실패 (" .. module.Name .. "):|r", err)
            end
        end
    end
end

-- Hook into Engine
local originalInit = dodo.OnInitialize
function dodo:OnInitialize()
    if originalInit then originalInit(self) end
end

local originalEnable = dodo.OnEnable
function dodo:OnEnable()
    if originalEnable then originalEnable(self) end
    self:EnableModules()
end

-- ==============================
-- 기능 2: 전투 중 비전투 QoL 모듈 강제 휴면 제어
-- ==============================
local function safe_combat_start(module)
    module:OnCombatStart()
end

local function safe_combat_end(module)
    module:OnCombatEnd()
end

local function on_combat_event(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, module in ipairs(dodo.ModuleRegistry) do
            if module.NonCombat and module.OnCombatStart then
                xpcall(safe_combat_start, geterrorhandler(), module)
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        for _, module in ipairs(dodo.ModuleRegistry) do
            if module.NonCombat and module.OnCombatEnd then
                xpcall(safe_combat_end, geterrorhandler(), module)
            end
        end
    end
end

local combatWatcher = CreateFrame("Frame")
combatWatcher:SetScript("OnEvent", on_combat_event)
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
