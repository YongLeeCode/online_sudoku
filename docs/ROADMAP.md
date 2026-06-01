# Sudoku Clash — 개발 로드맵

> 현재까지 구현된 기능과 앞으로 추가할 기능을 정리한 로드맵.
> 코드 분석 기준 작성일 2026-06-02. 상세 구조는 [`PROJECT_ANALYSIS.md`](./PROJECT_ANALYSIS.md) 참고.
> **Phase 1~8은 사용자가 지정한 진행 순서대로 번호가 매겨져 있다.**

**범례**: `[x]` 완료 · `[ ]` 예정 · 🔴 큰 작업 · 🟡 중간 · 🟢 작은 작업 · ⚠️ 선행 의존성 있음

---

## ✅ Phase 0 — 현재까지 완료된 것

### 기반 / 인프라
- [x] Flutter + Supabase 프로젝트 구성, Clean Architecture 3계층
- [x] Supabase 초기화 + 환경변수(`--dart-define`) 주입, `run.sh`
- [x] 시드 기반 스도쿠 생성기 (백트래킹, 난이도→빈칸 수)
- [x] Riverpod 상태관리 구조

### 싱글플레이
- [x] 혼자 풀기 (난이도 1~10 슬라이더)
- [x] 정답 검증 + 오답 패널티(입력 잠금)
- [x] 메모(연필) 기능 — 정답 입력 시 같은 행/열/박스 메모 자동 제거
- [x] 힌트 아이템
- [x] 완료 시간 측정 + 완료 다이얼로그

### 멀티플레이
- [x] 6자리 코드 방 생성 / 입장 (최대 6명), 코드 복사
- [x] 닉네임 영속 (SharedPreferences)
- [x] 로비: 참여자 목록, 준비 시스템, 방장 설정 변경(난이도/패널티/아이템 개수)
- [x] 동일 seed → 전원 동일 퍼즐 + 동일 아이템 칸
- [x] 실시간 동기화 (2초 폴링 + Realtime 병행)
- [x] 상대 진행률 게이지
- [x] 아이템 배틀 7종 (hint/blind/freeze/itemCut/shield/reverse/mystery)
- [x] 타겟 선택(게이지 탭) + 방어막 + 비행 이모지 애니메이션
- [x] 오버타임(1등 등장 후 10초) 종료 로직
- [x] 결과 화면 (순위 정렬)
- [x] 게임 종료 시 DB 데이터 전체 삭제(cleanup)
- [x] 연결 관리: heartbeat(30초), 앱 생명주기 disconnect/reconnect
- [x] 원자적 입장/순위 RPC (`join_room`, `assign_player_rank`)

---

## ✅ Phase 1 — 난이도 라벨 변경 🟢 (완료)

> 1~10 슬라이더 → **5단계 라벨(Very Easy / Easy / Normal / Hard / Extreme)** 로 변경. **완료 (2026-06-02)**

- [x] `Difficulty` enum 도입 (`veryEasy, easy, normal, hard, extreme`) — `lib/core/constants/difficulty.dart`
  - 빈칸 수 매핑: VeryEasy=30, Easy=38, Normal=45, Hard=52, Extreme=58
  - 색상은 presentation 전용 확장(`DifficultyColor`)으로 분리(코어는 Flutter 비의존)
- [x] `PuzzleGenerator.generate`가 `Difficulty`를 받아 `difficulty.blanks` 사용 (`_blanksForDifficulty` 제거)
- [x] `home_screen.dart` 슬라이더 → `DifficultySelector`(ChoiceChip Wrap)로 교체
- [x] `settings_panel.dart` 멀티 로비 난이도 UI도 `DifficultySelector` 재사용으로 교체
- [x] `RoomSettingsModel.difficulty` 저장 형식 = **정수 `dbValue` 1~5** (Open Q#7 결정). Dart에선 `Difficulty` 타입, 직렬화 시 `dbValue`로 변환
- [x] DB `room_settings.difficulty` check 제약 갱신: `schema.sql`을 `between 1 and 5` + 기본값 3으로 수정
  - ⚠️ **라이브 DB**: 기존 제약 `between 1 and 10`이 1~5를 이미 허용하므로 동작상 마이그레이션 불필요. 제약 강화를 원하면 운영 DB에 `alter table room_settings drop constraint ...; add check (difficulty between 1 and 5)` 적용
- [x] `difficultyProvider` 타입 변경(`StateProvider<Difficulty>`) 및 호출부 정리 (game_provider/game_repository/lobby_screen)
- [x] 하위호환: `Difficulty.fromDbValue`가 레거시 1~10 값을 clamp(6~10→Extreme)로 흡수

**리스크 해소**: `dbValue` 1~5는 기존 컬럼·제약과 호환되어 라이브 DB 손대지 않음. 진행 중인 기존 방의 레거시 difficulty 값은 `fromDbValue` clamp로 안전하게 매핑됨.

---

## 🏠 Phase 2 — 홈 화면 Mode 구조 개편 🟡 (완료)

> 상단에 **Mode 선택(Single / Multi / Rank)**, 선택에 따라 하단 내용이 바뀌는 구조. **완료 (2026-06-02)**

- [x] 상단 Mode 탭/세그먼트 (`Single` · `Multi` · `Rank`) — `HomeMode` enum + `SegmentedButton`(`_ModeSelector`)
- [x] **Single 탭** (`_SinglePane`)
  - [x] 혼자 풀기 + 난이도 선택(Phase 1 `DifficultySelector` 재사용)
  - [x] 튜토리얼 진입 버튼 — "준비 중" 타일(`_ComingSoonTile`), Phase 4 연결 자리
  - [x] 챌린지 진입 버튼 — "준비 중" 타일, Phase 7 연결 자리
- [x] **Multi 탭** (`_MultiPane`)
  - [x] 닉네임 입력
  - [x] 방 만들기 버튼
  - [x] 방 코드 입력 + 입장 버튼
  - [x] (기존 `home_screen`의 멀티 로직 이전/정리 — `_createRoom`/`_joinRoom` 그대로 재사용)
- [x] **Rank 탭** (`_RankPane`, Phase 6으로 연결) — "준비 중" placeholder 카드 + `랭크 매치 시작`(안내 스낵바)
- [x] `home_screen.dart` 리팩토링 (모드별 위젯 분리, 상태 보존)
  - 상태 보존: 닉네임/코드 컨트롤러·`_mode`는 `_HomeScreenState`에, 난이도는 provider에 유지 → 탭 전환에도 보존
- [x] **반응형 UI**: `Center`+`ConstrainedBox(maxWidth:480)` 폭 제한, 좁은(`<360`)·낮은(`<640`) 화면 패딩/여백/폰트 축소, 전체 `SingleChildScrollView`로 세로 잘림 방지, 타이틀 `FittedBox(scaleDown)`로 가로 잘림 방지, 좁은 세그먼트(`<300`)는 라벨 숨김

**의존성**: Rank 탭 내용은 Phase 5(프로필)·Phase 6 완료 후 채워짐. 현재는 UI 골격만 잡고 Rank·튜토리얼·챌린지는 "준비 중" 처리.

---

## 💡 Phase 3 — 아이템 설명 페이지 + 하단 탭 네비게이션 🟢 (완료)

> 7종 아이템의 효과를 한눈에 보는 도감/설명 페이지. **완료 (2026-06-02)**
> 진입점은 사용자 요청에 따라 **하단 탭(메인 / 아이템 설명 / 나)** 으로 구성.

### 하단 네비게이션 도입
- [x] `RootScreen`(`lib/presentation/screens/root_screen.dart`) 신설 — `NavigationBar`(M3) + `IndexedStack`로 탭 상태(스크롤·입력) 보존
  - 탭: **메인**(`HomeScreen`) · **아이템 설명**(`ItemGuideScreen`) · **나**(`ProfileScreen`)
- [x] `main.dart` 진입점을 `HomeScreen` → `RootScreen`으로 교체 (로비/게임은 각 탭에서 기존처럼 `Navigator.push`로 위에 쌓임)

### 아이템 설명 페이지
- [x] 아이템 가이드 화면 신설 (`item_guide_screen.dart`) — 하단 탭 "아이템 설명"으로 진입
- [x] 항목별 표시: 이모지 · 이름 · 효과 설명 · 지속시간(뱃지)
  - `item_model.dart`의 `ItemType`(emoji/name) 재사용 + **`description`/`durationLabel`/`target`(`ItemTarget` enum) 추가 정의**
  - 지속시간 라벨은 게임 로직 값 기준: blind=30초, freeze=5초, shield=1회 방어, 나머지=즉시
- [x] 자신용(`나에게`)/상대용(`상대에게`)/즉시발동(`즉시 발동`, 미스터리) 그룹으로 구분 표시
- [x] 본문을 `ItemGuideList` 위젯으로 분리 → 튜토리얼(Phase 4)·로비에서 재사용 가능

### '나' 탭 (Phase 5/8 연결 전 골격)
- [x] `ProfileScreen` 신설 — 게스트 헤더 + 메뉴(통계/어워드/설정/도움말) "준비 중" 처리
  - 실제 데이터(전적·승률·트로피·랭크점수)는 Phase 5(프로필) 이후 채움

**의존성**: 없음. 기존 `ItemType` 확장만으로 구현. '나' 탭의 통계/어워드는 Phase 5(영구 사용자 식별) 선행 필요.

---

## 📖 Phase 4 — 튜토리얼 모드 🟡 (싱글 모드 내, 단계별)

> 싱글 모드 안에서 **단계별 튜토리얼**로 처음 하는 사람도 규칙·조작을 익히도록.

- [ ] 튜토리얼 진입점: 홈 Single 탭에 "튜토리얼" 버튼 (Phase 2와 연결)
- [ ] 단계(step) 시나리오 정의 → **결정 필요**(아래 Open Questions)
  - 예시 단계: ① 셀 선택·숫자 입력 → ② 행/열/박스 규칙 → ③ 메모(연필) 사용 → ④ 오답 패널티 → ⑤ 아이템 칸·획득 → ⑥ (멀티 안내) 아이템으로 상대 방해/방어
- [ ] 단계별 가이드 UI (코치마크/하이라이트 + 말풍선, "다음" 진행)
- [ ] 스크립트형 미니 퍼즐(또는 고정 보드)로 각 동작을 직접 따라하게
- [ ] 진행 중 잘못된 조작 차단/유도 (해당 단계 외 입력 제한)
- [ ] 튜토리얼 완료 상태 저장 (최초 1회 자동 노출 여부 — SharedPreferences 또는 프로필)
- [ ] 건너뛰기/다시보기 지원

**의존성**: 홈 Single 탭(Phase 2). 게임 엔진 재사용하되 "가이드/제한 모드" 플래그 추가 검토. 아이템 설명은 Phase 3 컴포넌트 재사용 가능. 프로필 연동(완료 저장)은 선택.

---

## 🧱 Phase 5 — 기반 정비: 영구 사용자 식별 (랭크·통계·트로피의 공통 선행 작업) 🔴 ⚠️

> 랭크·통계·챌린지 트로피는 모두 **게임이 끝나도 사라지지 않는 사용자 데이터**가 필요하다.
> 현재 구조는 익명(`players` 행이 게임 종료 시 삭제)이라, 먼저 영구 사용자 식별을 도입해야 한다.

### 5-A. 영구 사용자 식별/프로필 🔴 (랭크·통계·트로피의 전제)
- [ ] 사용자 식별 방식 결정 → **결정 필요** (아래 Open Questions 참고)
  - 옵션 A: Supabase Auth 익명 로그인 (`signInAnonymously`) — 로그인 UX 없이 기기당 영구 uid
  - 옵션 B: 기기 저장 UUID(SharedPreferences) + `profiles` 테이블 매핑
- [ ] `profiles` 테이블 추가: `id, nickname, rank_score, wins, losses, created_at ...`
- [ ] 닉네임을 프로필 기준으로 이전 (현재 SharedPreferences 단독 → 프로필 동기화)
- [ ] `players` 행에 `profile_id` 연결 (게임 종료 cleanup 후에도 전적은 프로필에 누적)
- [ ] `schema.sql` 갱신 + 마이그레이션 (현재 스키마 드리프트도 함께 정리: `last_seen_at`, `answer_grid`, RPC 정의)

### 5-B. 데이터 영속 분리 🟡
- [ ] 게임 결과 집계 → 프로필 통계에 반영하는 경로 신설 (cleanup 전에 결과를 `match_history`로 적재)
- [ ] `match_history` 테이블: `id, game_id, profile_id, mode, rank, score_delta, duration, played_at`

---

## 🏆 Phase 6 — 랭크 모드 🔴 ⚠️(Phase 5 필요)

> 비슷한 랭크의 상대와 대전. **승리 시 점수 상승, 가장 늦게 풀면 점수 하락.**

- [ ] 랭크 점수 모델 결정 → **결정 필요** (ELO식 / 단순 가감점 / 티어제)
- [ ] 매치메이킹: 내 점수 ±범위 내 대기자 매칭
  - [ ] `matchmaking_queue` 테이블 또는 Supabase Edge Function/RPC
  - [ ] 대기열 입장/이탈/타임아웃, 봇 또는 범위 확장 폴백 정책
- [ ] 매칭 성사 → 기존 멀티 게임 플로우 재사용(동일 seed, 동일 난이도)
- [ ] 결과에 따른 점수 정산
  - [ ] 승리(1등) → 점수 상승
  - [ ] 최하위/최후 완료 → 점수 하락
  - [ ] 중간 순위 정산 규칙 정의 (다인 매치 시)
- [ ] 점수 변동을 `profiles.rank_score` 반영 + `match_history` 적재
- [ ] 랭크 매치 전용 결과 화면(점수 변동 +/- 표시)
- [ ] 어뷰징 방지(중도 이탈 시 패배 처리 등) 정책

**의존성**: Phase 5(프로필/식별), Phase 2(Rank 탭 UI). 매치메이킹은 무료티어 Realtime/폴링 한계 고려 필요.

---

## 🧩 Phase 7 — 챌린지 모드 🔴

> 매주 1개의 **특별하고 매우 어려운 문제**. 힌트 없음, 시간 제약 없음, 챌린지 전용 룰. 일반 게임과 분리 적용.

- [ ] 챌린지 전용 룰 정의 → **결정 필요** (현재 "특별한 룰"만 언급됨)
  - 예: 특정 셀 고정/금지, 색깔 영역 제약, 변형 스도쿠 등 — 구체화 필요
- [ ] 주간 문제 배포 방식
  - [ ] 옵션 A: ISO 주차 기반 결정적 seed로 클라이언트 생성
  - [ ] 옵션 B: `weekly_challenges` 테이블에 운영자가 등록/배포
- [ ] 챌린지 전용 게임 화면/플로우 (힌트·타이머 제약·아이템 제거, 별도 검증 로직)
- [ ] 챌린지 전용 `PuzzleGenerator`/검증기 (특별 룰 반영, 일반 생성기와 분리)
- [ ] 풀이 완료 시 **트로피** 지급 → 프로필에 누적 (Phase 8 통계와 연결)
- [ ] 챌린지 진행/완료 상태 저장 (`challenge_results`: `profile_id, week, solved_at, trophy`)
- [ ] 주차 전환 시 신규 문제 노출 + 과거 기록 보존

**의존성**: 트로피 누적은 Phase 5(프로필) 필요. 게임 엔진은 `game_provider`를 챌린지용으로 확장하거나 별도 Notifier 분리 검토.

---

## 📊 Phase 8 — 통계 / 어워드 / 전적 페이지 🟡 ⚠️(Phase 5 필요)

> 유저가 자신의 데이터를 볼 수 있는 프로필/마이페이지.

- [ ] 프로필 화면 신설 (홈에서 진입)
- [ ] 표시 항목
  - [ ] 랭크 점수 / 티어
  - [ ] 승/패 수, 승률
  - [ ] 평균 완료 시간, 최고 기록(난이도별)
  - [ ] 챌린지 트로피 목록 (주차별)
  - [ ] 누적 플레이 수 (싱글/멀티/랭크 구분)
- [ ] 어워드/업적 시스템 정의 (예: 첫 승리, 10연승, 챌린지 완주 등) → **결정 필요(업적 목록)**
- [ ] `profiles` + `match_history` + `challenge_results` 조회로 집계
- [ ] (선택) 리더보드 — 전체/주간 랭크 상위 노출

**의존성**: Phase 5(프로필), Phase 6(랭크 점수), Phase 7(트로피).

---

## 🔗 의존성 요약

```
Phase 5 (사용자 식별/프로필)  ──┬─→ Phase 6 (랭크 모드)
                               ├─→ Phase 7 트로피
                               └─→ Phase 8 (통계/전적)

Phase 1 (난이도 라벨)  ──→ Phase 2 (홈 Single 탭) ──┬─→ Phase 4 (튜토리얼 진입)
Phase 2 (홈 Rank 탭)   ──→ Phase 6                 └─→ Phase 7 (챌린지 진입)

Phase 3 (아이템 설명)  ── 독립 (의존성 없음) ──→ Phase 4에서 재사용 가능
```

**진행 순서**: 사용자가 지정한 대로 Phase 번호 순서대로 진행한다 → **1 → 2 → 3 → 4 → 5 → 6 → 7 → 8**.
(원래 기능 번호 기준으로는 난이도 → 홈개편 → 아이템설명 → 튜토리얼 → 기반정비 → 랭크 → 챌린지 → 통계 순)

> 참고: Phase 5(기반 정비)는 Phase 6·7·8의 전제다. 4번까지는 사용자 데이터 없이 독립 진행 가능하고, 5번부터 영구 사용자 식별 기반이 필요해진다.

---

## ❓ 결정 필요 (Open Questions)

1. **사용자 식별 방식**: Supabase Auth 익명 로그인 vs 기기 UUID + 프로필 테이블? (기기 변경/재설치 시 데이터 이전 정책 포함) — Phase 5
2. **랭크 점수 체계**: ELO식 vs 단순 가감점 vs 티어제? 다인(3~6명) 매치에서 중간 순위 점수 규칙은? — Phase 6
3. **매치메이킹 방식**: 실시간 대기열(폴링/Realtime)? 매칭 안 될 때 폴백(범위 확장/봇/대기 취소)? — Phase 6
4. **챌린지 "특별한 룰"의 구체 내용**: 어떤 변형 룰인지 정의 필요 (현재 미정). — Phase 7
5. **주간 챌린지 배포**: 결정적 seed 자동 생성 vs 운영자 수동 등록? — Phase 7
6. **어워드/업적 목록**: 어떤 업적을 제공할지. — Phase 8
7. ~~**난이도 저장 포맷**: 멀티 설정 동기화를 위해 정수 인덱스 vs 문자열 key.~~ → **결정 완료(Phase 1)**: 정수 `dbValue` 1~5. 기존 제약 `between 1 and 10`과 호환되어 라이브 DB 마이그레이션 불필요.
8. **튜토리얼 단계 구성**: 어떤 단계를 어떤 순서로 가르칠지, 스크립트형 고정 퍼즐 vs 자유 퍼즐, 최초 1회 강제 노출 여부. — Phase 4

---

## 🧹 곁다리 정리 거리 (백로그)
- [ ] `schema.sql` ↔ 실제 DB 동기화 (스키마 드리프트 해소)
- [ ] 미사용 의존성/Provider 정리 (`animated_text_kit`, `riverpod_generator`, `selectedItemSlotProvider` 등)
- [ ] 퍼즐 유일해 보장(현재 미보장) 검토 — 특히 챌린지/랭크에서 중요
- [ ] 테스트 보강 (현재 기본 `widget_test.dart`만 존재)
