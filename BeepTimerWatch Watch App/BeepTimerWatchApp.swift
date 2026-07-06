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
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TimerListView()
            }
        }
    }
}
