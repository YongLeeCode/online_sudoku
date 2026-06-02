# 배포 가이드 (online_sudoku)

세 가지 경로로 플레이할 수 있게 하는 방법을 정리합니다.
모든 빌드는 Supabase 자격증명을 `--dart-define`으로 주입해야 합니다 (값은 `.env`에 있음).

> 공통 사전값: `SUPABASE_URL`, `SUPABASE_ANON_KEY` — `.env`에 저장돼 있고 git에는 올라가지 않습니다.
> anon 키는 클라이언트에 포함되는 게 정상입니다(공개용 키). 실제 보안은 Supabase **RLS 정책**으로 합니다.

---

## 경로 1 — Android APK (사이드로딩) ✅ 완료

릴리스 서명키(`/Users/yong/sudoku-release.jks`, alias `sudoku`)로 서명된 APK가 빌드됨.

- 산출물: `build/app/outputs/flutter-apk/app-release.apk` (54MB, 유니버설)
- 보내기 편한 복사본: `~/Desktop/online_sudoku-v1.0.0.apk`

### 친구에게 설치시키는 법
1. APK 파일을 카카오톡/구글드라이브/링크 등으로 전송.
2. 친구는 안드로이드에서 그 파일을 열고 **"출처를 알 수 없는 앱 설치 허용"**을 켠 뒤 설치.
   (설정 → 앱 → 특수 액세스 → 알 수 없는 앱 설치 → 사용한 앱(파일/메신저) 허용)
3. 설치 후 바로 실행.

### 다시 빌드할 때
```bash
set -a; source .env; set +a
flutter build apk --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
# 용량을 줄이려면 ABI별 분할(여러 파일 생성):
#   flutter build apk --release --split-per-abi --dart-define=...
```

> ⚠️ 서명키 백업: `/Users/yong/sudoku-release.jks` 와 비밀번호(`android/key.properties`)를
> 안전한 곳(비밀번호 매니저)에 백업하세요. 플레이스토어에 한 번 올리면 **이 키를 영구히 써야** 하며 분실 시 앱 업데이트가 불가합니다.
> 아직 플레이스토어 전이므로 지금은 키를 새로 만들어도 무방합니다.

---

## 경로 2 — iOS (Xcode로 빌드해 친구에게 보내기) ⚠️ 추가 설정 필요

### ❗ 현재 이 맥의 제약
- **Xcode 정식 버전이 설치돼 있지 않습니다** (Command Line Tools만 존재).
- CocoaPods(`pod`)도 미설치.
- 따라서 **지금 이 기기에서는 iOS 빌드 자체가 불가능**합니다. 아래 준비가 끝나야 합니다.

### 1) 사전 설치 (한 번만)
```bash
# 1. Mac App Store에서 Xcode 정식 버전 설치 (약 7GB+)
# 2. 커맨드라인 도구를 Xcode로 전환
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
# 3. CocoaPods 설치
brew install cocoapods   # 또는: sudo gem install cocoapods
# 4. iOS 의존성 설치
cd ios && pod install && cd ..
```

### 2) "친구에게 보내기"는 Apple 계정 종류에 따라 갈립니다

| 방법 | 필요 조건 | 친구 수 | 만료 | 전송 방식 |
|---|---|---|---|---|
| **TestFlight** (권장) | 유료 Apple Developer Program ($99/년) | 최대 10,000 | 90일 | **링크/이메일 초대** (원격 OK) |
| Ad-hoc IPA | 유료 계정 + 친구 기기 UDID 등록 | 최대 100 | 1년 | IPA 파일 전달 |
| 무료 Apple ID | 무료 계정 | 본인 기기만 | **7일** | USB 직접 연결 필요 (원격 ❌) |

> 👉 "친구들에게 보내기"를 제대로 하려면 사실상 **유료 개발자 계정 + TestFlight**가 필요합니다.
> 무료 계정은 친구 폰을 직접 USB로 연결해야 하고 7일마다 재설치해야 합니다.

### 3-A) 유료 계정 → TestFlight 배포
가장 안정적인 방법은 Xcode GUI:
```bash
open ios/Runner.xcworkspace
```
1. 좌측 Runner 타깃 → **Signing & Capabilities** → Team에 본인 개발자 계정 선택.
2. Supabase 값 주입이 필요하므로 **CLI로 아카이브**하는 게 안전합니다 (릴리스에선 assert가 제거돼 빈 값이면 런타임 오류):
   ```bash
   set -a; source .env; set +a
   flutter build ipa --release \
     --dart-define=SUPABASE_URL=$SUPABASE_URL \
     --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
   ```
   → `build/ios/ipa/online_sudoku.ipa` 생성 (서명은 Xcode 자동 서명/팀 설정에 따름).
3. 업로드: **Transporter 앱**(App Store에서 무료)에 IPA를 드래그하거나, `xcrun altool`/`notarytool` 사용.
4. App Store Connect → TestFlight → 빌드 처리 후 친구를 **테스터로 초대**(이메일) 또는 **공개 링크** 생성.

### 3-B) 무료 계정 → 본인/친구 기기 USB 직접 설치
```bash
set -a; source .env; set +a
flutter devices                    # 연결된 기기 확인
flutter run --release -d <기기ID> \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```
- 처음엔 기기에서 **설정 → 일반 → VPN 및 기기 관리**에서 개발자 프로파일을 신뢰해야 함.
- 7일 후 앱이 만료되므로 재설치 필요.

---

## 경로 3 — 웹사이트 ✅ 빌드 완료 / 배포 1단계 남음

- 산출물: `build/web` (36MB, CanvasKit). 로컬/Firebase/Netlify에 바로 사용 가능.

### 로컬에서 먼저 확인
```bash
cd build/web && python3 -m http.server 8000
# 브라우저에서 http://localhost:8000 접속
```
(`flutter run -d chrome --dart-define=...` 로도 실행 가능)

### 기본 배포: GitHub Pages (자동) — `.github/workflows/deploy-web.yml` 준비됨
저장소: `YongLeeCode/online_sudoku` → 배포 URL: **https://yongleecode.github.io/online_sudoku/**

설정(한 번만):
1. GitHub 저장소 **Settings → Pages → Source: "GitHub Actions"** 선택.
2. **Settings → Secrets and variables → Actions → New repository secret** 로 2개 추가:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. 워크플로 파일 커밋 & 푸시:
   ```bash
   git add .github/workflows/deploy-web.yml
   git commit -m "ci: GitHub Pages 웹 자동 배포"
   git push
   ```
   → push 시 자동 빌드·배포. Actions 탭에서 진행 확인.

> Supabase 대시보드 → Authentication → URL Configuration 에서
> `https://yongleecode.github.io` 를 **허용 도메인**에 추가해야 인증/리다이렉트가 정상 동작합니다.

### 대안 호스팅
- **Firebase Hosting** (커스텀 도메인 쉬움):
  ```bash
  npm i -g firebase-tools && firebase login
  firebase init hosting    # public 폴더로 build/web 지정, SPA(rewrite) 예
  flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
  firebase deploy
  ```
- **Netlify / Vercel**: `build/web` 폴더를 드래그&드롭하거나 CLI로 배포. base-href는 `/` 그대로 OK.

> GitHub Pages는 하위경로(`/online_sudoku/`)라 base-href가 `/online_sudoku/`여야 합니다(워크플로가 처리).
> Firebase/Netlify/Vercel은 루트 도메인이라 base-href `/`(현재 빌드) 그대로 쓰면 됩니다.
