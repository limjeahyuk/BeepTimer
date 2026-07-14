//
//  WatchConnectivityManager.swift
//  BeepTimerWatch Watch App
//
//  아이폰에서 보내는 타이머 목록을 받는다. (워치는 편집하지 않고 골라서 실행만)
//  아이폰 타이머가 울릴 때는 비프 메시지를 받아 손목 햅틱을 함께 울린다.
//

import Foundation
import WatchConnectivity
import WatchKit

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var timers: [SyncTimer] = []
    @Published var autoMode: EngineAutoMode = .fullAuto
    /// 아이폰 전체 설정에서 받은 워치 공통 색상 (배경 / 운동 / 휴식)
    @Published var colors: WatchColors = .fallback

    /// 아이폰 타이머 미러링용 런타임 세션 — 아이폰 타이머가 도는 동안 잡아둬서
    /// 손목을 내려도(앱이 백그라운드여도) 비프 메시지를 계속 받아 햅틱을 울린다.
    private let mirrorRuntime = WatchRuntimeSession()

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
            self.colors = payload.watchColors
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

    /// 아이폰 타이머 미러링 메시지 (응답 없는 단방향)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let beep = message["beep"] as? String {
            DispatchQueue.main.async { self.playMirrorHaptic(beep) }
        }
        if let running = message["mirrorRunning"] as? Bool {
            DispatchQueue.main.async {
                if running {
                    self.mirrorRuntime.start()
                } else {
                    self.mirrorRuntime.stop()
                }
            }
        }
    }

    /// 아이폰 비프 종류 → 손목 햅틱 (워치 자체 실행 햅틱과 동일한 매핑)
    private func playMirrorHaptic(_ kind: String) {
        switch kind {
        case "tick":     WKInterfaceDevice.current().play(.click)
        case "phaseEnd": WKInterfaceDevice.current().play(.notification)
        case "complete": WKInterfaceDevice.current().play(.success)
        default: break
        }
    }
}
