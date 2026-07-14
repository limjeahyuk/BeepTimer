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

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ringWidth = side * 0.05
            let ringInset = side * 0.04
            // 반원을 아래로 내려 평평한 양 끝이 숫자 아래(스탯 행 위)에 맞닿게 한다 — 숫자를 감싸는 돔 형태.
            let ringDrop = side * 0.16

            ZStack {
                bgColor

                // 진행 반원 링 — 숫자를 감싸는 위쪽 반원. 남은 시간이 줄면 반원도 함께 줄어든다.
                // Circle 경로에서 위쪽 반원 구간은 0.5(9시)~1.0(3시)이다.
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .padding(ringInset)
                    .offset(y: ringDrop)
                Circle()
                    .trim(from: 0.5, to: 0.5 + 0.5 * model.progress)
                    .stroke(phaseColor,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .padding(ringInset)
                    .offset(y: ringDrop)
                    .animation(.linear(duration: 0.1), value: model.progress)

                VStack(spacing: side * 0.02) {
                    // 단계 이름을 항상 표시 — 커스텀은 단계 제목, 단순 타이머는 Time/Rest.
                    // 라벨 행을 두 타입 모두 유지해 아래 숫자의 위치·크기를 동일하게 맞춘다.
                    Text(model.phaseLabel)
                        .font(.system(size: side * 0.12, weight: .bold))
                        .foregroundStyle(WatchPalette.label)   // 숫자와 다른 색으로 구분
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    // 남은 시간 — 현재 페이즈 색으로(운동/휴식을 색으로만 구분)
                    Text(timeString(model.remaining))
                        .font(.system(size: side * 0.4, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(phaseColor)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, side * 0.11)
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
