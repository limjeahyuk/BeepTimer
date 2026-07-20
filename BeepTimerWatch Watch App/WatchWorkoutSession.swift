//
//  WatchWorkoutSession.swift
//  BeepTimerWatch Watch App
//
//  타이머가 도는 동안 HealthKit 운동 세션을 잡아, 손목을 내리거나 다른 앱을 열어도
//  진행과 햅틱이 이어지게 한다. (Info.plist의 workout-processing 백그라운드 모드)
//
//  운동 앱의 정석 방식이라 세션 유지가 보장되고, 끝나면 운동 기록도 건강 앱에 남는다.
//  워치 자체 타이머와 아이폰 미러링이 동시에 세션을 잡으면 충돌하므로 싱글턴으로 하나만 유지한다.
//

import Foundation
import HealthKit

final class WatchWorkoutSession: NSObject {

    static let shared = WatchWorkoutSession()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private override init() { super.init() }

    /// 최초 1회 권한 요청 — 결과와 무관하게 타이머는 그대로 동작한다(세션만 못 잡을 뿐).
    func requestAuthorizationIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { _, error in
            if let error { print("healthkit auth error: \(error)") }
        }
    }

    /// 운동 세션 시작 — 이미 잡혀 있으면 아무것도 하지 않는다.
    func start() {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .highIntensityIntervalTraining   // 인터벌 타이머 성격에 맞춘 분류
        config.locationType = .indoor

        do {
            let s = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                   workoutConfiguration: config)
            s.delegate = self
            b.delegate = self

            let startDate = Date()
            s.startActivity(with: startDate)
            b.beginCollection(withStart: startDate) { _, _ in }

            session = s
            builder = b
        } catch {
            // 권한 거부 등으로 실패하면 조용히 포기 — 포그라운드에서는 타이머가 그대로 동작한다.
            session = nil
            builder = nil
        }
    }

    /// 운동 세션 종료 — 수집한 기록을 저장하고 정리한다.
    func stop() {
        guard let s = session else { return }
        session = nil

        let endDate = Date()
        s.end()
        builder?.endCollection(withEnd: endDate) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in
                self?.builder = nil
            }
        }
    }
}

// MARK: HKWorkoutSessionDelegate

extension WatchWorkoutSession: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        session = nil
        builder = nil
    }
}

// MARK: HKLiveWorkoutBuilderDelegate
// 실시간 수집 자체는 데이터 소스가 처리한다 — 화면에 심박수를 띄우지 않으므로 본문은 비워 둔다.

extension WatchWorkoutSession: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}
