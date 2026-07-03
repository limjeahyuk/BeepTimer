//
//  TimerWidgetSnapshot.swift
//  BeepTimer
//
//  홈 화면 위젯이 읽는, 앱이 App Group에 저장하는 현재 타이머 스냅샷.
//  이 파일은 앱(BeepTimer)과 위젯(BeepTimerWidgetExtension) 두 타겟 모두에 포함된다.
//

import Foundation

/// 위젯에 보여줄 현재 타이머 상태 한 장.
struct TimerWidgetSnapshot: Codable, Equatable {
    // 설정값 (idle/active 공통)
    var title: String
    var time: Int
    var rest: Int
    var sets: Int

    // 진행 상태
    var isActive: Bool        // running 또는 paused (= Live Activity가 떠 있는 상태)
    var phaseIsRest: Bool     // 현재 페이즈가 휴식인가
    var setIndex: Int
    var startTime: Date? = nil // running일 때 현재 페이즈 시작시각 (timerInterval 렌더링용)
    var endTime: Date?        // running일 때 카운트다운 종료시각
    var isPaused: Bool
    var pausedRemain: Int?    // paused일 때 남은 초

    static let idleDefault = TimerWidgetSnapshot(
        title: "Beep Timer", time: 30, rest: 10, sets: 3,
        isActive: false, phaseIsRest: false, setIndex: 1,
        endTime: nil, isPaused: false, pausedRemain: nil
    )
}

/// App Group 공유 저장소 접근.
enum TimerWidgetStore {
    static let appGroup = "group.com.LimJH.BeepTimer"
    static let key = "timer.widget.snapshot.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func save(_ snapshot: TimerWidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> TimerWidgetSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(TimerWidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
}
