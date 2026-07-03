//
//  BeepTimerApp.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI
import RealmSwift

@main
struct BeepTimerApp: App {
    init() {
        // v6: RDrawingMemo(그림 메모) + 배경/펜 색상 추가 (additive 변경이라 마이그레이션 블록 불필요)
        Realm.Configuration.defaultConfiguration = Realm.Configuration(schemaVersion: 6)

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
