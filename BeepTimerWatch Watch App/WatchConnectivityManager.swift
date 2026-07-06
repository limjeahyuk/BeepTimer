//
//  WatchConnectivityManager.swift
//  BeepTimerWatch Watch App
//
//  아이폰에서 보내는 타이머 목록을 받는다. (워치는 편집하지 않고 골라서 실행만)
//

import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var timers: [SyncTimer] = []
    @Published var autoMode: EngineAutoMode = .fullAuto

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    /// 아이폰에 최신 목록을 직접 요청 (첫 실행/재설치 대비)
    func requestTimers() {
        let s = WCSession.default
        guard s.activationState == .activated, s.isReachable else { return }
        s.sendMessage(["request": "timers"], replyHandler: { [weak self] reply in
            self?.apply(reply)
        }, errorHandler: nil)
    }

    private func apply(_ dict: [String: Any]) {
        guard let data = dict["payload"] as? Data,
              let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) else { return }
        DispatchQueue.main.async {
            self.timers = payload.timers
            self.autoMode = EngineAutoMode(rawValue: payload.autoModeRaw) ?? .fullAuto
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // 활성화 시 마지막으로 받은 컨텍스트를 반영하고, 최신본을 한 번 요청
        apply(session.receivedApplicationContext)
        requestTimers()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }
}
