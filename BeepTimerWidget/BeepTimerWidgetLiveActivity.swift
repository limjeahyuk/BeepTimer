//
//  BeepTimerWidgetLiveActivity.swift
//  BeepTimerWidget
//
//  Created by 임재혁 on 11/13/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

enum TimerPhaseMode: String, Codable { case time; case rest }
enum TimerPhaseStatus: String, Codable { case running; case paused; case done}

struct TimerPhaseRingIcon: View {
    let mode: TimerPhaseMode      // .time / .rest
    let status: TimerPhaseStatus  // .running / .paused / .done

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
        switch mode {
        case .time: return TimerColor.ringRest
        case .rest: return TimerColor.ringTime
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
                Image("widgetTimer")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 23, height: 23)
                    .foregroundColor(.white)
            case .rest:
                Image(systemName: "leaf.fill")
            }
        case .done:
            Image(systemName: "checkmark")
        }
    }
}

struct BeepTimerWidgetLiveActivity: Widget {
    func modeAndStatus(
            from state: BeepTimerWidgetAttributes.ContentState
        ) -> (TimerPhaseMode, TimerPhaseStatus) {

            let mode: TimerPhaseMode = (state.phase == "rest") ? .rest : .time

            let status: TimerPhaseStatus
            switch state.status {
            case "running":
                status = .running
            case "done":
                status = .done
            default:
                status = .paused
            }

            return (mode, status)
        }
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeepTimerWidgetAttributes.self) { context in
            // 잠금화면(확장) 뷰
            HStack {
                if context.state.phase == "done" {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Text(context.state.endTime, style: .timer)
                        .font(.title3)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    if context.state.phase == "done" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                    } else {
                        Text(context.state.endTime, style: .timer)
                            .font(.largeTitle)
                            .monospacedDigit()
                    }
                }

            } compactLeading: {
                let (mode, status) = self.modeAndStatus(from: context.state)
                
                TimerPhaseRingIcon(mode: mode, status: status)
            } compactTrailing: {
                if context.state.phase == "done" {
                    Image(systemName: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.white)
                } else if context.state.phase == "paused" {
                    HStack(spacing: 2) {
                        Image("widgetTimer")
                            .renderingMode(.template)        // Template 로 색 입히기
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.white)

                        Text("\(context.state.remainSec ?? 0)")
                            .monospacedDigit()
                            .font(.caption2)
                    }
                } else {
                    HStack(spacing: 2) {
                        Image("widgetTimer")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.white)

                        Text(context.state.endTime, style: .timer)
                            .monospacedDigit()
                            .font(.caption2)
                    }
                }
            } minimal: {
                let (mode, status) = self.modeAndStatus(from: context.state)
                
                TimerPhaseRingIcon(mode: mode, status: status)
            }
        }
    }
}
