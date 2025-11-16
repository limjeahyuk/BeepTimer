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
//                Image("widgetTimer")
//                    .renderingMode(.template)
//                    .resizable()
//                    .frame(width: 23, height: 23)
//                    .foregroundColor(.white)
                Image(systemName: "figure.run")
            case .rest:
                Image(systemName: "figure.mind.and.body")
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
            let (mode, status) = self.modeAndStatus(from: context.state)
            let isAllDone = (status == .done) && (context.state.setIndex >= context.state.totalSets)

               HStack(spacing: 8) {
                   TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone)

                   if status == .done {
                       VStack(alignment: .leading, spacing: 2) {
                           Text(context.attributes.title)
                               .font(.headline)
                           Text("DONE")
                               .font(.subheadline)
                               .foregroundColor(.secondary)
                       }
                   } else {
                       VStack(alignment: .leading, spacing: 2) {
                           Text(context.attributes.title)
                               .font(.headline)

                           Text(context.state.endTime, style: .timer)
                               .font(.title3)
                               .monospacedDigit()
                       }
                   }

                   Spacer()

                   Text("\(context.state.setIndex)/\(context.state.totalSets)")
                       .font(.subheadline)
               }
               .padding(.horizontal, 16)
               .padding(.vertical, 10)
        } dynamicIsland: { context in
            let (mode, status) = self.modeAndStatus(from: context.state)
            let isAllDone = (status == .done) && (context.state.setIndex >= context.state.totalSets)
            let runningRemain = max(0, Int(context.state.endTime.timeIntervalSince(Date())))


            return DynamicIsland {
                // 확장 - 왼쪽 (아이콘 + 세트)
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
                        Text(context.state.endTime, style: .timer)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                // 확장 - 아래 (재생 / 다음 버튼 예시)
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // 재생 / 일시정지 토글용 딥링크 (예시)
                        Link(destination: URL(string: "beeptimer://action=toggle")!) {
                            Label(
                                status == .running ? "일시정지" : "재생",
                                systemImage: status == .running ? "pause.fill" : "play.fill"
                            )
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        // 다음 세트로 건너뛰기 딥링크 (예시)
                        Link(destination: URL(string: "beeptimer://action=next")!) {
                            Label("다음 세트", systemImage: "forward.fill")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

            } compactLeading: {
                // compact 왼쪽: minimal과 동일 아이콘
                
            } compactTrailing: {
                // compact 오른쪽: 세트/타이머 or DONE
                
                Text(context.state.endTime, style: .timer)
                    .frame(width: 50)
                    .font(.caption2)
                    .monospacedDigit()

            } minimal: {
                //최소: 아이콘만
                TimerPhaseRingIcon(mode: mode, status: status, isAllDone: isAllDone)
            }
        }
    }
}
