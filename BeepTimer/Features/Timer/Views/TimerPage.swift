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
                .onTapGesture {
                    hideKeyboard()
                    logger.d("hideKeyBoard")
                }

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
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase) { newValue in
            switch newValue {
            case .background:
                // 백그라운드로 갈 때: Live Activity 동기화 + 남은 페이즈 알림 예약
                logger.d("background scene phase")
                controller.isInBackground = true
                controller.scheduleBackgroundNotifications()
                Task { await controller.syncLiveActivityForCurrentState() }
            case .active:
                // 복귀: 예약 알림 취소 + 백그라운드에서 흘러간 만큼 상태 보정
                logger.d("active ground scene ")
                controller.isInBackground = false
                Task { await controller.handleReturnToForeground() }
            default:
                break
            }
        }
        .onChange(of: page) { newValue in
            logger.d("페이지 변경 \(newValue)")
            hideKeyboard()
        }
        .onOpenURL { url in
            // Live Activity / Dynamic Island 버튼 딥링크 처리
            // beeptimer://toggle , beeptimer://next
            guard url.scheme == "beeptimer" else { return }
            let action = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            logger.d("onOpenURL action=\(action)")
            page = 0   // 항상 메인 타이머로
            switch action {
            case "toggle":
                controller.toggle()
            case "next":
                _ = controller.nextSet()
            default:
                break
            }
        }
    }
}


extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
