//
//  PhoneConnectivity.swift
//  BeepTimer
//
//  아이폰 → 워치 타이머 목록 동기화 (한 방향).
//  최신 목록을 App Context로 보내고, 워치가 요청하면 메시지로도 응답한다.
//

import Foundation
import WatchConnectivity
import RealmSwift

final class PhoneConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivity()

    private var latest: SyncPayload?

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    // MARK: 실시간 미러링 — 아이폰 비프가 울릴 때 워치 햅틱도 함께

    /// 아이폰에서 비프가 울리는 순간 워치로 전달해 손목 햅틱을 울린다.
    /// 워치 앱이 켜져 있거나(포그라운드) 런타임 세션이 살아있을 때만 도달한다.
    /// kind: "tick"(3·2·1) | "phaseEnd"(페이즈 종료) | "complete"(전체 완료)
    func sendBeep(_ kind: String) {
        let s = WCSession.default
        guard WCSession.isSupported(), s.activationState == .activated, s.isReachable else { return }
        s.sendMessage(["beep": kind], replyHandler: nil, errorHandler: nil)
    }

    private var lastMirrorRunning: Bool?

    /// 아이폰 타이머 실행 여부를 워치에 알린다.
    /// 워치는 실행 중일 때 확장 런타임 세션을 잡아 손목을 내려도 햅틱을 계속 받는다.
    func sendTimerRunning(_ running: Bool) {
        guard lastMirrorRunning != running else { return }
        let s = WCSession.default
        guard WCSession.isSupported(), s.activationState == .activated, s.isReachable else { return }
        lastMirrorRunning = running
        s.sendMessage(["mirrorRunning": running], replyHandler: nil, errorHandler: nil)
    }

    /// 현재 타이머 목록을 워치로 보낸다. (프로그램 변경 시 호출)
    func sync(programs: [RTimerProgram], autoModeRaw: Int) {
        let timers = programs.map { Self.syncTimer(from: $0) }
        let payload = SyncPayload(timers: timers, autoModeRaw: autoModeRaw, updatedAt: Date())
        latest = payload
        push(payload)
    }

    private func push(_ payload: SyncPayload) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated else { return }   // 활성화되면 다시 보냄
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? s.updateApplicationContext(["payload": data])
    }

    // MARK: 변환

    static func syncTimer(from p: RTimerProgram) -> SyncTimer {
        let model = p.toModel()
        let id = p._id.stringValue

        if model.isCustom {
            let steps = model.steps.map {
                SyncStep(title: $0.title ?? "", isRest: $0.kind == .rest, seconds: $0.seconds)
            }
            let time = model.steps.first { $0.kind == .time }?.seconds ?? 30
            let rest = model.steps.first { $0.kind == .rest }?.seconds ?? 0
            let sets = max(1, model.steps.filter { $0.kind == .time }.count)
            return SyncTimer(id: id, title: model.title, timeSec: time, restSec: rest,
                             totalSets: sets, steps: steps,
                             timeColorHex: model.timeColorHex, restColorHex: model.restColorHex)
        }

        let trs = model.asTimeRestSets()
        let time = trs?.time ?? 30
        let rest = trs?.rest ?? 0
        let sets = model.infiniteSets ? Int.max : max(1, trs?.sets ?? 1)
        return SyncTimer(id: id, title: model.title, timeSec: time, restSec: rest,
                         totalSets: sets, steps: [],
                         timeColorHex: model.timeColorHex, restColorHex: model.restColorHex)
    }

    /// Realm의 전체 프로그램을 다시 읽어 워치로 재전송한다. (색 등 변경 즉시 반영용)
    func resyncFromRealm(autoModeRaw: Int) {
        guard let realm = try? Realm() else { return }
        let programs = Array(realm.objects(RTimerProgram.self))
        sync(programs: programs, autoModeRaw: autoModeRaw)
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated, let latest { push(latest) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// 워치 앱이 열리거나 닫힐 때: 다음 상태 갱신에서 실행 여부를 다시 보내도록 리셋
    /// (타이머 도중에 워치 앱을 열어도 런타임 세션을 잡을 수 있게)
    func sessionReachabilityDidChange(_ session: WCSession) {
        lastMirrorRunning = nil
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()   // 워치 전환 후 재활성화
    }

    /// 워치가 최신 목록을 직접 요청 (앱 첫 실행/재설치 대비)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let latest, let data = try? JSONEncoder().encode(latest) {
            replyHandler(["payload": data])
        } else {
            replyHandler([:])
        }
    }
}
