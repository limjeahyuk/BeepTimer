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
    @StateObject private var model: WatchTimerModel
    private let title: String
    private let timeColor: Color
    private let restColor: Color

    init(timer: SyncTimer, autoMode: EngineAutoMode) {
        title = timer.title
        timeColor = Color(hex: timer.timeColorHex)
        restColor = Color(hex: timer.restColorHex)
        _model = StateObject(wrappedValue: WatchTimerModel(config: timer.toEngineConfig(),
                                                           autoMode: autoMode))
    }

    private var phaseColor: Color { model.isRest ? restColor : timeColor }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            VStack(spacing: side * 0.02) {
                Text(model.phaseLabel)
                    .font(.system(size: side * 0.13, weight: .bold))
                    .foregroundStyle(phaseColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(timeString(model.remaining))
                    .font(.system(size: side * 0.42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                HStack(spacing: side * 0.05) {
                    Text(setText)
                        .font(.system(size: side * 0.1))
                        .foregroundStyle(.secondary)

                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: side * 0.1, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, side * 0.04)
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.teardown() }
    }

    private var setText: String {
        if model.isInfinite { return "\(model.setIndex)/∞" }
        return "\(model.setIndex)/\(model.totalSets)"
    }
}

/// mm:ss (1시간 이상이면 h:mm:ss)
func timeString(_ total: Int) -> String {
    let s = max(0, total)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%02d:%02d", s / 60, s % 60)
}
