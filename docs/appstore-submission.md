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

## 2. Apple Developer 포털

- [ ] Apple Developer Program 가입 (연 $99)
- [ ] Identifiers에서 위 3개 App ID 확인
- [ ] **워치 App ID에 HealthKit 활성화** ← 이번에 추가된 항목
- [ ] App Group `group.com.LimJH.BeepTimer` 등록 확인

> Xcode 자동 서명이 대부분 처리하지만, HealthKit은 아카이브 전에 워치 타깃
> Signing & Capabilities에 실제로 표시되는지 눈으로 확인할 것.

## 3. App Store Connect

### 앱 정보
- [ ] 앱 이름: `BeepTimer` (이름 중복 시 대체안 준비)
- [ ] 기본 언어: 한국어
- [ ] 카테고리: 건강 및 피트니스 (기본) / 생산성 (보조)
- [ ] SKU: 임의 문자열 (예: `beeptimer-001`)

### 연령 등급
- [ ] 제한 없는 웹 접근: **아니요** → **4+**

### App Privacy
- [ ] **Data Not Collected**

앱에 네트워크 코드, 분석 SDK, 광고 식별자가 전혀 없다.
HealthKit 데이터는 기기 안에만 저장되고 외부로 전송하지 않으므로 수집으로 신고하지 않는다.

- [ ] 개인정보 처리방침 URL (데이터를 안 모아도 URL 자체는 필수)
- [ ] 지원 URL

### 스크린샷
- [ ] iPhone 6.9" (iPhone 16 Pro Max, 1320 × 2868)
- [ ] **Apple Watch** — 워치 앱이 포함되어 필수
- [ ] iPad — 미지원이면 불필요

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

## 5. 제출 절차

1. [ ] 빌드 타깃을 **Any iOS Device**로 변경
2. [ ] Product › Archive
3. [ ] Organizer에서 **Validate App**
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
