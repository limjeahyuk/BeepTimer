//
//  CircleTimerView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

struct CircleTimerView: View {
    @ObservedObject var controller: TimerController
    
    var ringWidth: CGFloat = 20
    var bottomGapFraction: CGFloat = 0.14
    
    func mmss(_ sec: Int) -> String {
        let s = max(0, sec)
        let m = s / 60
        let ss = s % 60
        return String(format: "%02d : %02d", m, ss)
    }
    
    func clockString(_ total: Int) -> String {
        let s = max(0, total)
        if s >= 3600 {
            let h = s / 3600
            let m = (s % 3600) / 60
            let ss = s % 60
            return String(format: "%02d : %02d : %02d", h, m, ss)
        }else{
            return mmss(s)
        }
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let now = ctx.date
            let remaining = controller.displayRemaining(at: now)

            // p: 남은 비율(1→0). fill: 채워진 비율(0→1)
            let p = controller.progress(at: now)
            let fill = max(0, min(1, 1 - Double(p)))

            // 하단 갭 계산
            // 0.0 - 3시 ~ 0.75 - 12시
            let g = max(0.04, min(0.30, Double(bottomGapFraction)))
            let leftEdge  = 1.0 - g/2.0
            let rightEdge = g/2.0
            let allowed = leftEdge - rightEdge

            // 트랙/진행 색
            let trackColor    = (controller.phase == .time ? TimerColor.ringRest : TimerColor.ringTime).opacity(0.35)
            let progressColor = (controller.phase == .time ? TimerColor.ringTime : TimerColor.ringRest)
            
            let ringRotation: Double = 90

            // 실제 렌더링된 크기 기준으로 내부 요소 크기를 계산해야
            // 작은 화면에서 원이 축소돼도 글자가 넘치거나 겹치지 않는다
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let ring = min(ringWidth, side * 0.11)

                ZStack {
                    ZStack {
                        Circle()
                            .trim(from: rightEdge, to: leftEdge)
                            .stroke(trackColor, style: .init(lineWidth: ring, lineCap: .round))

                        let end = rightEdge + allowed * fill
                        Circle()
                            .trim(from: rightEdge, to: end)
                            .stroke(progressColor, style: .init(lineWidth: ring, lineCap: .round))
                    }
                    .rotationEffect(.degrees(ringRotation))
                    .animation(nil, value: controller.phase)

                    // ===== 중앙 타이머 텍스트 =====
                    Text(clockString(remaining))
                        .font(.system(size: side * 0.19, weight: .bold, design: .rounded))
                        .foregroundStyle(TimerColor.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .allowsTightening(true)
                        .contentTransition(.numericText())
                        .frame(maxWidth: side - ring * 2 - 24)

                    VStack {
                        Text(controller.phaseLabel)
                            .font(.system(size: side * 0.085, weight: .bold, design: .rounded))
                            .foregroundStyle(controller.phase == .time ? TimerColor.ringTime : TimerColor.ringRest)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                            .contentTransition(.numericText())
                            .padding(.top, ring + side * 0.05)

                        Spacer()

                        Image(systemName: controller.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: side * 0.12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .onChange(of: p) { _ in controller.tryFireEndIfNeeded() }
            .onChange(of: remaining) { newRemaining in
                if let end = controller.currentEndTime {
                    controller.handleBeepIfNeeded(displayRemaining: newRemaining, endTime: end)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Circle()) // 원 전체 클릭 되도록
        .onTapGesture {
            logger.d("circle Clickeds")
            controller.toggle()
        }
    }
}

private extension TimerController {
    var isRunning: Bool { if case .running = state { true } else { false } }
}
