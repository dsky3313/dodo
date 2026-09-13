# dodo.DB 별칭 잔여 파일 목록

`dodo.DB = dodo.DB or dodoDB` 패턴은 2dodo 표준 위반.
표준: `dodoDB` 직접 참조.

Interface 모듈(05)은 수정 완료. 아래 파일들은 미처리.

---

## 미처리 파일

### 04 Combat/01 ResourceBar/Core.lua
- L227: `dodo.DB = dodo.DB or dodoDB` (ADDON_LOADED 핸들러)
- L229: `dodo.DB = dodo.DB or dodoDB or {}` (PLAYER_LOGIN 핸들러)
- **본문에서 dodo.DB 읽기 없음** — 선언만 제거하면 됨

### 09 QOL/01 CharacterFrame/06 Layout.lua
- L11: `dodo.DB = dodo.DB or dodoDB`
- **본문에서 dodo.DB 읽기 여부 미확인** — 수정 전 전체 파일 검토 필요

### 00 coming soon/Short.lua
- L12: `dodo.DB = dodo.DB or dodoDB` (선언)
- L63, L86, L99, L101, L104: `dodo.DB` 읽기/쓰기 적극 사용
- 해당 파일 전체에서 `dodo.DB` → `dodoDB` 치환 필요

### 00 coming soon/SoloMode.lua
- L32: `dodo.DB` 읽기 (`dodo.DB.enableUnitframeModule`)
- `dodo.DB` 선언 없음 — Short.lua 로드 후 `dodo.DB`가 설정된 상태에 의존
- Short.lua → SoloMode.lua 수정 시 같이 처리 필요

---

## 수정 지침

```lua
-- 제거
dodo.DB = dodo.DB or dodoDB

-- 본문 치환
dodo.DB.xxx → dodoDB.xxx
dodo.DB and dodo.DB.xxx → dodoDB and dodoDB.xxx
```
