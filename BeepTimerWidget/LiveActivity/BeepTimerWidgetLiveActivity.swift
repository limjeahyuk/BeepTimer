//
//  BeepTimerWidgetLiveActivity.swift
//  BeepTimerWidget
//
//  Created by 임재혁 on 11/13/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

enum TimerPhaseMode: String, Codable { case time; case rest }
enum TimerPhaseStatus: String, Codable { case running; case paused; case done}

// MARK: - 공용 헬퍼

/// 초 → "mm:ss" (일시정지 시 고정 표시용)
private func mmss(_ total: Int) -> String {
    let s = max(0, total)
    return String(format: "%02d:%02d", s / 60, s % 60)
}

private func modeAndStatus(
    from state: BeepTimerWidgetAttributes.ContentState
) -> (TimerPhaseMode, TimerPhaseStatus) {
    let mode: TimerPhaseMode = (state.phase == "rest") ? .rest : .time
    let status: TimerPhaseStatus
    switch state.status {
    case "running": status = .running
    case "done":    status = .done
    default:        status = .paused
    }
    return (mode, status)
}

/// 다이나믹 아일랜드/잠금화면 페이즈 색 — 앱의 링 색과 통일.
/// 타이머마다 지정한 색(ContentState의 hex)을 사용한다.
struct PhaseTint {
    let time: Color
    let rest: Color

    init(_ state: BeepTimerWidgetAttributes.ContentState) {
        time = Color(hex: state.timeColorHex)
        rest = Color(hex: state.restColorHex)
    }

    func color(for mode: TimerPhaseMode) -> Color { mode == .time ? time : rest }
}

struct TimerPhaseRingIcon: View {
    let mode: TimerPhaseMode      // .time / .rest
    let status: TimerPhaseStatus  // .running / .paused / .done
    let isAllDone: Bool
    let tint: PhaseTint
    /// 남은 시간 5초 이하 — 링을 빨간색으로
    var endingSoon: Bool = false


    var body: some View {
        ZStack {
            IconImage
                .font(.system(size: 12, weight: .bold))

            Circle()
                .strokeBorder(lineWidth: 2)
                .foregroundColor(status == .done ? doneColor : ringColor)

        }
        .frame(width: 25, height: 25)
        .foregroundColor(.white)
    }

    private var ringColor: Color {
        (status == .running && endingSoon) ? .red : tint.color(for: mode)
    }

    // done 되자마자 mode가 변경되어버려서 다음 링 색상이 되어버립니다.
    private var doneColor: Color {
        if isAllDone {
            return .red
        }else {
            switch mode {
            case .time: return tint.color(for: .rest)
            case .rest: return tint.color(for: .time)
            }
        }
    }

    @ViewBuilder
    private var IconImage: some View {
        switch status {
        case .paused:
            Image(systemName: "pause.fill")
        case .running:
            switch mode {
            case .time:
                Image(systemName: "figure.run")
            case .rest:
                Image(systemName: "figure.mind.and.body")
            }
        case .done:
            Image(systemName: "checkmark")
        }
    }
}

// MARK: - minimal(작은 원) 뷰

/// minimal 상태(다른 앱과 아일랜드를 나눠 쓰는 작은 원).
/// 뷰가 스스로 T-5초에 다시 그릴 수는 없지만, 앱이 T-5초에 endingSoon=true로
/// 상태 업데이트를 보내주므로 실행 중엔 페이즈 색 → 마지막 5초에 빨간 링으로 바뀐다.
private struct MinimalIslandView: View {
    let mode: TimerPhaseMode
    let status: TimerPhaseStatus
    let endingSoon: Bool
    let tint: PhaseTint

    var body: some View {
        ZStack {
            iconImage
                .font(.system(size: 12, weight: .bold))

            Circle()
                .strokeBorder(lineWidth: 2)
                .foregroundColor(ringColor)
        }
        .frame(width: 25, height: 25)
        .foregroundColor(.white)
    }

    private var ringColor: Color {
        switch status {
        case .running: return endingSoon ? .red : tint.color(for: mode)
        case .paused:  return tint.color(for: mode)
        case .done:    return .red
        }
    }

    @ViewBuilder
    private var iconImage: some View {
        switch status {
        case .paused:
            Image(systemName: "pause.fill")
        case .running:
            Image(systemName: mode == .time ? "figure.run" : "figure.mind.and.body")
        case .done:
            Image(systemName: "stop.fill")
        }
    }
}

// MARK: - 남은 시간 / 상태 텍스트

/// running이면 카운트다운(.timer), paused면 고정된 남은 시간, done이면 "완료"
private struct TimerCountdownText: View {
    let state: BeepTimerWidgetAttributes.ContentState
    let status: TimerPhaseStatus
    var tint: Color = .primary

    var body: some View {
        switch status {
        case .running:
            // style: .timer는 endTime이 지나면 카운트업으로 바뀌므로,
            // timerInterval + countsDown으로 00:00에서 멈추게 한다.
            Text(timerInterval: min(state.startTime, state.endTime)...state.endTime,
                 countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.leading)
                .foregroundColor(tint)
        case .paused:
            Text(mmss(state.remainSec ?? 0))
                .monospacedDigit()
                .foregroundColor(.secondary)
        case .done:
            Text("완료")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - compact leading (다이나믹 아일랜드 왼쪽 원)

/// running이면 남은 시간에 따라 줄어드는 원형 프로그레스 링(운동=파랑, 휴식=초록),
/// 그 외에는 기존 아이콘 링을 보여준다.
private struct CompactPhaseRing: View {
    let state: BeepTimerWidgetAttributes.ContentState
    let mode: TimerPhaseMode
    let status: TimerPhaseStatus
    let isAllDone: Bool
    let tint: PhaseTint

    var body: some View {
        if status == .running, state.endTime > Date() {
            ProgressView(
                timerInterval: min(state.startTime, state.endTime)...state.endTime,
                countsDown: true
            ) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: mode == .time ? "figure.run" : "figure.mind.and.body")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            .progressViewStyle(.circular)
            .tint(state.endingSoon ? .red : tint.color(for: mode))
            .frame(width: 25, height: 25)
        } else {
            TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone,
                               tint: tint, endingSoon: state.endingSoon)
        }
    }
}

// MARK: - 컨트롤 버튼 (App Intents — 앱을 열지 않고 잠금화면에서 바로 동작)

private struct LAToggleButton: View {
    let status: TimerPhaseStatus
    let ownerId: String
    /// 재생/일시정지는 가장 중요한 버튼 — 페이즈 색으로 채워 강조
    var tint: Color = TimerColor.ringTime
    var body: some View {
        Button(intent: ToggleTimerIntent(ownerId: ownerId)) {
            LAButtonLabel(systemName: status == .running ? "pause.fill" : "play.fill",
                          bg: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct LANextButton: View {
    let ownerId: String
    var body: some View {
        Button(intent: NextSetIntent(ownerId: ownerId)) {
            LAButtonLabel(systemName: "forward.fill")
        }
        .buttonStyle(.plain)
    }
}

private struct LAStopButton: View {
    let ownerId: String
    var body: some View {
        Button(intent: StopTimerIntent(ownerId: ownerId)) {
            LAButtonLabel(systemName: "stop.fill",
                          iconTint: Color(hex: "#F87171"),
                          bg: Color(hex: "#F87171").opacity(0.18))
        }
        .buttonStyle(.plain)
    }
}

private struct LAButtonLabel: View {
    let systemName: String
    var iconTint: Color = .white
    var bg: Color = Color.white.opacity(0.14)
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(iconTint)
            .frame(width: 54, height: 46)
            .background(bg, in: Capsule())
    }
}

/// running/paused일 때만 노출되는 컨트롤 묶음 (재생·정지 / 다음 / 정지)
private struct LAControls: View {
    let status: TimerPhaseStatus
    let ownerId: String
    var tint: Color = TimerColor.ringTime
    var body: some View {
        if status != .done {
            HStack(spacing: 8) {
                LAToggleButton(status: status, ownerId: ownerId, tint: tint)
                LANextButton(ownerId: ownerId)
                LAStopButton(ownerId: ownerId)
            }
        }
    }
}

// MARK: - 잠금화면 뷰

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BeepTimerWidgetAttributes>

    var body: some View {
        let (mode, status) = modeAndStatus(from: context.state)
        let isAllDone = (status == .done) && (context.state.setIndex >= context.state.totalSets)
        let phaseTint = PhaseTint(context.state)
        let modeColor = phaseTint.color(for: mode)
        // 마지막 5초엔 배지/진행 바가 빨간색으로 바뀌어 눈에 띈다
        let tint = (status == .running && context.state.endingSoon) ? Color.red : modeColor

        VStack(spacing: 10) {
            // 상단: 페이즈 배지 · 타이틀 · 세트
            HStack(spacing: 8) {
                Text(mode == .time ? "TIME" : "REST")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(TimerColor.bg)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tint))

                Text(context.attributes.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(context.state.setCountText)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }

            // 가운데: 큰 타이머 + 큼직한 컨트롤
            if status == .done {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(isAllDone ? Color.green : modeColor)
                    Text(isAllDone ? "모든 세트 완료!" : "완료")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    TimerCountdownText(state: context.state, status: status,
                                       tint: context.state.endingSoon ? .red : .white)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Spacer(minLength: 6)

                    LAControls(status: status, ownerId: context.attributes.ownerId,
                               tint: modeColor)
                }
            }

            // 하단: 남은 시간 진행 바 (실행 중에만)
            if status == .running, context.state.endTime > Date() {
                ProgressView(timerInterval: min(context.state.startTime, context.state.endTime)...context.state.endTime,
                             countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(tint)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

struct BeepTimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeepTimerWidgetAttributes.self) { context in
            // 잠금화면(확장) 뷰 — 앱과 같은 다크 톤
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(TimerColor.bg)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let (mode, status) = modeAndStatus(from: context.state)
            let isAllDone = (status == .done) && (context.state.setIndex >= context.state.totalSets)
            let phaseTint = PhaseTint(context.state)

            return DynamicIsland {
                // 확장 - 왼쪽 (아이콘 + 세트/페이즈)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone,
                                           tint: phaseTint, endingSoon: context.state.endingSoon)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.setCountText)
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(mode == .time ? "Time" : "Rest")
                                .font(.caption2)
                        }
                    }
                }

                // 확장 - 가운데 (큰 타이머 or 체크)
                DynamicIslandExpandedRegion(.center) {
                    if status == .done {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                            Text("DONE")
                                .font(.headline)
                        }
                    } else {
                        TimerCountdownText(state: context.state, status: status)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                }

                // 확장 - 아래 (재생/일시정지 · 다음 · 정지 — App Intents)
                DynamicIslandExpandedRegion(.bottom) {
                    LAControls(status: status, ownerId: context.attributes.ownerId,
                               tint: phaseTint.color(for: mode))
                }

            } compactLeading: {
                // compact 왼쪽: 페이즈 색 원형 프로그레스 링 (운동=파랑, 휴식=초록)
                CompactPhaseRing(state: context.state, mode: mode, status: status,
                                 isAllDone: isAllDone, tint: phaseTint)
            } compactTrailing: {
                // compact 오른쪽: 남은 시간 (페이즈 색과 통일)
                TimerCountdownText(state: context.state, status: status, tint: phaseTint.color(for: mode))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 44)
            } minimal: {
                // 최소: 페이즈 색 링 + 아이콘, 마지막 5초엔 빨간 링, 종료 시 멈춤 아이콘
                MinimalIslandView(mode: mode, status: status,
                                  endingSoon: context.state.endingSoon, tint: phaseTint)
            }
        }
    }
}
