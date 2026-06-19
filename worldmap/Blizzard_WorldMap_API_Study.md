# Blizzard WorldMap (MapCanvas) API 및 작동 원리 분석

World of Warcraft Retail의 월드맵(`WorldMapFrame`) 시스템을 모방하거나 활용하여 지도 상에 커스텀 아이콘(핀)을 정석적으로 추가하기 위한 가이드 문서입니다.

---

## 1. MapCanvas 핵심 아키텍처

Blizzard의 지도 프레임워크는 **MapCanvas** 구조를 채택하고 있으며, 아래의 삼위일체 구조로 작동합니다.

1. **MapCanvas (`WorldMapFrame`)**
   * 지도의 타일 이미지, 스크롤 영역, 줌 및 드래그 등을 처리하는 부모 도화지 프레임입니다.
   * `MapCanvasMixin`을 상속받아 구현되어 있습니다.

2. **DataProvider (`MapCanvasDataProviderMixin`)**
   * 지도가 열리거나(`OnShow`), 맵 지역이 변경되거나(`OnMapChanged`), 특정 이벤트가 올 때 필요한 데이터를 가공하여 지도 위에 핀을 꽂거나 지우는 **중개자(컨트롤러)**입니다.

3. **MapPin (`MapCanvasPinMixin`)**
   * 지도 위에 실질적으로 렌더링되는 개별 아이콘 프레임(텍스처, 텍스트, 클릭 영역 포함)입니다.
   * 지도의 배율(Zoom) 및 드래그(Pan) 상태에 맞게 크기와 오프셋이 내부 엔진에 의해 관리됩니다.

---

## 2. SharedMapDataProviders 목록 및 역할

Blizzard는 지도에 표시되는 공통 요소들을 모듈화하여 관리합니다. 대표적인 프로바이더들은 다음과 같습니다.

| 프로바이더명 | 클래스명 | 기능 |
| :--- | :--- | :--- |
| `DeathMapDataProvider` | `DeathMapDataProviderMixin` | 플레이어 사망 시 부활할 시체(`CorpsePinTemplate`) 위치 및 무덤 위치 표시 |
| `GroupMembersDataProvider` | `GroupMembersDataProviderMixin` | 파티원 및 공대원들의 실시간 맵 위치 아이콘 렌더링 |
| `FlightPointDataProvider` | `FlightPointDataProviderMixin` | 활성화된 비행 경로(그리핀/와이번) 탑승 장소 표시 |
| `VignetteDataProvider` | `VignetteDataProviderMixin` | 은테(희귀) 몬스터, 보물 상자 등 미니맵/월드맵 연동 비네트 표시 |
| `DungeonEntranceDataProvider` | `DungeonEntranceDataProviderMixin` | 월드맵에 던전/레이드 입구 아이콘 표시 및 툴팁 제공 |

---

## 3. 커스텀 핀 구현 표준 코드 패턴

### ① 핀 객체 (Lua Mixin) 구현
`MapCanvasPinMixin`을 상속하여 아이콘의 크기, 줌 한계, 레이어 우선순위를 지정합니다.

```lua
-- 1. 핀 객체의 동작 정의
CustomMapPinMixin = CreateFromMixins(MapCanvasPinMixin);

function CustomMapPinMixin:OnLoad()
    -- 핀이 생성될 때 초기화 설정
    -- SetScalingLimits(maxScale, minScale, baseScale)을 사용해 지도 줌아웃 시 아이콘 크기 고정
    self:SetScalingLimits(1, 0.8, 0.8);
end

function CustomMapPinMixin:OnAcquired(pinData)
    -- 핀이 활성화되어 지도에 렌더링될 때 데이터 매핑
    self.pinData = pinData;
    self.Texture:SetTexture(pinData.texture or "Interface\\Icons\\INV_Misc_QuestionMark");
    
    -- 비율 좌표 (0.0 ~ 1.0 범위의 x, y)를 사용해 지도 위에 배치
    self:SetPosition(pinData.x, pinData.y);
end

function CustomMapPinMixin:OnReleased()
    -- 핀이 해제되고 객체 풀(Pool)로 반환될 때 리소스 해제
    self.pinData = nil;
end

function CustomMapPinMixin:OnMouseEnter()
    -- 마우스 호버 시 툴팁 출력
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetText(self.pinData.name or "알 수 없는 핀");
    GameTooltip:Show();
end

function CustomMapPinMixin:OnMouseLeave()
    GameTooltip:Hide();
end
```

### ② XML 템플릿 정의
월드맵 캔버스 프레임에 로드되어 복제(Acquire)될 핀 템플릿 프레임을 XML에 등록합니다. `MapCanvasPinTemplate`을 반드시 상속해야 합니다.

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <!-- inherits="MapCanvasPinTemplate" 필수 상속 -->
    <Frame name="CustomMapPinTemplate" inherits="MapCanvasPinTemplate" virtual="true">
        <Size x="24" y="24"/>
        <Layers>
            <Layer level="ARTWORK">
                <Texture parentKey="Texture" setAllPoints="true"/>
            </Layer>
        </Layers>
        <Scripts>
            <OnLoad>
                Mixin(self, CustomMapPinMixin);
                self:OnLoad();
            </OnLoad>
        </Scripts>
    </Frame>
</Ui>
```

### ③ 데이터 프로바이더 (Lua Mixin) 구현
실질적으로 지도가 열리거나 변경될 때 핀을 갱신하는 매니저입니다.

```lua
-- 2. 데이터 프로바이더 정의
CustomMapDataProvider = CreateFromMixins(MapCanvasDataProviderMixin);

function CustomMapDataProvider:RemoveAllData()
    -- 기존에 그려진 핀들을 회수하여 풀로 돌려보냄
    self:GetMap():RemoveAllPinsByTemplate("CustomMapPinTemplate");
end

function CustomMapDataProvider:RefreshAllData(fromOnShow)
    self:RemoveAllData();

    local mapID = self:GetMap():GetMapID();
    
    -- 예시: 임의의 데이터 테이블에서 해당 맵의 좌표 데이터를 가져옴
    local pinList = MyCustomAddonDB[mapID];
    if not pinList then return end

    for _, data in ipairs(pinList) do
        -- AcquirePin을 통해 템플릿 핀을 캔버스 프레임에 추가
        local pin = self:GetMap():AcquirePin("CustomMapPinTemplate", data);
        pin:Show();
    end
end
```

### ④ 데이터 프로바이더 등록
애드온 초기화 시점(`PLAYER_LOGIN` 등)에 `WorldMapFrame`에 데이터 프로바이더를 등록합니다.

```lua
-- 3. 월드맵 프레임워크에 추가
WorldMapFrame:AddDataProvider(CustomMapDataProvider);
```

---

## 4. 핵심 API 및 주요 메서드 요약

* `self:SetPosition(x, y)`: 핀의 위치를 지정합니다. `x`, `y`는 지도 전체 대비 좌측 상단을 원점으로 하는 **0.0 ~ 1.0 범위의 정규화된 비율 좌표**입니다.
* `self:SetScalingLimits(maxScale, minScale, baseScale)`: 지도 확대/축소 시 핀의 크기가 지나치게 커지거나 작아지지 않도록 축척 스케일의 상/하한선을 보정합니다.
* `self:UseFrameLevelType(frameLevelType)`: 여러 핀이 겹쳤을 때 렌더링 우선순위(프레임 레벨)를 결정합니다. (예: `"PIN_FRAME_LEVEL_CORPSE"`, `"PIN_FRAME_LEVEL_QUEST"` 등)
* `self:GetMap():AcquirePin(pinTemplate, ...)`: 맵 캔버스의 내부 객체 풀에서 사용 가능한 핀 프레임을 획득하여 성능 렉(가비지 누수)을 방지합니다.
