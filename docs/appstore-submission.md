# BeepTimer App Store 제출 체크리스트

첫 제출(v1.0) 기준. 완료한 항목은 `[x]`로 바꿔가며 쓴다.

## 1. 코드/프로젝트 — 완료됨

| 항목 | 상태 |
|---|---|
| 개인정보 매니페스트 (`PrivacyInfo.xcprivacy`) | 앱·위젯 both. UserDefaults / 사유 `CA92.1` |
| 배포 타깃 | 앱·위젯 모두 iOS 17.6 (워치 10.0) |
| Development Team | 전 타깃 `8WW9CMZ6D2` |
| 워치 앱 표시 이름 | `BeepTimer` |
| 워치 백그라운드 | HealthKit `HKWorkoutSession` + `WKBackgroundModes: workout-processing` |
| 수출 규정 | `ITSAppUsesNonExemptEncryption = 0` (앱·워치) |
| 인앱 웹뷰 | 제거됨 → 연령 등급 4+ 가능 |

### 번들 구성

| 타깃 | Bundle ID | 필요 Capability |
|---|---|---|
| iOS 앱 | `com.LimJH.BeepTimer` | App Groups |
| 워치 앱 | `com.LimJH.BeepTimer.watchkitapp` | **HealthKit** |
| 위젯 | `com.LimJH.BeepTimer.BeepTimerWidget` | App Groups |

App Group: `group.com.LimJH.BeepTimer`

## 2. Apple Developer 포털 — 완료됨

- [x] Apple Developer Program 가입 (팀 `8WW9CMZ6D2`)
- [x] App ID 3개 등록
- [x] **워치 App ID에 HealthKit 활성화** — `-allowProvisioningUpdates`로 자동 등록됨
- [x] App Group `group.com.LimJH.BeepTimer`
- [x] Apple Distribution 인증서 (만료 2027-07-22)

포털에서 더 할 일은 없다.

## 3. App Store Connect — 웹에서 할 일

빌드 업로드 전에 미리 해둘 수 있다. 순서대로 진행한다.

### 3-0. 선행 조건 — 개인정보 처리방침 URL

**이게 없으면 심사 제출 자체가 막힌다.** 데이터를 전혀 수집하지 않아도 URL은 필수다.
GitHub Pages, Notion 공개 페이지 등 접근 가능한 URL이면 된다.

넣을 내용 (그대로 써도 됨):

```
BeepTimer 개인정보 처리방침

BeepTimer는 사용자의 개인정보를 수집하지 않습니다.

- 타이머 설정, 메모, 사진 등 앱에서 만든 모든 데이터는 사용자의 기기 안에만
  저장되며 외부 서버로 전송되지 않습니다.
- 앱은 광고 식별자나 분석 도구를 사용하지 않으며, 사용자를 추적하지 않습니다.
- Apple Watch에서 타이머를 백그라운드로 유지하기 위해 건강(HealthKit) 운동
  세션을 사용합니다. 이 데이터는 사용자의 기기와 Apple 건강 앱에만 저장되며
  개발자가 접근하거나 수집하지 않습니다.
- 앱을 삭제하면 모든 데이터가 함께 삭제됩니다.

문의: <연락 가능한 이메일>
```

- [ ] 개인정보 처리방침 URL 준비
- [ ] 지원 URL (같은 페이지 재사용 가능)

### 3-1. 새 앱 만들기

My Apps › `+` › New App

| 항목 | 값 |
|---|---|
| 플랫폼 | iOS |
| 이름 | `BeepTimer` (중복 시 `BeepTimer - 인터벌 타이머` 등) |
| 기본 언어 | 한국어 |
| 번들 ID | `com.LimJH.BeepTimer` |
| SKU | `beeptimer-001` (외부 비공개, 아무 문자열) |
| 사용자 액세스 | 전체 액세스 |

### 3-2. 앱 정보

- [ ] 카테고리: 기본 **건강 및 피트니스** / 보조 **생산성**
- [ ] 연령 등급 설문 → **모두 "없음"**, 특히 **제한 없는 웹 접근: 아니요** → **4+**

> 인앱 웹뷰를 제거했기 때문에 4+가 가능하다. 웹뷰가 있었다면 17+로 강제됐다.

### 3-3. App Privacy

- [ ] **Data Not Collected** 선택

네트워크 코드, 분석 SDK, 광고 식별자가 전혀 없다. HealthKit 데이터도 기기에만
저장되고 외부로 전송하지 않으므로 수집으로 신고하지 않는다.

### 3-4. 스크린샷 업로드

**iPhone 6.9"만 올리면 된다.** Apple이 작은 기기용으로 자동 축소해준다.
(6.5"는 6.9"를 안 올릴 때만 필수 → 우리는 불필요)

| 순서 | 파일 | 화면 |
|---|---|---|
| 1 | `07_running_late.png` | 타이머 실행 중 |
| 2 | `02_library.png` | 타이머 목록 |
| 3 | `03_appsettings.png` | 전체 설정 |
| 4 | `04_settings.png` | 타이머 설정 |

- [ ] iPhone 6.9" (1320 × 2868) — 위 4장
- [ ] **Apple Watch** (416 × 496) — `w02_run.png`, `w01_list.png` (워치 앱 포함이라 필수)
- [ ] iPad — 미지원이면 불필요

### 3-5. 버전 정보

- [ ] 프로모션 텍스트 (선택)
- [ ] 설명 / 키워드 / 지원 URL → 아래 4번 문구 사용
- [ ] 이 버전의 새로운 기능: 첫 버전이면 비워두거나 "첫 출시"

## 4. 스토어 문구 초안

**부제 (30자)**

```
인터벌 운동 타이머 · 애플워치 지원
```

**설명**

```
BeepTimer는 운동과 휴식을 반복하는 인터벌 트레이닝을 위한 타이머입니다.

• 운동/휴식 시간과 세트 수를 자유롭게 설정
• 단계별로 이름과 시간을 정하는 상세 타이머
• 구간이 끝나기 3초 전 카운트다운 비프음과 진동
• 잠금 화면 실시간 액티비티와 홈 화면 위젯
• Apple Watch 앱 — 손목에서 바로 실행하고 진동으로 알림
• 아이폰에서 타이머가 울리면 워치에도 함께 진동

모든 데이터는 기기 안에만 저장되며 서버로 전송되지 않습니다.
```

**키워드 (100자, 쉼표 구분)**

```
인터벌,타이머,운동,홈트,타바타,HIIT,스톱워치,세트,휴식,워치,루틴,헬스
```

## 5. 제출 절차 — Xcode에서

아카이브는 이미 만들어져 있다 (Release, v1.0 빌드 1, Apple Distribution 서명 확인됨).
Xcode Organizer만 쓰면 되고 Transporter 같은 별도 앱은 필요 없다.

1. [x] Product › Archive
2. [ ] Window › Organizer › Archives에서 아카이브 선택
3. [ ] **Validate App** — 통과 확인
4. [ ] **Distribute App** → App Store Connect 업로드
5. [ ] TestFlight 실기기 테스트 (아래 항목은 시뮬레이터로 검증 불가)
   - [ ] 폰↔워치 WatchConnectivity 동기화
   - [ ] 백그라운드 페이즈 알림
   - [ ] **HealthKit 권한 팝업 및 운동 세션** — 손목 내린 채 햅틱이 이어지는지
   - [ ] Live Activity / 위젯
6. [ ] 심사 제출

## 6. 심사 대비 메모

- **운동 백그라운드 모드 문의 시**: "인터벌 운동 타이머로, 백그라운드에서 구간 전환
  시점을 진동으로 알리기 위해 HealthKit 운동 세션을 사용합니다."
- 알려진 제약: 워치 확장 런타임 대신 운동 세션을 쓰므로, 사용자가 건강 권한을
  거부하면 백그라운드 지속이 동작하지 않는다 (포그라운드는 정상).
