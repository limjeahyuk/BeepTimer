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
            let remaining = controller.displayRemaing(at: now)

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

            ZStack {
                ZStack {
                    Circle()
                        .trim(from: rightEdge, to: leftEdge)
                        .stroke(trackColor, style: .init(lineWidth: ringWidth, lineCap: .round))
                    
                    let end = rightEdge + allowed * fill
                    Circle()
                        .trim(from: rightEdge, to: end)
                        .stroke(progressColor, style: .init(lineWidth: ringWidth, lineCap: .round))
                }
                .rotationEffect(.degrees(ringRotation))
                .animation(nil, value: controller.phase)
                
                // ===== 중앙 타이머 텍스트 =====
                Text(clockString(remaining))
                    .font(.system(size: max(42, ringWidth * 3), weight: .bold, design: .rounded))
                    .foregroundStyle(TimerColor.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
                    
                VStack{
                    Text(controller.phase == .time ? "Time" : "Rest")
                        .font(.system(size: max(12, ringWidth * 1.5), weight: .bold, design: .rounded))
                        .foregroundStyle(controller.phase == .time ? TimerColor.ringTime : TimerColor.ringRest)
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .contentTransition(.numericText())
                        .padding(.top, ringWidth + 15)
                    
                    Spacer()
                    
                    Image(systemName: controller.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: ringWidth * 2.2, weight: .bold))
                        .foregroundStyle(.white)
                }
                
            }
            .onChange(of: p) { _ in controller.tryFireEndIfNeeded() }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            logger.d("circle Clickeds")
            togglePlay()
        }
    }
    
    private func togglePlay() {
        switch controller.state {
        case .running:
            controller.pause()
        case .paused(let rem):
            controller.resume(rem)
        case .idle:
            controller.start()
        }
    }
}

private extension TimerController {
    var isRunning: Bool { if case .running = state { true } else { false } }
}
