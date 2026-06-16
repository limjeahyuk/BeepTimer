//
//  NotificationService.swift
//  BeepTimer
//
//  백그라운드/잠금 화면에서 페이즈 전환 시점마다 소리·진동 알림을 띄운다.
//

import Foundation
import UserNotifications

/// 알림으로 전달할 페이즈 경계 1건
struct PhaseBoundary {
    enum NextKind {
        case time(set: Int)   // 다음이 운동(세트 n)
        case rest(set: Int)   // 다음이 휴식(세트 n)
        case done             // 운동 전체 종료
    }
    let fireDate: Date
    let next: NextKind
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let prefix = "beeptimer.phase."

    /// 최초 1회 권한 요청 (이미 결정돼 있으면 그대로 둔다)
    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    logger.e("notification auth error \(error)")
                } else {
                    logger.d("notification auth granted: \(granted)")
                }
            }
        }
    }

    /// 예약돼 있던 페이즈 알림 전부 취소
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// 경계 목록을 받아 각 시점에 알림 예약. 기존 예약은 먼저 모두 지운다.
    func schedule(boundaries: [PhaseBoundary]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        for (i, b) in boundaries.enumerated() {
            let interval = b.fireDate.timeIntervalSince(now)
            guard interval > 0.5 else { continue }   // 0.5초 이하 과거/현재는 스킵

            let content = UNMutableNotificationContent()
            content.sound = .default
            switch b.next {
            case .time(let set):
                content.title = "운동 시작 💪"
                content.body = "세트 \(set) — 운동을 시작하세요!"
            case .rest(let set):
                content.title = "휴식 시작 😮‍💨"
                content.body = "세트 \(set) 완료 — 잠시 쉬어요."
            case .done:
                content.title = "운동 완료 ✅"
                content.body = "수고하셨어요! 모든 세트를 끝냈습니다."
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: "\(prefix)\(i)", content: content, trigger: trigger)
            center.add(request) { error in
                if let error { logger.e("notification add error \(error)") }
            }
        }
    }
}
