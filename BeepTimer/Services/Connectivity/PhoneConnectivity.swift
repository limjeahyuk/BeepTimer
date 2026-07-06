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
