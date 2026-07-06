//
//  WatchRuntimeSession.swift
//  BeepTimerWatch Watch App
//
//  타이머가 도는 동안 손목을 내려도 진행/햅틱이 이어지도록 확장 런타임 세션을 유지한다.
//  세션 시작이 실패하거나 만료되면 조용히 정리한다 (포그라운드에서는 타이머가 그대로 동작).
//

import WatchKit

final class WatchRuntimeSession: NSObject, WKExtendedRuntimeSessionDelegate {

    private var session: WKExtendedRuntimeSession?

    func start() {
        guard session == nil else { return }
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        session = s
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    // MARK: WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        session = nil
    }
}
