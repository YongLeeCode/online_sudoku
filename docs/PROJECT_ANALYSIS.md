# Sudoku Clash — 프로젝트 분석 문서

> 실시간 멀티플레이어 + 아이템 배틀 온라인 스도쿠 게임
> Flutter + Supabase 기반 / Clean Architecture
>
> 본 문서는 `lib/` 전체 소스, `supabase/schema.sql`, 빌드 스크립트를 직접 읽고 정리한 코드 기준 분석입니다. (작성일 2026-06-02)

---

## 1. 한눈에 보기

| 항목 | 내용 |
|------|------|
| 앱 이름 | Sudoku Clash (`pubspec` name: `online_sudoku`) |
| 버전 | 1.0.0+1 |
| 목적 | 같은 퍼즐을 여러 명이 동시에 풀며 경쟁 + 아이템으로 상대 방해 |
| 플랫폼 | Flutter 모바일 (Android/iOS, macOS 설정 존재) |
| 백엔드 | Supabase (Postgres + Realtime), 무료티어 가정 |
| 인증 | 없음 (anon 키, RLS는 전체 허용 정책) — 가족/지인용 |
| 게임 종료 후 | 관련 DB 레코드 전체 삭제 → 저장공간 0 유지 |

빌드 시 환경변수 주입 필수:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

`run.sh`가 `.env`를 읽어 위 두 값을 자동 주입한다. `main()` 진입 시 두 값이 비어있으면 `assert`로 중단된다.

---

## 2. 기술 스택 / 의존성

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `flutter` (Dart SDK) | `^3.11.0` | 프레임워크 |
| `supabase_flutter` | `^2.0.0` | DB / Realtime / RPC |
| `flutter_riverpod` | `^2.0.0` | 상태관리 |
| `riverpod_annotation` + `riverpod_generator` | `^2.0.0` | (선언만 되어 있고 현재 코드젠 미사용) |
| `shared_preferences` | `^2.2.0` | 닉네임 로컬 저장 |
| `uuid` | `^4.0.0` | 임시 host_id 생성 |
| `gap` | `^3.0.0` | 레이아웃 간격 위젯 |
| `animated_text_kit` | `^4.0.0` | (의존성에만 존재, 실사용 코드 미확인) |

> 참고: `riverpod_generator`/`build_runner`가 dev 의존성에 있으나 현재 모든 Provider는 **수동 선언 방식**(`StateProvider`, `StreamProvider.autoDispose` 등)으로 작성되어 있다. `.g.dart` 생성 파일은 사용하지 않는다.

---

## 3. 아키텍처

Clean Architecture를 단순화한 3계층 구조.

```
lib/
├── main.dart                 # 앱 진입점, Supabase 초기화, 앱 생명주기 → 연결/해제 처리
│
├── core/                     # 공통 (프레임워크/도메인 비의존)
│   ├── constants/
│   │   ├── app_constants.dart        # 게임 상수
│   │   └── supabase_constants.dart   # 테이블명 상수
│   ├── utils/
│   │   └── puzzle_generator.dart     # 시드 기반 스도쿠 생성기 (백트래킹)
│   └── errors/
│       └── app_exception.dart        # 도메인 예외 (RoomFull/NotFound/AlreadyStarted)
│
├── data/                     # 데이터 계층
│   ├── models/               # DB ↔ Dart 매핑 모델
│   │   ├── room_model.dart
│   │   ├── room_settings_model.dart
│   │   ├── player_model.dart
│   │   └── item_model.dart            # ItemType enum + 확장 (emoji/name/dbKey/targetsOpponent)
│   └── repositories/         # Supabase 접근 캡슐화
│       ├── room_repository.dart       # 방/플레이어/설정 CRUD + Realtime 스트림
│       ├── game_repository.dart       # 게임 생성/진행률/순위/정리(cleanup)
│       └── event_repository.dart      # 아이템 사용 이벤트 송수신
│
├── domain/
│   └── providers/            # Riverpod 상태/비즈니스 로직
│       ├── room_provider.dart         # 닉네임/방/플레이어/설정 스트림, 로비 액션
│       ├── multiplayer_provider.dart  # 게임ID/seed/상대 진행률 스트림
│       └── game_provider.dart         # ★ 스도쿠 게임 엔진 (입력/검증/아이템 효과)
│
└── presentation/
    ├── screens/
    │   ├── home_screen.dart                # 닉네임 입력, 방 생성/입장, 싱글 난이도 선택
    │   ├── lobby_screen.dart               # 대기실, 설정, 준비/시작
    │   ├── game_screen.dart                # 싱글플레이 게임
    │   ├── multiplayer_game_screen.dart    # ★ 멀티플레이 게임 (가장 복잡)
    │   └── result_screen.dart              # 순위 결과
    └── widgets/
        ├── sudoku/{sudoku_grid, sudoku_cell, number_pad}.dart
        ├── lobby/{player_card, settings_panel}.dart
        └── hud/item_slot.dart
```

**의존성 방향**: presentation → domain(providers) → data(repositories) → Supabase. `game_provider`만 예외적으로 순수 게임 로직(네트워크 비의존)을 담고, 진행률/아이템 획득은 콜백(`onProgressChanged`, `onItemCollected`)으로 화면에 위임한다.

---

## 4. 데이터 모델

### RoomModel (`rooms`)
`id, code(6자리), hostId, status, maxPlayers, createdAt`
- `status`: `waiting` → `playing` → (`finished`) / `closed`(호스트 이탈 표시, 코드 전용)

### PlayerModel (`players`)
`id, roomId, nickname, isHost, isReady, isConnected, joinedAt, lastSeenAt?`
- 방장(`isHost`)은 생성 시 `isReady=true` 고정
- `isConnected`로 입장/이탈 표시 (실제 행 삭제는 게임 종료 cleanup 때)

### RoomSettingsModel (`room_settings`)
`roomId, difficulty(1~10), penaltySeconds, maxItemCount, allowedItems[], hintCounts{}`
- ⚠️ **DB 컬럼명과 모델 필드명이 다름**: DB의 `item_interval` 컬럼을 모델에서는 `maxItemCount`(0~15로 clamp)로 매핑한다. 즉 "아이템 등장 간격"이 아니라 "보드에 뿌릴 아이템 칸 개수"로 의미가 바뀌었다.
- `allowedItems` 기본값: 전체 7종

### ItemType (enum, `item_model.dart`)

| enum | 이모지 | 한글명 | dbKey | 대상 | 효과 |
|------|:---:|------|------|:---:|------|
| `hint` | 💡 | 힌트 | `hint` | 자신 | 선택한 빈 칸에 정답 자동 입력 |
| `blind` | 🌫️ | 블라인드 | `blind` | 상대 | 랜덤 3×3 박스를 N초간 가림(숫자만, 입력은 가능) |
| `freeze` | ⏸️ | 프리즈 | `freeze` | 상대 | N초간 입력 잠금 |
| `itemCut` | ✂️ | 아이템 커터 | `item_cut` | 상대 | 상대 슬롯의 첫 아이템 1개 제거 |
| `shield` | 🛡️ | 방어막 | `shield` | 자신 | 다음 상대 공격 1회 방어 |
| `reverse` | 💥 | 리버스 | `reverse` | 상대 | 상대가 채운 정답 칸 1개를 랜덤으로 지움 |
| `mystery` | ❓ | 미스터리 | `mystery` | 즉시 | 8가지 랜덤 결과(자신/상대 × 좋음/나쁨) |

`targetsOpponent`가 true인 것(`blind/freeze/itemCut/reverse`)은 사용 시 **상대 게이지를 탭**해 타겟을 지정한다.

---

## 5. Supabase DB 스키마 & RPC

`supabase/schema.sql` 기준 6개 테이블 + 인덱스 + RLS(전체 허용) + Realtime 발행.

```
rooms ──< room_settings (room_id FK, cascade)
  │
  ├──< players (room_id FK, cascade)
  │
  └──< games (room_id FK, cascade)
         │
         ├──< player_game_states (game_id FK + player_id FK, cascade)
         └──< game_events (game_id FK + player_id FK, cascade)
```

Realtime 발행 테이블: `rooms`, `players`, `player_game_states`, `game_events`.

### 사용 중인 RPC 함수 (Postgres 측)
코드가 호출하지만 `schema.sql`에는 정의가 없는 서버 함수 — **별도로 DB에 배포되어 있어야 함**:

- `join_room(p_code, p_nickname)` → `{room, player}` JSON 반환. 방 조회·정원·시작여부 체크 + 플레이어 insert를 **원자적으로** 처리(동시 입장 레이스 방지). 실패 시 `ROOM_NOT_FOUND` / `GAME_ALREADY_STARTED` / `ROOM_FULL` 메시지를 던지고, 클라이언트가 이를 도메인 예외로 변환.
- `assign_player_rank(p_game_id, p_player_id)` → `int`. 클리어 순간 순위를 원자적으로 결정해 반환.

> ⚠️ **스키마 드리프트 주의**: `schema.sql`은 현재 코드와 일부 어긋난다.
> - `players`에 `last_seen_at` 컬럼이 코드상 사용되나 스키마엔 없음(추가 필요).
> - `games.answer_grid jsonb not null`로 정의돼 있으나 `createGame`은 `answer_grid`를 넣지 않음 → 실 DB에서는 NOT NULL이 풀렸거나 컬럼이 제거된 상태일 것.
> - `player_game_states`의 `item_slots`, `is_penalized`는 코드와 일치.
> - 위 RPC 2개가 스키마 파일에 누락.
> 실제 운영 DB는 코드 기준으로 마이그레이션된 상태이며, `schema.sql`은 초기 버전에 가깝다.

---

## 6. 상태 관리 (Riverpod Provider 맵)

### room_provider.dart
| Provider | 타입 | 역할 |
|----------|------|------|
| `supabaseProvider` | Provider | SupabaseClient |
| `roomRepositoryProvider` | Provider | RoomRepository |
| `nicknameProvider` | StateNotifier\<String\> | SharedPreferences 영속 닉네임 |
| `currentRoomProvider` | StateProvider\<RoomModel?\> | 현재 방 |
| `currentPlayerProvider` | StateProvider\<PlayerModel?\> | 내 플레이어 |
| `roomSettingsProvider` | StateProvider\<RoomSettingsModel?\> | 로컬 설정 캐시 |
| `playersStreamProvider` | StreamProvider.autoDispose | 플레이어 목록 (2초 폴링 + Realtime) |
| `roomStreamProvider` | StreamProvider.autoDispose | 방 상태 (폴링 + Realtime) |
| `roomSettingsStreamProvider` | StreamProvider.autoDispose | 설정 (폴링 + Realtime) |
| `heartbeatProvider` | Provider.autoDispose | 30초마다 `last_seen_at` 갱신 |
| `allReadyProvider` | Provider\<bool\> | 방장 제외 전원 준비 여부 |
| `lobbyActionsProvider` | Provider\<LobbyActions\> | 방 생성/입장/준비/설정/시작/퇴장 |

### multiplayer_provider.dart
| Provider | 역할 |
|----------|------|
| `gameRepositoryProvider`, `eventRepositoryProvider` | 저장소 |
| `currentGameIdProvider`, `currentGameSeedProvider` | 현재 게임 식별/시드 |
| `selectedItemSlotProvider` | 타겟 선택 모드용 (실제로는 화면 local state 사용) |
| `firstClearProvider` | 1등 확정 여부 (오버타임 트리거) |
| `overtimeRemainingProvider` | 오버타임 카운트다운(초) |
| `opponentStatesProvider` | StreamProvider — 전원 진행률 (2초 폴링 + Realtime) |

### game_provider.dart (게임 엔진)
- `selectedCellProvider`: 선택 셀 `(row,col)?`
- `difficultyProvider`: 싱글 난이도
- `memoModeProvider`: 메모(연필) 모드
- `gameProvider`: `StateNotifierProvider<GameNotifier, GameState?>` — 핵심 로직 보유

---

## 7. 핵심 게임 엔진 — `GameNotifier` / `GameState`

`GameState`는 9×9 보드 전체 상태를 불변 객체로 보관:
`puzzle`(초기), `current`(현재 입력), `solution`(정답), `notes`(메모 9×9 Set), `errorCells`, `filledCount/totalBlanks`, 패널티/블라인드/프리즈/방어막 상태, `itemCells`, `itemPool`, `myItems[4]`.

- `copyWith`는 `blindedBoxIndex`에 sentinel(`_absent`)을 써서 "null로 설정(해제)"과 "변경 안 함"을 구분한다.
- `progress = filledCount / totalBlanks`, `isInputBlocked = isPenalized || isFrozen`.

### 퍼즐 생성 (`PuzzleGenerator`)
1. 시드로 `Random` 생성 → 대각선 3개 박스를 먼저 무작위로 채움(서로 독립).
2. 나머지는 백트래킹(`_solveSudoku`)으로 완성.
3. 난이도→빈칸 수: `27 + round(difficulty * 2.8)` (난이도 1~10 → 약 30~55칸).
4. 칸 제거. **유일해 보장 검증은 없음** (제거만 하므로 복수해 가능성 존재).

→ **같은 seed면 모든 클라이언트가 동일 퍼즐**. 아이템 칸은 `Random(seed ^ 0xCAFEBABE)`로 빈칸을 섞어 앞에서 `maxItemCount`개를 선택 → 전원 동일한 아이템 칸.

### 입력 흐름 (`inputNumber`)
- 메모 모드: 후보 숫자 토글.
- 오답: `isPenalized=true`, `penaltyRemaining=penaltySeconds`로 입력 잠금(오답은 보드에 쓰지 않음).
- 정답: 칸 채움 + 같은 행/열/박스의 해당 숫자 메모 자동 제거 + 아이템 칸이면 `itemPool`에서 랜덤 획득(빈 슬롯 있을 때만, 없으면 소멸).
- 전 칸 정답이면 `isCompleted=true`, `completedDuration` 기록.
- 매 변경마다 `onProgressChanged(filled, completed)` 콜백 호출 → 멀티에서 DB 진행률 동기화.

### 아이템 효과 메서드
`useHintItem` / `removeItemAt` / `removeFirstItem` / `applyBlind` / `applyFreeze` / `applyShield` / `consumeShield` / `applyReverse` / `applyRandomHint` + 틱 메서드(`penaltyTick`/`blindTick`/`freezeTick`).

---

## 8. 화면별 흐름

### HomeScreen
- 닉네임(≤20자) 입력 → SharedPreferences 저장.
- **방 만들기**: `createRoom` → 방/설정/방장 생성 후 LobbyScreen push.
- **코드 입장**: 6자리 코드 → `joinRoom`(RPC).
- **혼자 풀기**: 난이도 슬라이더(1~10) → `startGame(difficulty)` (아이템 풀은 `hint`만) → GameScreen.

### LobbyScreen
- 상단에 방 코드(복사 가능). 참여자 목록(`PlayerCard`), 게임 설정(`SettingsPanel`).
- 방장만 설정 변경 가능(난이도/패널티/아이템 개수 슬라이더) → 즉시 DB 반영, 참여자는 `roomSettingsStreamProvider`로 동기화.
- 준비: 방장 제외 전원 준비 시 방장의 "게임 시작!" 활성(`allReadyProvider`).
- **시작**: 방장이 `createGame`(seed 생성·states insert) 후 방 status를 `playing`으로 변경 → 모든 클라이언트가 `roomStreamProvider`로 감지하고 `_navigateToGame()` 실행. 이때 **항상 DB에서 최신 설정을 다시 fetch**해 동일 seed·동일 설정으로 시작.
- **이탈 처리**: 뒤로가기는 `PopScope`로 가로채 `_onLeave` 호출(disconnect, 방장이면 `closeRoom`→status `closed`). 다른 사람은 status `closed` 감지 시 홈으로 튕기고 안내.

### MultiplayerGameScreen (가장 복잡)
6개의 타이머 운용: 경과시간/패널티/블라인드/프리즈/오버타임/아이템이벤트폴링.

- **진행률 동기화**: `_onProgressChanged` → `updateProgress` DB 반영. 완료 시 `firstClear` set + `assign_player_rank` RPC.
- **상대 진행률**: `opponentStatesProvider`(2초 폴링+Realtime) → 세로 게이지 바로 표시.
- **아이템 사용(발신)**:
  - 힌트: 빈 칸 선택 후 슬롯 탭 → 즉시 자기 보드에 적용.
  - 방어막: 즉시 `applyShield` + 슬롯 제거.
  - 미스터리: `_useMysteryItem` 8지선다 랜덤(자신 힌트/방어막/프리즈/블라인드, 상대 프리즈/블라인드/리버스/힌트역효과). 상대 없으면 자기 힌트로 폴백.
  - 공격형: 슬롯 선택 → 상대 게이지 "TAP" → `sendItemEvent`(game_events insert) + 슬롯 제거 + 비행 이모지 애니메이션(`_FlyingEmoji` Overlay).
- **아이템 수신**: 2초마다 `fetchItemEventsAfter`로 나를 타겟한 이벤트 폴링. `_processedEventIds`로 중복 방지. 방어막 보유 시 `consumeShield`로 1회 차단.
- **종료 조건(오버타임)**: 누군가 클리어하면 `firstClearProvider` set → `_startOvertime`(`AppConstants.overtimeSeconds`=10초) 카운트다운. 0이 되거나 "전원 완료/이탈"이면 `_endGame`.
- **`_endGame`**: 타이머 즉시 취소 → `finishGame` → 결과 집계(메모리 스냅샷 `_lastKnownOpponentStates` 우선, 없으면 DB 재조회) → `cleanupGame`으로 **관련 DB 전체 삭제**(FK 순서 준수) → 로컬 상태 초기화 → ResultScreen.

### ResultScreen
- `rank` 우선, 없으면 진행률 내림차순 정렬. 1등 트로피 카드 + 전체 순위 리스트(메달색). "홈으로"로 첫 화면 복귀.

### GameScreen (싱글)
- 멀티와 유사하나 상대/이벤트/오버타임 없음. 아이템은 힌트만 동작(공격형은 "멀티에서만 사용 가능" 안내). 완료 시 다이얼로그.

---

## 9. 실시간 동기화 전략

**Realtime 단독을 신뢰하지 않고 "2초 폴링 + Realtime 콜백"을 병행**한다(무료티어 Realtime 누락 대비). 폴링·Realtime 둘 다 동일한 `fetch()`를 호출하고, `StreamController`로 합쳐 화면에 전달. 적용 대상:
- 로비: 플레이어 목록 / 방 상태 / 방 설정
- 게임: 상대 진행률(`player_game_states`), 내게 온 아이템 이벤트(`game_events`)

연결 관리:
- `heartbeatProvider`: 30초마다 `last_seen_at` 갱신(로비·게임 화면에서 watch).
- 앱 생명주기(`main.dart`): `paused` 1분 후 disconnect 예약, `resumed` 시 취소 후 reconnect, `detached` 시 즉시 disconnect.

---

## 10. 주요 상수 (`AppConstants`)

| 상수 | 값 | 의미 |
|------|---:|------|
| `maxPlayers` | 6 | 방 최대 인원 |
| `roomCodeLength` | 6 | 방 코드 길이 |
| `itemSlotCount` | 4 | 아이템 슬롯 수 |
| `defaultItemInterval` | 10 | (레거시) |
| `overtimeSeconds` | 10 | 1등 등장 후 종료까지 |
| `defaultPenaltySeconds` | 5 | 기본 오답 패널티 |

방 코드 문자셋: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (혼동 문자 I/O/0/1 제외).

---

## 11. 구현상 주목할 점 / 잠재 이슈

- **퍼즐 유일해 미보장**: `_removeCells`가 검증 없이 칸만 제거해 복수해 퍼즐이 나올 수 있음. 단, 정답 검증은 `solution` 배열과 직접 비교하므로 "다른 유효해"도 오답 처리된다.
- **경쟁 조건 방어 흔적**: `_endGame`이 여러 클라이언트에서 동시에 `cleanupGame`을 호출해도 "먼저 성공한 쪽만 유효, 나머지는 무시"하도록 설계. 스트림이 cleanup 직후 빈 값을 emit할 때를 대비해 `_lastKnownOpponentStates` 스냅샷을 결과로 사용.
- **`Random()` 무시드 사용처**: 아이템 획득 종류, 블라인드 박스, 리버스/랜덤힌트 대상 등은 비결정적(각 클라이언트 로컬). 퍼즐·아이템 칸만 seed 동기화.
- **`selectedItemSlotProvider`** 는 선언돼 있으나 멀티 화면은 위젯 local `_selectedItemSlot`을 사용한다(중복/미사용 가능성).
- **`SettingsPanel`의 `allowedItems`**: UI에서 종류 토글은 없고 항상 전체 풀을 넘긴다. 설정은 난이도/패널티/아이템 개수만 조절.
- **스키마 드리프트**: 6장 경고 참조 — `schema.sql`을 코드 기준으로 갱신 필요.
- 멀티 게임에 `freeze` 발신 시 duration 5초, `reverse`는 0, 그 외(blind 등)는 30초로 전송하나, 수신측 블라인드 표시 로직과의 정합성은 이벤트 payload `duration`에 의존.

---

## 12. 빌드 / 실행

```bash
# .env 에 SUPABASE_URL, SUPABASE_ANON_KEY 정의 후
./run.sh                    # = flutter run --dart-define=... (추가 인자 전달 가능)

# 직접 실행 시
flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

DB는 `supabase/schema.sql` 실행 후 `join_room`·`assign_player_rank` 함수와 `last_seen_at` 컬럼을 추가로 배포해야 정상 동작한다.
