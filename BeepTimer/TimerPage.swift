//
//  File.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/14/25.
//

import SwiftUI

struct TimerPager: View {
    @StateObject private var controller = TimerController()
    @Environment(\.scenePhase) var scenePhase

    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            // 0: 메인 타이머
            ContentView()
                .environmentObject(controller)
                .tag(0)

            // 1: 라이브러리
            NavigationStack {
                TimerLibraryView(
                        onPick: { model in
                            if let trs = model.asTimeRestSets() {
                                controller.configure(title: model.title, time: trs.time, rest: trs.rest, sets: trs.sets)
                                print("trs.time \(trs.time)")
                                controller.stop()
                                page = 0 // 선택 후 메인으로 스와이프 백
                            } else {
                                // 혼합값(mixed)이면 처리: ① 첫 값으로 정규화하거나 ② 알럿/시트로 안내
                                // 간단 정규화 예시(첫 값 채택):
                                let title = model.title
                                let times = model.steps.filter { $0.kind == .time }.map(\.seconds)
                                let rests = model.steps.filter { $0.kind == .rest }.map(\.seconds)
                                let time = times.first ?? 0
                                let rest = rests.first ?? 0
                                let sets = model.setsCount

                                controller.configure(title: title, time: time, rest: rest, sets: sets)
                                controller.stop()
                                page = 0
                            }
                            controller.saveLastUsed()
                        }
                    )
            }
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(hex: "#1A1E24").ignoresSafeArea())
        .onChange(of: scenePhase) { newValue in
            switch newValue {
            case .background:
                // 백그라운드로 갈 때 현재 상태 기준으로 Live Activity 동기화
                logger.d("background scene phase")
                controller.isInBackground = true
                Task { await controller.syncLiveActivityForCurrentState() }
            case .active:
                // 다시 앱으로 돌아오면 Live Activity는 유지해도 되고,
                // 원하면 끝내도 됨
                logger.d("active ground scene ")
                controller.isInBackground = false
                break
            default:
                break
            }
        }
    }
}

