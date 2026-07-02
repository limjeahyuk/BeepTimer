//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI
import RealmSwift

struct ContentView: View {
    @EnvironmentObject var controller: TimerController

    @ObservedObject var settings = SettingManager.shared

    // 저장(라이브러리)도 TimerLibraryView와 동일한 기본 Realm 설정을 사용한다.
    @ObservedResults(RTimerProgram.self) var programs

    @State private var savedFlash = false

    private var isIdle: Bool {
        if case .idle = controller.state { return true }
        return false
    }

    // MARK: - 메인 화면에서 직접 편집하기 위한 바인딩 (편집 시 lastConfig로 즉시 보존)
    private var timeBinding: Binding<Int> {
        Binding(get: { Int(controller.timeSec) },
                set: { controller.timeSec = TimeInterval(max(1, $0)); controller.saveLastUsed() })
    }
    private var restBinding: Binding<Int> {
        Binding(get: { Int(controller.restSec) },
                set: { controller.restSec = TimeInterval(max(0, $0)); controller.saveLastUsed() })
    }
    private var setsBinding: Binding<Int> {
        Binding(get: { controller.totalSets },
                set: { controller.totalSets = max(1, $0); controller.saveLastUsed() })
    }

    /// 현재 메인 화면 설정(제목/Time/Rest/Set)을 라이브러리에 새 타이머로 저장
    private func saveCurrentAsProgram() {
        let sets = max(1, controller.totalSets)
        let t = max(1, Int(controller.timeSec))
        let r = max(0, Int(controller.restSec))
        let trimmed = controller.timerTitle.trimmingCharacters(in: .whitespaces)
        let title = trimmed.isEmpty ? "My Timer" : trimmed

        let obj = RTimerProgram()
        obj.title = title
        obj.createdAt = Date()
        let steps = RealmSwift.List<RStep>()
        for _ in 0..<sets {
            let ts = RStep(); ts.kindRaw = "time"; ts.seconds = t
            let rs = RStep(); rs.kindRaw = "rest"; rs.seconds = r
            steps.append(objectsIn: [ts, rs])
        }
        obj.steps = steps
        $programs.append(obj)   // ObservedResults가 write 트랜잭션 처리

        controller.timerTitle = title
        controller.saveLastUsed()

        hideKeyboard()
        withAnimation { savedFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { savedFlash = false }
        }
    }

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
                TextField("Title", text: $controller.timerTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(TimerColor.textPrimary)
                .font(.fromCSSFont(36, weight: .bold))
                .disabled(!isIdle)
                .submitLabel(.done)
                .onSubmit { controller.saveLastUsed() }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let ringWidth = max(22, side * 0.06)
                    
                    // 타이머 영역
                    CircleTimerView(controller: controller, ringWidth: ringWidth)
                        .frame(width: side - 24, height: side - 24)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                
                HStack(spacing: 24){
                    
                    Button {
                        logger.d("backward fill")
                        if !controller.previousSet() {
                            logger.d("timerController previousSet fail")
                        }
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
                        VStack(spacing: 2) {
                            Image(systemName: {
                                switch settings.autoMode {
                                case .fullAuto: "repeat"        // 전체 자동 반복
                                case .setAuto:  "repeat.1"      // 세트 단위 자동
                                case .manual:   "hand.raised.fill" // 수동
                                }
                            }())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                            Text({
                                switch settings.autoMode {
                                case .fullAuto: "Auto"
                                case .setAuto:  "Set"
                                case .manual:   "Manual"
                                }
                            }())
                            .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .accessibilityLabel("자동 모드: \(settings.autoMode == .fullAuto ? "전체 자동" : settings.autoMode == .setAuto ? "세트 자동" : "수동")")
                    
                    Spacer()
                    
                    Button {
                        logger.d("backward fill")
                        if !controller.nextSet() {
                            logger.d("end point")
                        }
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

                // 정지 / 리셋 (idle일 땐 비활성)
                Button {
                    logger.d("stop / reset")
                    controller.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.fromCSSFont(15, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 22)
                        .background(TimerColor.btnResetBg.opacity(isIdle ? 0.12 : 0.22), in: Capsule())
                        .foregroundStyle(TimerColor.btnResetBg)
                }
                .disabled(isIdle)
                .opacity(isIdle ? 0.4 : 1)

                VStack(spacing: 16){
                    HStack{
                        Text("Time")
                        Spacer()
                        if isIdle {
                            TimeFieldButton(title: "", seconds: timeBinding, minSeconds: 1, maxSeconds: 59*60+59)
                        } else {
                            Text(clockString(Int(controller.timeSec)))
                        }
                    }
                    HStack{
                        Text("Rest")
                        Spacer()
                        if isIdle {
                            TimeFieldButton(title: "", seconds: restBinding, minSeconds: 0, maxSeconds: 59*60+59)
                        } else {
                            Text(clockString(Int(controller.restSec)))
                        }
                    }
                    HStack{
                        Text("Set")
                        Spacer()
                        if isIdle {
                            SetsFieldButton(title: "", sets: setsBinding, minSets: 1, maxSets: 99)
                        } else {
                            Text("\(controller.setIndex)/\(controller.totalSets)")
                        }
                    }

                    // 현재 설정을 라이브러리에 저장
                    Button {
                        saveCurrentAsProgram()
                    } label: {
                        Label(savedFlash ? "저장됨!" : "Save",
                              systemImage: savedFlash ? "checkmark" : "square.and.arrow.down")
                            .font(.fromCSSFont(15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TimerColor.ringTime.opacity(savedFlash ? 0.32 : 0.20), in: Capsule())
                            .foregroundStyle(savedFlash ? .green : TimerColor.ringTime)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .foregroundStyle(TimerColor.textPrimary)
                .font(.fromCSSFont(18, weight: .medium))
                .padding(.horizontal, 40)
                .padding(.bottom, 24)

            }
            .onAppear {
                
                if let last = controller.loadLastUsed() {
                    controller.configure(title: last.title, time: Int(TimeInterval(max(0, last.time))), rest: Int(TimeInterval(max(0, last.rest))), sets: max(1, last.sets))
                } else {
                    // 기본값 그대로: 30 / 15 / 3
                    controller.configure(title: "Beep Timer", time: 30, rest: 10, sets: 3)
                }
                
                controller.onEnded = {
                    logger.d("contentView setting onEnded")
                }
            }
        }
    }
}
