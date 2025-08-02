//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @State private var workoutTime: Double = 45
    @State private var restTime: Double = 15
    @State private var setCount: Int = 3

    var body: some View {
        ZStack {
            Color(hex: "#1A1E24")
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text("BeepTimer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // 타이머 영역
                Text("\(Int(workoutTime))s")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.green)

                // 설정 영역
                VStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("운동 시간: \(Int(workoutTime))초")
                            .foregroundColor(.white)
                        Slider(value: $workoutTime, in: 10...300, step: 5)
                            .accentColor(.green)
                    }

                    VStack(alignment: .leading) {
                        Text("휴식 시간: \(Int(restTime))초")
                            .foregroundColor(.white)
                        Slider(value: $restTime, in: 5...180, step: 5)
                            .accentColor(.blue)
                    }

                    VStack(alignment: .leading) {
                        Text("세트 수: \(setCount)회")
                            .foregroundColor(.white)
                        Stepper("", value: $setCount, in: 1...10)
                            .labelsHidden()
                    }
                }
                .padding(.horizontal)

                // 시작 버튼
                Button(action: {
                    // 타이머 시작
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
        }
    }
}

