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
local normalize_token = M.normalize_token

---@class EJAchievementRow
---@field achievementID number
---@field name string
---@field description string
---@field icon number
---@field rewardText string
---@field categoryPath string
---@field completed boolean

local DEFAULT_ICON_FILE_ID = 134400
local SCAN_PER_TICK = 10
local TICK_INTERVAL = 0.02

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local EJ_GetInstanceInfo = EJ_GetInstanceInfo
local GetAchievementInfo = GetAchievementInfo
local GetCategoryNumAchievements = GetCategoryNumAchievements
local ipairs = ipairs
local next = next
local pairs = pairs
local remove = table.remove
local tostring = tostring
local type = type

-- ==============================
-- 업적 행 비동기 빌드
-- ==============================
function M.get_cached_rows(instanceID)
    local cached = M._row_cache[instanceID]
    if type(cached) == "table" then
        return cached.rows or {}, cached.categoryID, false
    end
    return nil, nil, M._pending_builds[instanceID] ~= nil
end

local function build_row(achievementID, name, description, icon, rewardText, completed, categoryID)
    return {
        achievementID = achievementID,
        name = name or tostring(achievementID),
        description = description or "",
        icon = icon or DEFAULT_ICON_FILE_ID,
        rewardText = rewardText or "",
        completed = completed and true or false,
        categoryPath = M.get_category_path(categoryID, " | "),
    }
end

local function process_task(task)
    local categoryIDs = task.categoryIDs
    local scans = 0

    while scans < SCAN_PER_TICK do
        local categoryID = categoryIDs[task.categoryIndex]
        if not categoryID then return true end

        if task.numAchievements == nil then
            local total = GetCategoryNumAchievements(categoryID, true)
            task.numAchievements = (type(total) == "number" and total > 0) and total or 0
            task.achievementIndex = 1
        end

        if task.achievementIndex > task.numAchievements then
            task.categoryIndex = task.categoryIndex + 1
            task.achievementIndex = 1
            task.numAchievements = nil
        else
            local achievementID, name, _, completed, _, _, _, description, _, icon, rewardText, _, _, _, isStatistic =
                GetAchievementInfo(categoryID, task.achievementIndex)
            task.achievementIndex = task.achievementIndex + 1
            scans = scans + 1

            if type(achievementID) == "number" and achievementID > 0
                and isStatistic ~= true
                and not task.seen[achievementID] then
                local include = true
                if task.mode == "fallback" then
                    local nt = normalize_token(name)
                    local dt = normalize_token(description)
                    include = (nt ~= "" and nt:find(task.instanceToken, 1, true) ~= nil)
                        or (dt ~= "" and dt:find(task.instanceToken, 1, true) ~= nil)
                end
                if include then
                    task.seen[achievementID] = true
                    task.rows[#task.rows + 1] = build_row(achievementID, name, description, icon, rewardText, completed, categoryID)
                end
            end
        end
    end
    return false
end

local function finish_task(task)
    M._row_cache[task.instanceID] = { rows = task.rows, categoryID = task.categoryID }
    M._pending_builds[task.instanceID] = nil

    for i = #M._build_queue, 1, -1 do
        if M._build_queue[i] == task then
            remove(M._build_queue, i)
            break
        end
    end

    for _, cb in ipairs(task.callbacks) do
        if type(cb) == "function" then pcall(cb, task.instanceID) end
    end
end

local function tick()
    local queue = M._build_queue
    if #queue == 0 then
        M.cancel_pending_builds()
        return
    end

    local task = queue[1]
    if type(task) ~= "table" then
        remove(queue, 1)
        return
    end

    if process_task(task) then
        finish_task(task)
    end

    if #queue == 0 then
        M.cancel_pending_builds()
    end
end

function M.cancel_pending_builds()
    if M._ticker and M._ticker.Cancel then M._ticker:Cancel() end
    M._ticker = nil
    M._pending_builds = {}
    M._build_queue = {}
end

-- 인스턴스의 업적 목록을 백그라운드에서 청크 단위로 빌드 (이미 캐시됐으면 즉시 콜백)
function M.request_rows(instanceID, isRaid, on_complete)
    if type(instanceID) ~= "number" or instanceID <= 0 then
        if type(on_complete) == "function" then pcall(on_complete, instanceID) end
        return false
    end

    if type(M._row_cache[instanceID]) == "table" then
        if type(on_complete) == "function" then pcall(on_complete, instanceID) end
        return true
    end

    local pending = M._pending_builds[instanceID]
    if type(pending) == "table" then
        if type(on_complete) == "function" then pending.callbacks[#pending.callbacks + 1] = on_complete end
        return false
    end

    -- 한 번에 하나의 인스턴스만 추적: 다른 작업 진행 중이면 취소 후 새로 시작
    if next(M._pending_builds) then
        M.cancel_pending_builds()
    end

    local categoryID = M.get_resolved_category(instanceID, isRaid)
    local mode, categoryIDs, instanceToken

    if categoryID then
        mode = "category"
        categoryIDs = M.get_descendant_ids(categoryID, true)
    else
        mode = "fallback"
        local rootID = M.get_preferred_root_id()
        categoryIDs = rootID and M.get_descendant_ids(rootID, true) or M.get_all_ids()
        instanceToken = normalize_token(EJ_GetInstanceInfo(instanceID))
    end

    if mode == "fallback" and instanceToken == "" then
        M._row_cache[instanceID] = { rows = {}, categoryID = nil }
        if type(on_complete) == "function" then pcall(on_complete, instanceID) end
        return true
    end

    local task = {
        instanceID = instanceID,
        categoryID = categoryID,
        mode = mode,
        categoryIDs = type(categoryIDs) == "table" and categoryIDs or {},
        categoryIndex = 1,
        achievementIndex = 1,
        numAchievements = nil,
        instanceToken = instanceToken or "",
        seen = {},
        rows = {},
        callbacks = {},
    }
    if type(on_complete) == "function" then task.callbacks[1] = on_complete end

    if type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
        while not process_task(task) do end
        M._row_cache[task.instanceID] = { rows = task.rows, categoryID = task.categoryID }
        for _, cb in ipairs(task.callbacks) do
            if type(cb) == "function" then pcall(cb, task.instanceID) end
        end
        return true
    end

    M._pending_builds[instanceID] = task
    M._build_queue[#M._build_queue + 1] = task
    if not M._ticker then
        M._ticker = C_Timer.NewTicker(TICK_INTERVAL, tick)
    end
    return false
end
