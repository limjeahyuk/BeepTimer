//
//  TimerRunView.swift
//  BeepTimerWatch Watch App
//
//  원(링) 하나로 선택한 타이머를 실행한다.
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
            let ring = max(9, side * 0.075)
            // 링 두께의 절반이 화면 밖으로 나가 잘리지 않게 + 바깥 여백을 위해 지름을 줄인다
            let diameter = side - ring - side * 0.12

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: ring)

                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: ring, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: model.progress)

                VStack(spacing: side * 0.01) {
                    Text(model.phaseLabel)
                        .font(.system(size: side * 0.11, weight: .bold))
                        .foregroundStyle(phaseColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(timeString(model.remaining))
                        .font(.system(size: side * 0.26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(setText)
                        .font(.system(size: side * 0.085))
                        .foregroundStyle(.secondary)

                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: side * 0.11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, side * 0.015)
                }
                .padding(.horizontal, ring + side * 0.04)
            }
            .frame(width: diameter, height: diameter)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .contentShape(Circle())
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
        .ignoresSafeArea()
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
