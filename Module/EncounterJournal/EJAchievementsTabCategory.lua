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

---@class EJCategoryNode
---@field id number
---@field title string
---@field parentID number
---@field normalizedTitle string
---@field children number[]

local DUNGEONS_AND_RAIDS_CATEGORY_ID = 168
local SCAN_PER_TICK = 10
local TICK_INTERVAL = 0.02

-- ==============================
-- 캐싱
-- ==============================
local _G = _G
local C_Timer = C_Timer
local EJ_GetCurrentTier = EJ_GetCurrentTier
local EJ_GetInstanceInfo = EJ_GetInstanceInfo
local EJ_GetTierInfo = EJ_GetTierInfo
local GetCategoryInfo = GetCategoryInfo
local GetCategoryList = GetCategoryList
local ipairs = ipairs
local next = next
local pairs = pairs
local sort = table.sort
local tonumber = tonumber
local type = type

-- ==============================
-- 카테고리 그래프
-- ==============================
local function resolve_category_info(categoryID)
    local title, parentID = GetCategoryInfo(categoryID)
    if type(title) == "table" then
        parentID = title.parentID
        title = title.title or title.name
    end
    return title, tonumber(parentID) or -1
end

local function get_category_id_list()
    if type(GetCategoryList) ~= "function" then return {} end
    local packed = { GetCategoryList() }
    local source = (#packed == 1 and type(packed[1]) == "table") and packed[1] or packed
    local ids, seen = {}, {}
    for _, raw in pairs(source) do
        local id = tonumber(raw)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    sort(ids)
    return ids
end

-- 던전 및 공격대(168) 서브트리만 남기고 나머지 카테고리는 그래프에서 제거
local function prune_graph_to_dungeons_and_raids(graph)
    local root = graph[DUNGEONS_AND_RAIDS_CATEGORY_ID]
    if not root then return end

    local keep = {}
    local function mark(id)
        if keep[id] then return end
        keep[id] = true
        local node = graph[id]
        if not node then return end
        for _, cid in ipairs(node.children) do mark(cid) end
    end
    mark(DUNGEONS_AND_RAIDS_CATEGORY_ID)

    for id in pairs(graph) do
        if not keep[id] then graph[id] = nil end
    end
end

local function finish_graph_build(graph)
    -- 참조된 부모가 없으면 추가
    local added, safety = true, 0
    while added and safety < 32 do
        added = false
        for _, node in pairs(graph) do
            local pid = node.parentID
            if pid and pid > 0 and not graph[pid] then
                local title, pp = resolve_category_info(pid)
                graph[pid] = { id = pid, title = title or "", parentID = pp, normalizedTitle = normalize_token(title), children = {} }
                added = true
            end
        end
        safety = safety + 1
    end

    -- 자식 목록 구성
    for _, node in pairs(graph) do
        local pid = node.parentID
        if pid and pid > 0 and graph[pid] then
            local p = graph[pid]
            p.children[#p.children + 1] = node.id
        end
    end

    -- 자식 정렬
    for _, node in pairs(graph) do
        sort(node.children, function(a, b)
            local an = graph[a] and graph[a].title or ""
            local bn = graph[b] and graph[b].title or ""
            return an == bn and a < b or an < bn
        end)
    end

    prune_graph_to_dungeons_and_raids(graph)

    local all_ids = {}
    for id in pairs(graph) do all_ids[#all_ids + 1] = id end
    sort(all_ids)

    M._graph = graph
    M._all_ids = all_ids
end

function M.build_category_graph()
    local ids = get_category_id_list()
    local graph = {}

    for _, id in ipairs(ids) do
        local title, parentID = resolve_category_info(id)
        graph[id] = {
            id = id,
            title = title or "",
            parentID = parentID,
            normalizedTitle = normalize_token(title),
            children = {},
        }
    end

    finish_graph_build(graph)
    return M._graph
end

-- ==============================
-- 카테고리 그래프 비동기 빌드
-- ==============================
-- 탭 클릭 시 프리징 방지: 청크 단위로 분산 처리
local function process_graph_task(task)
    local ids = task.ids
    local scans = 0

    while scans < SCAN_PER_TICK do
        local id = ids[task.idIndex]
        if not id then return true end

        local title, parentID = resolve_category_info(id)
        task.graph[id] = {
            id = id,
            title = title or "",
            parentID = parentID,
            normalizedTitle = normalize_token(title),
            children = {},
        }
        task.idIndex = task.idIndex + 1
        scans = scans + 1
    end
    return false
end

local function complete_graph_build(task)
    finish_graph_build(task.graph)

    if M._graph_ticker and M._graph_ticker.Cancel then M._graph_ticker:Cancel() end
    M._graph_ticker = nil
    M._graph_task = nil

    local callbacks = M._graph_callbacks
    M._graph_callbacks = {}
    for _, cb in ipairs(callbacks) do
        if type(cb) == "function" then pcall(cb) end
    end
end

local function graph_tick()
    local task = M._graph_task
    if not task then
        M.cancel_graph_build()
        return
    end

    if process_graph_task(task) then
        complete_graph_build(task)
    end
end

function M.cancel_graph_build()
    if M._graph_ticker and M._graph_ticker.Cancel then M._graph_ticker:Cancel() end
    M._graph_ticker = nil
    M._graph_task = nil
    M._graph_callbacks = {}
end

-- 카테고리 그래프를 백그라운드에서 청크 단위로 빌드 (이미 빌드됐으면 즉시 콜백)
function M.request_graph(on_complete)
    if type(M._graph) == "table" and next(M._graph) then
        if type(on_complete) == "function" then pcall(on_complete) end
        return
    end

    if M._graph_task then
        if type(on_complete) == "function" then M._graph_callbacks[#M._graph_callbacks + 1] = on_complete end
        return
    end

    if type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
        M.build_category_graph()
        if type(on_complete) == "function" then pcall(on_complete) end
        return
    end

    M._graph_task = { ids = get_category_id_list(), idIndex = 1, graph = {} }
    M._graph_callbacks = type(on_complete) == "function" and { on_complete } or {}
    M._graph_ticker = C_Timer.NewTicker(TICK_INTERVAL, graph_tick)
end

function M.get_graph()
    if type(M._graph) ~= "table" or not next(M._graph) then
        local task = M._graph_task
        if task then
            -- 비동기 빌드가 진행 중인데 즉시 결과가 필요하면 남은 부분을 한 번에 마무리
            while not process_graph_task(task) do end
            complete_graph_build(task)
        else
            M.build_category_graph()
        end
    end
    return M._graph
end

function M.get_all_ids()
    if type(M._all_ids) ~= "table" or #M._all_ids == 0 then
        M.get_graph()
    end
    return M._all_ids or {}
end

-- ==============================
-- 카테고리 경로 / 깊이
-- ==============================
function M.get_category_depth(categoryID)
    local cache = M._depth_cache
    if cache[categoryID] then return cache[categoryID] end

    local graph = M.get_graph()
    local depth, cursor, safety = 0, categoryID, 0
    while cursor and safety < 64 do
        local node = graph[cursor]
        if not node then break end
        local pid = node.parentID
        if not pid or pid <= 0 then break end
        depth = depth + 1
        cursor = pid
        safety = safety + 1
    end

    cache[categoryID] = depth
    return depth
end

function M.get_category_path(categoryID, sep)
    sep = sep or " > "
    local cache = M._path_cache
    local bySep = cache[categoryID]
    if bySep and bySep[sep] then return bySep[sep] end

    local graph = M.get_graph()
    local segs, cursor, safety = {}, categoryID, 0
    while cursor and safety < 64 do
        local node = graph[cursor]
        if not node then break end
        segs[#segs + 1] = node.title or ""
        if not node.parentID or node.parentID <= 0 then break end
        cursor = node.parentID
        safety = safety + 1
    end

    -- 역순
    local n = #segs
    for i = 1, math.floor(n / 2) do
        segs[i], segs[n - i + 1] = segs[n - i + 1], segs[i]
    end

    local path = table.concat(segs, sep)
    bySep = bySep or {}
    bySep[sep] = path
    cache[categoryID] = bySep
    return path
end

function M.get_category_path_token(categoryID)
    local cache = M._path_token_cache
    if cache[categoryID] then return cache[categoryID] end
    local token = normalize_token(M.get_category_path(categoryID, " "))
    cache[categoryID] = token
    return token
end

-- ==============================
-- 인스턴스 → 카테고리 매핑
-- ==============================
function M.get_preferred_root_id()
    local graph = M.get_graph()
    if graph[DUNGEONS_AND_RAIDS_CATEGORY_ID] then return DUNGEONS_AND_RAIDS_CATEGORY_ID end

    local combo = normalize_token((_G.DUNGEONS or "") .. (_G.RAIDS or ""))
    if combo ~= "" then
        for id, node in pairs(graph) do
            if node.parentID == -1 and node.normalizedTitle == combo then return id end
        end
    end

    local dt = normalize_token(_G.DUNGEONS or "")
    local rt = normalize_token(_G.RAIDS or "")
    if dt ~= "" and rt ~= "" then
        for id, node in pairs(graph) do
            if node.parentID == -1
                and node.normalizedTitle ~= ""
                and node.normalizedTitle:find(dt, 1, true)
                and node.normalizedTitle:find(rt, 1, true) then
                return id
            end
        end
    end
    return nil
end

local function get_branch_root(rootID, isRaid)
    local graph = M.get_graph()
    local root = graph[rootID]
    if not root then return nil end
    local target = normalize_token(isRaid and (_G.RAIDS or "") or (_G.DUNGEONS or ""))
    if target == "" then return nil end
    for _, cid in ipairs(root.children) do
        local cn = graph[cid]
        if cn and cn.normalizedTitle == target then return cid end
    end
    for _, cid in ipairs(root.children) do
        local cn = graph[cid]
        if cn and cn.normalizedTitle ~= "" and cn.normalizedTitle:find(target, 1, true) then return cid end
    end
    return nil
end

function M.get_descendant_ids(rootID, include_root)
    local graph = M.get_graph()
    local root = graph[rootID]
    if not root then return {} end

    local result = {}
    local function traverse(id)
        local node = graph[id]
        if not node then return end
        result[#result + 1] = id
        for _, cid in ipairs(node.children) do traverse(cid) end
    end

    if include_root then
        traverse(rootID)
    else
        for _, cid in ipairs(root.children) do traverse(cid) end
    end
    return result
end

local function score_category(categoryID, instance_token, expansion_token)
    local graph = M.get_graph()
    local node = graph[categoryID]
    if not node then return nil end

    local ct = node.normalizedTitle
    if ct == "" or instance_token == "" then return nil end

    local score
    if ct == instance_token then
        score = 1000
    elseif ct:find(instance_token, 1, true) then
        score = 700
    elseif instance_token:find(ct, 1, true) then
        score = 650
    else
        local pt = M.get_category_path_token(categoryID)
        if pt ~= "" and pt:find(instance_token, 1, true) then score = 550 end
    end

    if not score then return nil end

    if expansion_token ~= "" then
        local pt = M.get_category_path_token(categoryID)
        if pt ~= "" and pt:find(expansion_token, 1, true) then score = score + 100 end
    end

    return score + M.get_category_depth(categoryID)
end

local function get_expansion_token()
    if type(EJ_GetCurrentTier) ~= "function" or type(EJ_GetTierInfo) ~= "function" then return "" end
    local tier = EJ_GetCurrentTier()
    return type(tier) == "number" and normalize_token(EJ_GetTierInfo(tier)) or ""
end

function M.resolve_category_for_instance(instanceID, isRaid)
    local graph = M.get_graph()
    if not next(graph) then return nil end

    local instanceName = EJ_GetInstanceInfo(instanceID)
    local instance_token = normalize_token(instanceName)
    if instance_token == "" then return nil end

    local expansion_token = get_expansion_token()
    local rootID = M.get_preferred_root_id()

    local candidates
    if rootID then
        local branchID = get_branch_root(rootID, isRaid)
        candidates = M.get_descendant_ids(branchID or rootID, true)
    else
        candidates = M.get_all_ids()
    end

    local best_id, best_score
    for _, cid in ipairs(candidates) do
        local s = score_category(cid, instance_token, expansion_token)
        if s and (not best_score or s > best_score) then
            best_id = cid
            best_score = s
        end
    end
    if best_id then return best_id end

    -- fallback: 전체 정확 매칭
    for _, cid in ipairs(M.get_all_ids()) do
        local node = graph[cid]
        if node and node.normalizedTitle == instance_token then return cid end
    end

    -- fallback: path 포함 매칭
    local best_path_id, best_depth
    for _, cid in ipairs(M.get_all_ids()) do
        local pt = M.get_category_path_token(cid)
        if pt ~= "" and pt:find(instance_token, 1, true) then
            local d = M.get_category_depth(cid)
            if not best_depth or d > best_depth then
                best_path_id = cid
                best_depth = d
            end
        end
    end
    return best_path_id
end

function M.get_resolved_category(instanceID, isRaid)
    if type(instanceID) ~= "number" or instanceID <= 0 then return nil end
    local cached = M._instance_category_cache[instanceID]
    if cached ~= nil then return cached or nil end

    local id = M.resolve_category_for_instance(instanceID, isRaid)
    if id then
        M._instance_category_cache[instanceID] = id
    elseif next(M.get_graph()) then
        M._instance_category_cache[instanceID] = false
    end
    return id
end
