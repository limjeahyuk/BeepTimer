//
//  TimerRunView.swift
//  BeepTimerWatch Watch App
//
//  선택한 타이머를 실행한다. 남은 시간을 큰 숫자로 표시한다.
//   · 탭        = 재생 / 일시정지
//   · 왼쪽 스와이프 = 다음 세트
//   · 오른쪽 스와이프 = 처음으로 되돌리기
//

import SwiftUI

struct TimerRunView: View {
    @ObservedObject private var sync = WatchConnectivityManager.shared
    @StateObject private var model: WatchTimerModel
    private let timer: SyncTimer
    private let title: String

    init(timer: SyncTimer, autoMode: EngineAutoMode) {
        self.timer = timer
        title = timer.title
        _model = StateObject(wrappedValue: WatchTimerModel(config: timer.toEngineConfig(),
                                                           autoMode: autoMode))
    }

    // 색은 고정 팔레트 — 모든 타이머 통일 (사용자 설정 없음)
    private var bgColor: Color { WatchPalette.bg }
    private var timeColor: Color { WatchPalette.time }
    private var restColor: Color { WatchPalette.rest }
    private var phaseColor: Color { model.isRest ? restColor : timeColor }
    /// 다음 페이즈의 몸체 색 — 운동 중엔 달(휴식), 휴식 중엔 해(운동)
    private var nextBodyColor: Color { model.isRest ? timeColor : restColor }
    /// 아이폰 전체 설정에서 고른 화면 스타일 — 해와 달 연출을 켤지 여부
    private var isSunMoon: Bool { sync.screenStyle == .sunMoon }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            // 화면보다 큰 원반의 위쪽 호가 화면 아래에 붙는 큰 돔(지평선 위의 해/달)을 만든다.
            let arcDiameter = side * 1.34
            let arcDrop = side * 0.52       // 돔 자리 — 페이즈 시작 시 몸체가 놓이는 위치
            let sunkDrop = side * 1.25      // 지평선 아래로 완전히 사라지는 오프셋
            let skyDrop = -side * 1.25      // 화면 위 하늘 바깥 — 다음 몸체의 시작 위치
            let elapsed = 1 - model.progress // 경과 비율 (0 → 1)
            // 심플 스타일에서는 원반이 없으므로 halo·오프셋도 끈다
            let halo = isSunMoon ? side * 0.02 : 0
            let smallHalo = isSunMoon ? side * 0.015 : 0
            let contentDrop = isSunMoon ? -side * 0.05 : 0

            ZStack {
                bgColor

                // 해·달 궤도 — 해가 지고 달이 뜨듯, 현재 페이즈의 몸체(운동=해, 휴식=달)가
                // 진행에 따라 지평선(화면 아래) 밑으로 지고, 다음 페이즈의 몸체가 하늘에서
                // 내려와 페이즈가 끝나는 순간 돔 자리에 안착한다. 페이즈가 바뀌면 방금 안착한
                // 몸체가 "현재"가 되어 그 자리에서 다시 지기 시작한다.
                // (심플 스타일에서는 연출 없이 숫자만 보여준다)
                if isSunMoon {
                    Group {
                        // 지는 몸체 — 현재 페이즈. 꽉 찬 원반이라 실제 해/달처럼 보인다.
                        Circle()
                            .fill(phaseColor)
                            .offset(y: arcDrop + (sunkDrop - arcDrop) * elapsed)

                        // 내려오는 몸체 — 다음 페이즈 (도착하는 쪽이 앞에 그려진다)
                        Circle()
                            .fill(nextBodyColor)
                            .offset(y: skyDrop + (arcDrop - skyDrop) * elapsed)
                    }
                    .frame(width: arcDiameter, height: arcDiameter)
                    .animation(.linear(duration: 0.1), value: model.progress)
                    // 페이즈가 바뀌면 뷰를 새로 만들어, 역할이 뒤바뀐 원반이 화면을 가로질러
                    // 날아가는(푸슉) 전환 애니메이션을 차단한다.
                    .id("\(model.setIndex)-\(model.isRest)-\(model.phaseLabel)")
                }

                VStack(spacing: side * 0.02) {
                    // 단계 이름을 항상 표시 — 커스텀은 단계 제목, 단순 타이머는 Time/Rest.
                    // 라벨 행을 두 타입 모두 유지해 아래 숫자의 위치·크기를 동일하게 맞춘다.
                    Text(model.phaseLabel)
                        .font(.system(size: side * 0.12, weight: .bold))
                        .foregroundStyle(WatchPalette.label)   // 숫자와 다른 색으로 구분
                        .shadow(color: bgColor, radius: smallHalo)  // 원반이 지나가도 읽히게 —
                        .shadow(color: bgColor, radius: smallHalo)  // 겹층 halo로 윤곽선 효과
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    // 남은 시간 — 해와 달 스타일에서는 흰색 고정에 검정 halo 세 겹을 쌓아
                    // 밝은 원반이 뒤를 지나가도 항상 읽히게 한다. (구분은 원반·스탯 색이 담당)
                    // 심플 스타일에서는 원반이 없으므로 페이즈 색을 그대로 숫자에 쓴다.
                    Text(timeString(model.remaining))
                        .font(.system(size: side * 0.4, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isSunMoon ? WatchPalette.number : phaseColor)
                        .shadow(color: bgColor, radius: halo)
                        .shadow(color: bgColor, radius: halo)
                        .shadow(color: bgColor, radius: halo)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)

                    // 타이머 시간 · 세트 수 · 휴식 시간 (시간/휴식은 색으로만 구분, 라벨 없음)
                    HStack(spacing: side * 0.07) {
                        if !timer.isCustom {
                            Text(shortDuration(timer.timeSec))
                                .foregroundStyle(timeColor)
                        }
                        Text(setText)
                            .foregroundStyle(.secondary)
                        if !timer.isCustom {
                            // 휴식이 0이라도 항상 표시 — 시간/휴식 자리를 일관되게 유지
                            Text(shortDuration(timer.restSec))
                                .foregroundStyle(restColor)
                        }
                    }
                    .font(.system(size: side * 0.1, weight: .semibold))
                    .monospacedDigit()
                    .shadow(color: bgColor, radius: smallHalo)  // 원반이 지나가도 읽히게 —
                    .shadow(color: bgColor, radius: smallHalo)  // 겹층 halo로 윤곽선 효과
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, side * 0.11)
                .offset(y: contentDrop)   // 해와 달에서는 숫자를 살짝 위로 올려 돔 안에 앉힌다
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()   // 궤도를 도는 원이 화면 밖으로 그려지지 않게
            .contentShape(Rectangle())
            .onTapGesture { model.toggle() }
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < 0 {
                            model.next()          // ← 왼쪽: 다음
                        } else {
                            model.stopAndReset()  // → 오른쪽: 처음으로
                        }
                    }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.teardown() }
    }

    private var setText: String {
        if model.isInfinite { return "\(model.setIndex)/∞" }
        return "\(model.setIndex)/\(model.totalSets)"
    }
}

/// 짧은 길이 표기 — 60초 미만은 "30s", 이상은 "m:ss" (작은 화면용)
func shortDuration(_ seconds: Int) -> String {
    let v = max(0, seconds)
    if v >= 60 { return String(format: "%d:%02d", v / 60, v % 60) }
    return "\(v)s"
}

/// mm:ss (1시간 이상이면 h:mm:ss)
func timeString(_ total: Int) -> String {
    let s = max(0, total)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%02d:%02d", s / 60, s % 60)
}
