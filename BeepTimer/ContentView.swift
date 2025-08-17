//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var timerController = TimerController()
    
    @State private var workoutTime: Int = 5
    @State private var restTime: Int = 3
    @State private var setCount: Int = 3
    @State var currentSet: Int = 1

    var body: some View {
        ZStack {
            // 화면 전체 색상.
            Color(hex: "#1A1E24")
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                TimerHeaderView(totalTime: workoutTime, restTime: restTime, totalSets: setCount, currentSet: timerController.setIndex)
                    .padding(.horizontal, 40)

                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let ringWidth = max(22, side * 0.06)
                    
                    // 타이머 영역
                    CircleTimerView(controller: timerController, ringWidth: ringWidth)
                        .frame(width: side - 24, height: side - 24)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(maxWidth: .infinity)

                HStack{
                    Button(action: {
                        timerController.stop()
                    }) {
                        Text("리셋")
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
                        case .idle, .paused(_):
                            timerController.start()
                        case .running(_, _):
                            timerController.pause()
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
                timerController.configure(time: workoutTime, rest: restTime, sets: setCount)
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
