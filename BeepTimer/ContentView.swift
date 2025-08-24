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
        ZStack {
            // 화면 전체 색상.
            TimerColor.bg
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()
                
                HStack(spacing: 10){
                    Text("SET")
                    Text(String(timerController.setIndex))
                }
                .foregroundStyle(TimerColor.textPrimary)
                .font(.fromCSSFont(36, weight: .bold))
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
                
                VStack(spacing: 20){
                    HStack{
                        Text("Time")
                        Spacer()
                        Text(clockString(workoutTime))
                    }
                    HStack{
                        Text("Rest")
                        Spacer()
                        Text(clockString(restTime))
                    }
                    HStack{
                        Text("Set")
                        Spacer()
                        Text("\(timerController.setIndex)/\(setCount)")
                    }
                }
                .foregroundStyle(TimerColor.textPrimary)
                .font(.fromCSSFont(18, weight: .medium))
                .padding(.horizontal, 40)
                

                HStack{
                    Button(action: {
                        timerController.stop()
                    }) {
                        Text("리셋")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TimerColor.btnResetBg)
                            .foregroundColor(TimerColor.btnText)
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
                            .background(TimerColor.btnStartBg)
                            .foregroundColor(TimerColor.btnText)
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
