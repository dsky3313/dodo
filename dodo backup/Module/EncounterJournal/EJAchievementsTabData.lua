-- ==============================
-- Inspired
-- ==============================
-- RefineUI (Modules/EncounterAchievements/Data.lua)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

dodo.EJAchievements = dodo.EJAchievements or {}
local M = dodo.EJAchievements

-- ==============================
-- 캐싱
-- ==============================
local type = type

-- ==============================
-- 텍스트 정규화
-- ==============================
local function normalize_token(text)
    if type(text) ~= "string" then return "" end
    local t = text:lower()
    t = t:gsub("|c%x%x%x%x%x%x%x%x", "")
    t = t:gsub("|r", "")
    t = t:gsub("%s+", "")
    t = t:gsub("[%p%c]+", "")
    return t
end

M.normalize_token = normalize_token

-- ==============================
-- 캐시 초기화
-- ==============================
function M.reset_caches()
    M.cancel_pending_builds()
    M.cancel_graph_build()
    M._graph = nil
    M._all_ids = nil
    M._depth_cache = {}
    M._path_cache = {}
    M._path_token_cache = {}
    M._instance_category_cache = {}
    M._row_cache = {}
end

-- 초기 상태
M._graph = nil
M._all_ids = nil
M._depth_cache = {}
M._path_cache = {}
M._path_token_cache = {}
M._instance_category_cache = {}
M._row_cache = {}
M._pending_builds = {}
M._build_queue = {}
M._ticker = nil
M._graph_task = nil
M._graph_ticker = nil
M._graph_callbacks = {}
