# 🎮 멀티플레이어 스도쿠 게임 기획서

> Flutter + Supabase 기반 가족 실시간 스도쿠 게임

---

## 📌 프로젝트 개요

- **목적**: 가족끼리 동시에 동일한 스도쿠 문제를 풀며 경쟁
- **플랫폼**: Flutter (모바일)
- **인프라**: Supabase 무료티어 (실시간 동기화)
- **아키텍처**: Clean Architecture

---

## 🏗️ 기술 스택

| 항목 | 선택 | 이유 |
|------|------|------|
| 프레임워크 | Flutter | 크로스 플랫폼 |
| 백엔드 | Supabase 무료티어 | 무료, 실시간 지원, 가족 규모로 충분 |
| 상태 관리 | Riverpod | 실시간 스트림 처리에 적합 |
| 아키텍처 | Clean Architecture | 확장성, 유지보수 용이 |

### Supabase 무료티어 사용량 분석
- 1판당 약 33KB 저장, 200KB 대역폭
- 게임 종료 후 데이터 삭제 → 저장 공간 0MB 유지
- 가족 규모(월 60~90판) → 무료 한도의 10% 수준

---

## 👥 방 시스템

| 항목 | 내용 |
|------|------|
| 최대 인원 | 6명 |
| 입장 방식 | 6자리 코드 (추후 QR코드 추가 예정) |
| 방 상태 | `waiting` → `ready` → `playing` → `finished` |
| 준비 조건 | 방장 제외 모든 플레이어 준비 완료 시 방장 시작 버튼 활성화 |

### 방장 권한
- 게임 시작
- 각 유저별 초기 힌트 수 설정
- 아이템 종류 설정
- 오답 패널티 시간 설정
- 게임 일시정지

---

## 🎯 게임 규칙

### 승리 조건
- 동일한 스도쿠 문제를 **가장 빨리 완성**한 사람이 1등

### 게임 진행
- 1등 확정 시 → 나머지 플레이어 **1분 제한 시간** 시작
- 1분 내 미완료 시 → **진행 게이지(%) 높은 순**으로 등수 결정

### 오답 패널티
- 오답 입력 시 → **N초간 입력 잠금** (방장이 설정)

### 이탈 처리
| 상황 | 처리 |
|------|------|
| 백그라운드 진입 (전화 등) | 게임 그대로 진행 |
| 앱 완전 종료 | 자동 탈락 |
| 혼자 남은 경우 | 자동 승리 |

---

## 🧩 퍼즐 시스템

### 난이도 (1~10단계)

| 난이도 | 빈 칸 수 | 풀이 기법 |
|--------|----------|-----------|
| 1~3 | 30~35개 | 기본 (Naked Single) |
| 4~6 | 36~45개 | Hidden Single, Pointing Pairs |
| 7~9 | 46~52개 | X-Wing, Swordfish |
| 10 | 53개+ | 추측 포함 (Brute Force) |

### 퍼즐 생성 방식
- **Seed 기반 랜덤 생성**
- 방 생성 시 랜덤 seed 하나 생성 → 모든 참여자가 동일한 퍼즐 수신
- 매판 다른 문제 보장

---

## 🎁 아이템 시스템

### 획득 조건
- **10칸 채울 때마다** 아이템 1개 지급 (설정값으로 관리, 추후 변경 가능)
- 아이템 풀에서 **랜덤** 지급 (유저마다 다름 → 운 요소)

### 소지 슬롯
- **4칸** 고정
- 슬롯이 꽉 찬 상태에서 새 아이템 획득 시 → **자동 소멸** (기존 슬롯 유지)

### 사용 방법
1. 내 아이템 슬롯에서 아이템 탭
2. 대상 유저 탭 → 발동

### 아이템 종류

| 아이템 | 효과 | 대상 |
|--------|------|------|
| 💡 힌트 | 빈 칸 하나 정답 표시 | 나 |
| 🌫️ 블라인드 | 5초간 화면 흐릿하게 | 상대 |
| ✂️ 힌트 커트 | 상대 남은 힌트 -1 | 상대 |
| ⏸️ 프리즈 | 상대 입력 N초 불가 | 상대 |

### 힌트 사용 시 효과
- 사용한 유저의 이름이 **점프하거나 깜빡이는 애니메이션** 표시

---

## 📊 동기화 설계

### 실시간 공유 데이터
```
✅ 공유하는 것
├── 각 유저의 완료 퍼센티지 (게이지)
├── 아이템 사용 이벤트
├── 오답 패널티 이벤트
├── 게임 종료 (1등 확정)
└── 방장의 일시정지

❌ 공유하지 않는 것
└── 각자의 칸 입력 내용 (퍼센티지만 표시)
```

---

## 🗄️ DB 테이블 설계 (Supabase)

### rooms
```sql
rooms
├── id              UUID (PK)
├── code            VARCHAR(6)
├── host_id         UUID
├── status          ENUM ('waiting','ready','playing','finished')
├── max_players     INT
└── created_at      TIMESTAMP
```

### room_settings
```sql
room_settings
├── room_id         UUID (FK → rooms)
├── difficulty      INT (1~10)
├── penalty_seconds INT
├── item_interval   INT (기본 10)
├── allowed_items   JSONB
└── hint_counts     JSONB
```

### players
```sql
players
├── id              UUID (PK)
├── room_id         UUID (FK → rooms)
├── nickname        VARCHAR(20)
├── is_host         BOOLEAN
├── is_connected    BOOLEAN
└── joined_at       TIMESTAMP
```

### games
```sql
games
├── id              UUID (PK)
├── room_id         UUID (FK → rooms)
├── puzzle_seed     BIGINT
├── answer_grid     JSONB
├── status          ENUM ('playing','finished')
├── started_at      TIMESTAMP
├── first_clear_at  TIMESTAMP
└── finished_at     TIMESTAMP
```

### player_game_states
```sql
player_game_states
├── id              UUID (PK)
├── game_id         UUID (FK → games)
├── player_id       UUID (FK → players)
├── progress        INT
├── total_blanks    INT
├── hint_remaining  INT
├── rank            INT
├── is_penalized    BOOLEAN
├── finished_at     TIMESTAMP
└── item_slots      JSONB
```

### game_events
```sql
game_events
├── id              UUID (PK)
├── game_id         UUID (FK → games)
├── player_id       UUID (FK → players)
├── event_type      ENUM ('progress','item_used','penalty','clear')
├── payload         JSONB
└── created_at      TIMESTAMP
```

### 테이블 관계
```
rooms
  ├── room_settings  (1:1)
  ├── players        (1:N)
  └── games          (1:1)
        ├── player_game_states  (1:N)
        └── game_events         (1:N)
```

### 자동 삭제 전략
- 게임 종료 시 모든 관련 데이터 즉시 삭제
- DB 용량 0MB 유지

---

## 📁 Flutter 폴더 구조 (Clean Architecture)

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── supabase_constants.dart
│   ├── errors/
│   │   └── app_exception.dart
│   └── utils/
│       └── puzzle_generator.dart
│
├── data/
│   ├── models/
│   │   ├── room_model.dart
│   │   ├── player_model.dart
│   │   ├── game_model.dart
│   │   ├── player_game_state_model.dart
│   │   ├── game_event_model.dart
│   │   └── item_model.dart
│   └── repositories/
│       ├── room_repository.dart
│       ├── game_repository.dart
│       └── event_repository.dart
│
├── domain/
│   └── providers/
│       ├── room_provider.dart
│       ├── game_provider.dart
│       ├── player_provider.dart
│       └── realtime_provider.dart
│
└── presentation/
    ├── screens/
    │   ├── home_screen.dart
    │   ├── lobby_screen.dart
    │   ├── game_screen.dart
    │   └── result_screen.dart
    └── widgets/
        ├── sudoku/
        │   ├── sudoku_grid.dart
        │   ├── sudoku_cell.dart
        │   └── number_pad.dart
        ├── hud/
        │   ├── player_gauge.dart
        │   ├── item_slot.dart
        │   └── penalty_overlay.dart
        └── lobby/
            ├── player_card.dart
            └── settings_panel.dart
```

### 의존 방향
```
presentation → domain → data → core
```

---

## 🖥️ 화면 흐름

```
HomeScreen
  ├── 방 만들기 → LobbyScreen (방장)
  └── 코드 입장 → LobbyScreen (참여자)
        │
        ▼
LobbyScreen
  ├── 방장: 설정 패널 + 시작 버튼
  ├── 참여자: 준비 버튼
  └── 모두 준비 → 방장 시작 → GameScreen
        │
        ▼
GameScreen
  ├── 상단: 상대방 진행 게이지
  ├── 중앙: 스도쿠 9x9 그리드
  ├── 하단: 아이템 슬롯 4칸 + 숫자 키패드
  └── 1등 확정 → 1분 카운트다운
        │
        ▼
ResultScreen
  └── 최종 등수 표시 → 홈으로
```

### GameScreen 레이아웃
```
┌─────────────────────────┐
│  상대방 게이지 (상단)    │
│  [김철수 ████░░ 70%]   │
│  [이영희 ██░░░░ 40%]   │
├─────────────────────────┤
│                         │
│    스도쿠 9x9 그리드    │
│                         │
├─────────────────────────┤
│  아이템 슬롯            │
│  [💡][🌫️][✂️][  ]    │
├─────────────────────────┤
│  숫자 키패드            │
│  1  2  3  4  5          │
│  6  7  8  9  ←         │
└─────────────────────────┘
```

---

## 📦 주요 패키지

```yaml
dependencies:
  supabase_flutter: ^2.0.0
  flutter_riverpod: ^2.0.0
  gap: ^3.0.0
  animated_text_kit: ^4.0.0

  # 추후 추가
  # qr_flutter: ^4.0.0
```

---

## 🔜 코드 작성 순서

```
1단계. core/        → constants, 퍼즐 생성 알고리즘
2단계. data/        → models → repositories
3단계. domain/      → providers (Riverpod)
4단계. presentation/ → screens → widgets
```# online_sudoku
