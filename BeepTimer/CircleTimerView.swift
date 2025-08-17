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
    
    let timeGrad = Color(hex: "#22D3EE")
    let restGrad = Color(hex: "#FB923C")
    
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
            let p = controller.progress(at: now)
            let remaining = controller.displayRemaing(at: now)

            // 안전 범위로 클램프
            let gap = min(max(bottomGapFraction, 0.04), 0.30)

            // 색 구성
            let trackColor   = (controller.phase == .time ? timeGrad : restGrad).opacity(0.35)
            let progressColor = (controller.phase == .time ? restGrad : timeGrad)

            ZStack {
                // ===============================
                // 1) 트랙(배경 링): 아래만 비우기
                //    trim 구간을 두 개로 나눠 그리면 "하단에만" gap이 생깁니다.
                // ===============================
                Circle()
                    .trim(from: 0.0, to: 0.5 - gap/2)
                    .stroke(style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .foregroundColor(trackColor)

                Circle()
                    .trim(from: 0.5 + gap/2, to: 1.0)
                    .stroke(style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .foregroundColor(trackColor)

                // ===============================
                // 2) 진행 링: 기존 0→p 로 그리되,
                //    "같은 gap 마스크"로 하단 구간을 잘라냅니다.
                // ===============================
                Circle()
                    .trim(from: 0.0, to: p)
                    .stroke(style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .scaleEffect(x: -1, y: 1, anchor: .center)
                    .foregroundStyle(progressColor)
                    .mask(
                        ZStack {
                            Circle()
                                .trim(from: 0.0, to: 0.5 - gap/2)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Circle()
                                .trim(from: 0.5 + gap/2, to: 1.0)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                    )

                // ===============================
                // 3) 중앙 타이머 텍스트
                // ===============================
                Text("\(formattedValue(remaining))")
                    .font(.system(size: max(24, ringWidth * 1.8), weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#F3F4F6"))
                    .monospacedDigit()

                // ===============================
                // 4) 하단 gap 안쪽 컨트롤 (오토모드 토글 + 재생/일시정지)
                //    gap 만큼 올려서 링과 겹치지 않게 합니다.
                // ===============================
                VStack {
                    Spacer()
                    HStack(spacing: 28) {
                        // --- 오토모드 토글 버튼 ---
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
                                case .manual:   "forward.end" // 또는 "hand.tap"
                                }
                            }())
                            .font(.system(size: 18, weight: .semibold))
                        }

                        // --- 재생/일시정지 버튼 ---
                        Button {
                            togglePlay()
                        } label: {
                            Image(systemName: controller.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color(hex: "#F3F4F6"))
                    // gap 중심보다 약간 위로 배치되도록 보정
                    .padding(.bottom, ringWidth * 0.7)
                }
            }
            .onChange(of: p) { _ in
                controller.tryFireEndIfNeeded()
            }
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
