//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var timerController = TimerController()
    
    @State private var workoutTime: Int = 12
    @State private var restTime: Int = 15
    @State private var setCount: Int = 3
    @State var currentSet: Int = 1

    var body: some View {
        ZStack {
            // 화면 전체 색상.
            Color(hex: "#1A1E24")
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                TimerHeaderView(totalTime: workoutTime, restTime: restTime, totalSets: setCount, currentSet: $currentSet)
                    .padding(.horizontal, 40)
                
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let ringWidth = max(12, side * 0.06)
                    
                    // 타이머 영역
                    CircleTimerView(controller: timerController, ringWidth: ringWidth)
                        .frame(width: side - 24, height: side - 24)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(maxWidth: .infinity)

                HStack{
                    // 시작 버튼
                    Button(action: {
                        // 타이머 시작
                        timerController.start(total: workoutTime)
                    }) {
                        Text("재시작")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .font(.title2.bold())
                            .cornerRadius(16)
                            .padding(.horizontal)
                    }
                    
                    // 시작 버튼
                    Button(action: {
                        switch timerController.state {
                        case .idle:
                            timerController.start(total: workoutTime)
                        case .running(_, _):
                            timerController.pause()
                        case .paused(_):
                            timerController.resume()
                        }
                    }) {
                        Text(timerController.state.buttonTitle)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.black)
                            .font(.title2.bold())
                            .cornerRadius(16)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
                
            }
            .onAppear {
                timerController.setTotalTime(workoutTime)
                timerController.onEnded = {
                    logger.d("time the end")
                }
            }
        }
    }
}

extension TimerController.State {
    var buttonTitle: String {
        switch self {
        case .running: return "일시정지"
        case .paused: return "재개"
        case .idle: return "시작"
        }
    }
}
