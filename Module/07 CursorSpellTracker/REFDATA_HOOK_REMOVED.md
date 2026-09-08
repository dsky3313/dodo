# RefreshData 훅 제거 (taint 수정)

## 문제
`hook_cdm_item`에서 CDM item 프레임에 `hooksecurefunc(item, "RefreshData", ...)` 걸었음.
CDM이 전투 중 aura 갱신 시 `RefreshData` 호출 → 우리 훅이 CDM 콜체인 안에서 실행(tainted)
→ CDM의 이후 코드(`CooldownViewer.lua:344`)에서 `isActiveSpell`(secret) 비교 시 taint 에러.
전투 중 72x 반복.

## 수정
```lua
-- 이전
local function hook_cdm_item(item)
    if not item.__dodoCSTHooked then
        item.__dodoCSTHooked = true
        hooksecurefunc(item, "RefreshData", function() update_cdm_item(item) end)
    end
    update_cdm_item(item)
end

-- 이후
local function hook_cdm_item(item)
    update_cdm_item(item)
end
```

## 영향
- CDM item 프레임에 `__dodoCSTHooked` 필드 쓰기 제거
- `RefreshData` 훅 제거 → CDM 프레임 reuse 시 mapping 즉시 갱신 안 됨
- `is_cdm_aura_active`의 5초 throttle 재스캔(`rescan_cdm_items`)이 stale mapping 커버
- `OnAcquireItemFrame` 훅은 유지 (pool에서 새 프레임 획득 시 초기 mapping 등록용)

## 잔존 taint 가능성
`init_cdm_hooks`의 `hooksecurefunc(viewer, "OnAcquireItemFrame", ...)` 은 남아있음.
CDM 설정 변경 시 프레임 재할당 → 훅 실행 → 미미한 taint 가능.
전투 중 발생 빈도 낮아 현재 허용.
