//
//  CircleTimerView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

struct CircleTimerView: View {
    @ObservedObject var controller: TimerController
    
    @ObservedObject var settings = SettingManager.shared
    
    var ringWidth: CGFloat = 20
    var bottomGapFraction: CGFloat = 0.14
    
    let timeColor = Color(hex: "#22D3EE")
    let restColor = Color(hex: "#FB923C")
    
    func formattedValue(_ sec: Int) -> String {
        if sec < 60 {
            return "\(String(sec)) s"
        } else if sec % 60 == 0 {
            return "\(sec / 60) m"
        } else {
            return "\(sec / 60)m \(sec % 60)s"
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
            let g = max(0.04, min(0.30, Double(bottomGapFraction)))
            let leftEdge  = 0.75 - g/2.0
            let rightEdge = 0.75 + g/2.0

            // 트랙/진행 색
            let trackColor    = (controller.phase == .time ? timeColor : restColor).opacity(0.35)
            let progressColor = (controller.phase == .time ? restColor : timeColor)

            ZStack {
                // ===== 트랙(배경 링): 하단 갭 비우고 두 조각으로 그리기 =====
                // [0 .. leftEdge]
                Circle()
                    .trim(from: 0.0, to: leftEdge)
                    .stroke(trackColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                // [rightEdge .. 1]
                Circle()
                    .trim(from: rightEdge, to: 1.0)
                    .stroke(trackColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

                // ===== 진행 링: 왼쪽 끝 → 오른쪽 끝 (위를 통해) =====
                // 허용 경로 길이 = 1 - 갭
                let allowed = 1.0 - g
                let len = allowed * fill          // 채워야 할 길이
                let end = leftEdge - len          // 감소 방향

                if end >= 0 {
                    // 래핑 없음: [end .. leftEdge]
                    Circle()
                        .trim(from: end, to: leftEdge)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                } else {
                    // 래핑: [0 .. leftEdge] + [1+end .. 1]
                    Circle()
                        .trim(from: 0.0, to: leftEdge)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    Circle()
                        .trim(from: 1.0 + end, to: 1.0)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                }

                // ===== 중앙 타이머 텍스트 =====
                Text(formattedValue(remaining))
                    .font(.system(size: max(24, ringWidth * 1.8), weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#F3F4F6"))
                    .monospacedDigit()

                // ===== 하단 갭 안쪽 컨트롤 =====
                VStack {
                    Spacer()
                    HStack(spacing: 28) {
                        // 모드 토글
                        Button {
                            switch settings.autoMode {
                            case .fullAuto: settings.autoMode = .setAuto
                            case .setAuto:  settings.autoMode = .manual
                            case .manual:   settings.autoMode = .fullAuto
                            }
                        } label: {
                            Image(systemName: {
                                switch settings.autoMode {
                                case .fullAuto: "repeat"
                                case .setAuto:  "repeat.1"
                                case .manual:   "forward.end"
                                }
                            }())
                            .font(.system(size: 18, weight: .semibold))
                        }

                        // 재생/일시정지
                        Button {
                            togglePlay()
                        } label: {
                            Image(systemName: controller.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color(hex: "#F3F4F6"))
                    .padding(.bottom, ringWidth * 0.7)
                }
            }
            .rotationEffect(.degrees(180))
            // 단계 바뀔 때 색 전환만 부드럽게
            .animation(.easeInOut(duration: 0.25), value: controller.phase)
            .onChange(of: p) { _ in controller.tryFireEndIfNeeded() }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
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
