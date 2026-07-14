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

    // 색은 아이폰 전체 설정에서 받은 워치 공통 색상 — 모든 타이머 통일
    private var bgColor: Color { Color(hex: sync.colors.bgHex) }
    private var timeColor: Color { Color(hex: sync.colors.timeHex) }
    private var restColor: Color { Color(hex: sync.colors.restHex) }
    private var phaseColor: Color { model.isRest ? restColor : timeColor }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            VStack(spacing: side * 0.02) {
                // 상세(커스텀) 타이머만 단계 이름 표시 — 단순 타이머는 색으로 구분
                if timer.isCustom {
                    Text(model.phaseLabel)
                        .font(.system(size: side * 0.12, weight: .bold))
                        .foregroundStyle(phaseColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                // 남은 시간 — 현재 페이즈 색으로(운동/휴식을 색으로만 구분)
                Text(timeString(model.remaining))
                    .font(.system(size: side * 0.42, weight: .bold, design: .rounded))
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
                    if !timer.isCustom, timer.restSec > 0 {
                        Text(shortDuration(timer.restSec))
                            .foregroundStyle(restColor)
                    }
                }
                .font(.system(size: side * 0.1, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, side * 0.04)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(bgColor)
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
