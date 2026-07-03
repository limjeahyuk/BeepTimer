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
        case time(set: Int)            // 다음이 운동(세트 n) — 자동으로 시작됨
        case rest(set: Int)            // 다음이 휴식(세트 n) — 자동으로 시작됨
        case pauseBeforeTime(set: Int) // 다음이 운동이지만 자동 시작 안 함(일시정지)
        case pauseBeforeRest(set: Int) // 다음이 휴식이지만 자동 시작 안 함(일시정지)
        case done                      // 운동 전체 종료
    }
    let fireDate: Date
    let next: NextKind
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let prefix = "beeptimer.phase."

    /// 타이머(owner) 하나당 예약 상한.
    /// iOS는 앱 전체 pending 알림을 64개까지만 유지하므로, 동시 실행 타이머가 있어도
    /// 서로의 예약을 밀어내지 않도록 여유를 둔다.
    private let maxPerOwner = 30

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

    /// 특정 타이머(owner)의 페이즈 알림만 취소 — 다른 타이머 예약은 건드리지 않는다.
    /// 이미 배달돼 알림 센터에 남아 있는 지난 페이즈 알림도 함께 지워
    /// 현재 타이머 상태와 다른 문구("휴식 시작" 등)가 계속 보이지 않게 한다.
    func cancel(ownerId: String) {
        let ids = (0..<maxPerOwner).map { identifier(ownerId: ownerId, index: $0) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// 모든 페이즈 알림 취소 (앱의 다른 종류 알림은 남긴다)
    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [prefix] requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        center.getDeliveredNotifications { [prefix] notes in
            let ids = notes.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// 경계 목록을 받아 각 시점에 알림 예약. 같은 owner의 기존 예약만 먼저 지운다.
    func schedule(boundaries: [PhaseBoundary], ownerId: String) {
        let center = UNUserNotificationCenter.current()
        cancel(ownerId: ownerId)

        let now = Date()
        var index = 0
        for b in boundaries {
            guard index < maxPerOwner else { break }
            let interval = b.fireDate.timeIntervalSince(now)
            guard interval > 0.5 else { continue }   // 0.5초 이하 과거/현재는 스킵

            let content = UNMutableNotificationContent()
            content.sound = .default
            // 집중 모드/알림 요약에 묻히지 않고 즉시 소리·진동이 나도록 (entitlement 필요)
            content.interruptionLevel = .timeSensitive
            switch b.next {
            case .time(let set):
                content.title = "운동 시작 💪"
                content.body = "세트 \(set) — 운동을 시작하세요!"
            case .rest(let set):
                content.title = "휴식 시작 😮‍💨"
                content.body = "세트 \(set) 완료 — 잠시 쉬어요."
            case .pauseBeforeTime(let set):
                content.title = "휴식 끝 ⏸️"
                content.body = "재생을 누르면 세트 \(set) 운동을 시작해요."
            case .pauseBeforeRest(let set):
                content.title = "운동 끝 ⏸️"
                content.body = "세트 \(set) 완료 — 재생을 누르면 휴식을 시작해요."
            case .done:
                content.title = "운동 완료 ✅"
                content.body = "수고하셨어요! 모든 세트를 끝냈습니다."
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(ownerId: ownerId, index: index),
                                                content: content, trigger: trigger)
            center.add(request) { error in
                if let error { logger.e("notification add error \(error)") }
            }
            index += 1
        }
    }

    private func identifier(ownerId: String, index: Int) -> String {
        "\(prefix)\(ownerId).\(index)"
    }
}
