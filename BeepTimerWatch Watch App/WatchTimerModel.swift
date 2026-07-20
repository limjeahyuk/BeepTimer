//
//  WatchTimerModel.swift
//  BeepTimerWatch Watch App
//
//  공용 TimerEngine을 구동하고, 엔진 이벤트를 손목 햅틱으로 바꾼다.
//  타이머가 도는 동안엔 확장 런타임 세션으로 백그라운드에서도 진행되게 한다.
//

import SwiftUI
import WatchKit
import Combine

final class WatchTimerModel: ObservableObject {

    let engine: TimerEngine

    // 화면 표시용 상태
    @Published var remaining: Int = 0
    @Published var progress: Double = 1        // 남은 비율 (1 → 0)
    @Published var isRunning: Bool = false
    @Published var phaseLabel: String = "Time"
    @Published var isRest: Bool = false
    @Published var setIndex: Int = 1
    @Published var totalSets: Int = 1
    @Published var isInfinite: Bool = false
    @Published var finished: Bool = false

    private var ticker: Timer?
    private let runtime = WatchWorkoutSession.shared

    init(config: EngineConfig, autoMode: EngineAutoMode) {
        engine = TimerEngine(config: config, autoMode: autoMode)
        engine.onEvent = { [weak self] event in self?.handle(event) }
        refresh()
    }

    /// 다른 타이머로 교체 (실행 중이면 멈추고 처음부터)
    func configure(_ config: EngineConfig, autoMode: EngineAutoMode) {
        stopTicker()
        runtime.stop()
        engine.update(config: config)
        engine.update(autoMode: autoMode)
        refresh()
    }

    /// 화면을 벗어날 때 정리
    func teardown() {
        stopTicker()
        runtime.stop()
    }

    // MARK: 제어

    func toggle() {
        engine.toggle()
        WKInterfaceDevice.current().play(.click)
        syncRunLoop()
        refresh()
    }

    func next() {
        guard engine.nextSet() else { return }
        WKInterfaceDevice.current().play(.start)
        syncRunLoop()
        refresh()
    }

    func stopAndReset() {
        engine.stop()
        WKInterfaceDevice.current().play(.stop)
        syncRunLoop()
        refresh()
    }

    // MARK: 엔진 이벤트 → 손목 햅틱

    private func handle(_ event: EngineEvent) {
        switch event {
        case .countdownTick:
            WKInterfaceDevice.current().play(.click)        // 3·2·1 톡톡
        case .phaseEnded:
            WKInterfaceDevice.current().play(.notification) // 페이즈 종료
        case .advanced:
            WKInterfaceDevice.current().play(.start)        // 다음 페이즈 자동 시작
        case .pausedAtBoundary:
            WKInterfaceDevice.current().play(.stop)         // 경계에서 멈춤
            syncRunLoop()
        case .finished:
            WKInterfaceDevice.current().play(.success)      // 전체 완료
            syncRunLoop()
        }
        refresh()
    }

    // MARK: 진행 루프 / 백그라운드 세션

    private func syncRunLoop() {
        if engine.isRunning {
            startTicker()
            runtime.start()
        } else {
            stopTicker()
            runtime.stop()
        }
    }

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.engine.tick()   // 필요 시 이벤트(햅틱) 발생
            self.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func refresh(at now: Date = Date()) {
        remaining = engine.displayRemaining(at: now)
        progress = max(0, min(1, engine.progress(at: now)))
        isRunning = engine.isRunning
        phaseLabel = engine.phaseLabel
        isRest = engine.phase == .rest
        setIndex = engine.setIndex
        totalSets = engine.config.totalSets
        isInfinite = engine.config.isInfiniteSets
        finished = engine.isFinished
    }
}
