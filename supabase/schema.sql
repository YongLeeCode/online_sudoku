-- OnlineSudoku DB Schema
-- Supabase SQL Editor에서 실행하세요

-- 1. rooms 테이블
create table rooms (
  id uuid primary key default gen_random_uuid(),
  code varchar(6) not null unique,
  host_id uuid not null,
  status varchar(20) not null default 'waiting'
    check (status in ('waiting', 'ready', 'playing', 'finished')),
  max_players int not null default 6,
  created_at timestamptz not null default now()
);

-- 2. room_settings 테이블
create table room_settings (
  room_id uuid primary key references rooms(id) on delete cascade,
  -- 난이도 5단계: 1=VeryEasy, 2=Easy, 3=Normal, 4=Hard, 5=Extreme
  difficulty int not null default 3 check (difficulty between 1 and 5),
  penalty_seconds int not null default 5,
  item_interval int not null default 10,
  allowed_items jsonb not null default '["hint","blind","hint_cut","freeze"]'::jsonb,
  hint_counts jsonb not null default '{}'::jsonb
);

-- 3. players 테이블
create table players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  nickname varchar(20) not null,
  is_host boolean not null default false,
  is_ready boolean not null default false,
  is_connected boolean not null default true,
  joined_at timestamptz not null default now()
);

-- 4. games 테이블
create table games (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  puzzle_seed bigint not null,
  answer_grid jsonb not null,
  status varchar(20) not null default 'playing'
    check (status in ('playing', 'finished')),
  started_at timestamptz not null default now(),
  first_clear_at timestamptz,
  finished_at timestamptz
);

-- 5. player_game_states 테이블
create table player_game_states (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  progress int not null default 0,
  total_blanks int not null,
  hint_remaining int not null default 3,
  rank int,
  is_penalized boolean not null default false,
  finished_at timestamptz,
  item_slots jsonb not null default '[]'::jsonb
);

-- 6. game_events 테이블
create table game_events (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  event_type varchar(20) not null
    check (event_type in ('progress', 'item_used', 'penalty', 'clear')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- 인덱스
create index idx_rooms_code on rooms(code);
create index idx_players_room_id on players(room_id);
create index idx_games_room_id on games(room_id);
create index idx_player_game_states_game_id on player_game_states(game_id);
create index idx_game_events_game_id on game_events(game_id);

-- RLS (Row Level Security) 활성화
alter table rooms enable row level security;
alter table room_settings enable row level security;
alter table players enable row level security;
alter table games enable row level security;
alter table player_game_states enable row level security;
alter table game_events enable row level security;

-- 모든 테이블에 anon 접근 허용 (가족용 게임이라 인증 없이 사용)
create policy "Allow all access" on rooms for all using (true) with check (true);
create policy "Allow all access" on room_settings for all using (true) with check (true);
create policy "Allow all access" on players for all using (true) with check (true);
create policy "Allow all access" on games for all using (true) with check (true);
create policy "Allow all access" on player_game_states for all using (true) with check (true);
create policy "Allow all access" on game_events for all using (true) with check (true);

-- Realtime 활성화
alter publication supabase_realtime add table rooms;
alter publication supabase_realtime add table players;
alter publication supabase_realtime add table player_game_states;
alter publication supabase_realtime add table game_events;
