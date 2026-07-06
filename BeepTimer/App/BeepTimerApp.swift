//
//  BeepTimerApp.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI
import RealmSwift
import ActivityKit

@main
struct BeepTimerApp: App {
    init() {
        // v9: RCustomArea.webUrl(웹 모드 시작 URL) 추가 (additive 변경이라 마이그레이션 블록 불필요)
        Realm.Configuration.defaultConfiguration = Realm.Configuration(schemaVersion: 9)

        // 위젯 버튼(LiveActivityIntent)이 앱 프로세스에서 컨트롤러를 즉시 찾을 수 있도록
        // 앱 시작 시점에 싱글톤을 생성해 TimerWidgetActionBus에 등록한다.
        _ = TimerController.shared

        // 프로세스가 새로 시작됐다는 건 실행 중이던 타이머 상태가 모두 사라졌다는 뜻이므로,
        // 이전 프로세스가 남긴 Live Activity는 전부 고아다.
        // 정리하지 않으면 잠금화면에 얼어붙은 채(버튼도 안 듣는 상태로) 계속 남는다.
        // (지금 시점의 목록을 먼저 잡아둬야 이후 새로 시작한 활동을 건드리지 않는다)
        let orphans = Activity<BeepTimerWidgetAttributes>.activities
        Task {
            for activity in orphans {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            TimerPager()
        }
    }
}
