//
//  BeepTimerWatchApp.swift
//  BeepTimerWatch Watch App
//
//  Created by 인스플래닛 on 7/6/26.
//

import SwiftUI

@main
struct BeepTimerWatch_Watch_AppApp: App {
    init() {
        WatchConnectivityManager.shared.activate()   // 아이폰 연결 활성화
        // 백그라운드에서도 타이머·햅틱을 이어가려면 운동 세션이 필요하다 — 권한을 미리 요청한다.
        WatchWorkoutSession.shared.requestAuthorizationIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TimerListView()
            }
        }
    }
}
