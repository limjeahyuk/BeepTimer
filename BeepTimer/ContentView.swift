//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var timerController = TimerController()
    
    @State private var workoutTime: Int = 123
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

                // 타이머 영역
                CircleTimerView(controller: timerController)

                // 시작 버튼
                Button(action: {
                    // 타이머 시작
                    timerController.start()
                }) {
                    Text("시작")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.black)
                        .font(.title2.bold())
                        .cornerRadius(16)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .onAppear {
                timerController.totalTime = workoutTime
                timerController.timeRemaining = workoutTime
                timerController.onEnded = {
                    print("타이머 종료")
                }
            }
        }
    }
}

