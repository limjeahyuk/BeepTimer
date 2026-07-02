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

struct TimerPhaseRingIcon: View {
    let mode: TimerPhaseMode      // .time / .rest
    let status: TimerPhaseStatus  // .running / .paused / .done
    let isAllDone: Bool


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
        switch mode {
        case .time: return TimerColor.ringTime
        case .rest: return TimerColor.ringRest
        }
    }

    // done 되자마자 mode가 변경되어버려서 다음 링 색상이 되어버립니다.
    private var doneColor: Color {
        if isAllDone {
            return .red
        }else {
            switch mode {
            case .time: return TimerColor.ringRest
            case .rest: return TimerColor.ringTime
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

// MARK: - 남은 시간 / 상태 텍스트

/// running이면 카운트다운(.timer), paused면 고정된 남은 시간, done이면 "완료"
private struct TimerCountdownText: View {
    let state: BeepTimerWidgetAttributes.ContentState
    let status: TimerPhaseStatus

    var body: some View {
        switch status {
        case .running:
            Text(state.endTime, style: .timer)
                .monospacedDigit()
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

// MARK: - 컨트롤 버튼 (App Intents — 앱을 열지 않고 잠금화면에서 바로 동작)

private struct LAToggleButton: View {
    let status: TimerPhaseStatus
    var body: some View {
        Button(intent: ToggleTimerIntent()) {
            LAButtonLabel(systemName: status == .running ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.plain)
    }
}

private struct LANextButton: View {
    var body: some View {
        Button(intent: NextSetIntent()) {
            LAButtonLabel(systemName: "forward.fill")
        }
        .buttonStyle(.plain)
    }
}

private struct LAStopButton: View {
    var body: some View {
        Button(intent: StopTimerIntent()) {
            LAButtonLabel(systemName: "stop.fill", tint: TimerColor.btnResetBg)
        }
        .buttonStyle(.plain)
    }
}

private struct LAButtonLabel: View {
    let systemName: String
    var tint: Color = .white
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 38, height: 34)
            .background(Color.white.opacity(0.14), in: Capsule())
    }
}

/// running/paused일 때만 노출되는 컨트롤 묶음 (재생·정지 / 다음 / 정지)
private struct LAControls: View {
    let status: TimerPhaseStatus
    var body: some View {
        if status != .done {
            HStack(spacing: 10) {
                LAToggleButton(status: status)
                LANextButton()
                LAStopButton()
            }
        }
    }
}

struct BeepTimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeepTimerWidgetAttributes.self) { context in
            // 잠금화면(확장) 뷰
            let (mode, status) = modeAndStatus(from: context.state)
            let isAllDone = (status == .done) && (context.state.setIndex >= context.state.totalSets)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)

                        TimerCountdownText(state: context.state, status: status)
                            .font(.title3)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.setIndex)/\(context.state.totalSets)")
                            .font(.subheadline.weight(.semibold))
                        Text(mode == .time ? "Time" : "Rest")
                            .font(.caption2)
                            .foregroundColor(mode == .time ? TimerColor.ringTime : TimerColor.ringRest)
                    }
                }

                LAControls(status: status)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } dynamicIsland: { context in
            let (mode, status) = modeAndStatus(from: context.state)
            let isAllDone = (status == .done) && (context.state.setIndex >= context.state.totalSets)

            return DynamicIsland {
                // 확장 - 왼쪽 (아이콘 + 세트/페이즈)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(context.state.setIndex)/\(context.state.totalSets)")
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
                    LAControls(status: status)
                }

            } compactLeading: {
                // compact 왼쪽: 아이콘
                TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone)
            } compactTrailing: {
                // compact 오른쪽: 남은 시간만 깔끔하게
                TimerCountdownText(state: context.state, status: status)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 44)
            } minimal: {
                // 최소: 아이콘만
                TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone)
            }
        }
    }
}
