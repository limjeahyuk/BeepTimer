//
//  BeepTimerApp.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI

@main
struct BeepTimerApp: App {
    init() {
        // 위젯 버튼(LiveActivityIntent)이 앱 프로세스에서 컨트롤러를 즉시 찾을 수 있도록
        // 앱 시작 시점에 싱글톤을 생성해 TimerWidgetActionBus에 등록한다.
        _ = TimerController.shared
    }

    var body: some Scene {
        WindowGroup {
            TimerPager()
        }
    }
}
