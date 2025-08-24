//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var timerController = TimerController()
    
    @ObservedObject var settings = SettingManager.shared
    
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

            VStack(spacing: 20) {
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
                .aspectRatio(1, contentMode: .fit)
                
                HStack(spacing: 24){
                    
                    Button {
                        logger.d("backward fill")
                    } label: {
                        Image(systemName: "backward.fill")
                            .resizable()
                            .frame(width: 22, height: 18)
                    }
                    
                    Spacer()
                    
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
                            case .manual:   "repeat"
                            }
                        }())
                        .resizable()
                        .frame(width: 22, height: 22)
                        .font(.system(size: 18, weight: .semibold))
                        .opacity(settings.autoMode == .manual ? 0.3 : 1)
                    }
                    
                    Spacer()
                    
                    Button {
                        logger.d("backward fill")
                    } label: {
                        Image(systemName: "forward.fill")
                            .resizable()
                            .frame(width: 22, height: 18)
                    }
                    
                }
                .frame(height: 48)
                .frame(maxWidth: 220, alignment: .center)
                .padding(.horizontal, 40)
                .background(
                    ZStack {
                        Capsule().fill(.ultraThinMaterial).opacity(0.18)
                        Capsule().fill(Color.white.opacity(0.22))
                    }
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
                .foregroundStyle(Color.white)
                
                
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
                .padding(.bottom, 24)
                

//                HStack{
//                    Button(action: {
//                        timerController.stop()
//                    }) {
//                        Text("리셋")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(TimerColor.btnResetBg)
//                            .foregroundColor(TimerColor.btnText)
//                            .font(.title2.bold())
//                            .cornerRadius(16)
//                            .padding(.horizontal)
//                    }
//                    
//                    // 시작 버튼
//                    Button(action: {
//                        switch timerController.state {
//                        case .idle, .paused(_):
//                            timerController.start()
//                        case .running(_, _):
//                            timerController.pause()
//                        }
//                    }) {
//                        Text(timerController.state.buttonTitle)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(TimerColor.btnStartBg)
//                            .foregroundColor(TimerColor.btnText)
//                            .font(.title2.bold())
//                            .cornerRadius(16)
//                            .padding(.horizontal)
//                    }
//                }
//                .padding(.bottom, 24)
                
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
