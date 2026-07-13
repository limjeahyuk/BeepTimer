//
//  TimerEngine.swift
//  BeepTimer
//
//  플랫폼 독립 타이머 코어.
//  ActivityKit / WidgetKit / UIKit에 의존하지 않으므로 iOS와 watchOS가 함께 사용한다.
//  소리·햅틱·알림·라이브액티비티 같은 부수효과는 여기서 처리하지 않고
//  Event로 밖에 넘겨, 각 플랫폼이 원하는 방식으로 반응하게 한다.
//    - iOS: 소리 + 시스템 햅틱
//    - watchOS: 손목 햅틱
//

import Foundation

// MARK: - 설정 / 상태 값

public enum EnginePhase: Equatable {
    case time
    case rest
}

public enum EngineRunState: Equatable {
    case idle
    case running(start: Date, end: Date)
    case paused(remaining: TimeInterval)
}

/// 자동 진행 규칙 (SettingManager.AutoPlayMode와 동일한 의미)
public enum EngineAutoMode: Int {
    case fullAuto = 0   // 세트가 끝날 때까지 자동
    case setAuto = 1    // 한 세트 끝나면 멈춤
    case manual = 2     // 각 단계 끝나면 멈춤
}

/// 상세(커스텀) 모드의 한 단계
public struct EngineStep: Equatable {
    public var title: String
    public var isRest: Bool
    public var seconds: TimeInterval

    public init(title: String, isRest: Bool, seconds: TimeInterval) {
        self.title = title
        self.isRest = isRest
        self.seconds = seconds
    }
}

/// 엔진 구성 (단순 반복 or 상세 단계)
public struct EngineConfig: Equatable {
    public var title: String
    public var timeSec: TimeInterval
    public var restSec: TimeInterval
    public var totalSets: Int
    public var steps: [EngineStep]   // 비어있으면 단순 반복 모드

    public static let infiniteSets = Int.max

    public var isCustom: Bool { !steps.isEmpty }
    public var isInfiniteSets: Bool { totalSets == Self.infiniteSets }

    public init(title: String,
                timeSec: TimeInterval,
                restSec: TimeInterval,
                totalSets: Int,
                steps: [EngineStep] = []) {
        self.title = title
        self.timeSec = timeSec
        self.restSec = restSec
        self.totalSets = totalSets
        self.steps = steps
    }
}

/// 엔진이 밖으로 보내는 사건. 호스트가 소리/햅틱/알림으로 반응한다.
public enum EngineEvent: Equatable {
    case countdownTick(remaining: Int)  // 3, 2, 1
    case phaseEnded(EnginePhase)        // 한 페이즈(Time/Rest) 종료 — 마지막 완료는 제외
    case advanced(phase: EnginePhase, setIndex: Int)  // 다음 페이즈로 자동 진행됨
    case pausedAtBoundary(phase: EnginePhase, setIndex: Int)  // 경계에서 자동 진행하지 않고 멈춤
    case finished                        // 모든 세트/단계 완료
}

// MARK: - 엔진

/// 순수 상태 기계. UI 프레임워크에 의존하지 않으며, tick()을 주기적으로 불러 진행시킨다.
public final class TimerEngine {

    public private(set) var config: EngineConfig
    public private(set) var autoMode: EngineAutoMode

    public private(set) var phase: EnginePhase = .time
    public private(set) var setIndex: Int = 1
    public private(set) var stepIndex: Int = 0
    public private(set) var state: EngineRunState = .idle

    /// 부수효과를 밖으로 흘려보내는 채널. 호스트가 붙인다.
    public var onEvent: ((EngineEvent) -> Void)?

    private var beepedSeconds: Set<Int> = []
    private var lastBeepEndTime: Date?

    public init(config: EngineConfig, autoMode: EngineAutoMode) {
        self.config = config
        self.autoMode = autoMode
        resetPosition()
    }

    public var isCustomMode: Bool { config.isCustom }
    public var isInfiniteSets: Bool { config.isInfiniteSets }

    /// 무한 반복이면 fullAuto는 setAuto로 강등 (방치 시 끝없이 돌지 않게)
    private var effectiveAutoMode: EngineAutoMode {
        if isInfiniteSets, autoMode == .fullAuto { return .setAuto }
        return autoMode
    }

    // MARK: 구성 변경

    public func update(config: EngineConfig) {
        self.config = config
        reset()
    }

    public func update(autoMode: EngineAutoMode) {
        self.autoMode = autoMode
    }

    private func reset() {
        resetPosition()
        state = .idle
        beepedSeconds.removeAll()
        lastBeepEndTime = nil
    }

    /// 첫 단계 기준으로 phase/setIndex/stepIndex를 되돌린다.
    /// 커스텀 모드에서 첫 단계가 휴식이면 idle에도 휴식 색·라벨이 나와야 한다.
    private func resetPosition() {
        setIndex = 1
        stepIndex = 0
        phase = (config.isCustom && config.steps.first?.isRest == true) ? .rest : .time
    }

    // MARK: 조회

    /// 현재 페이즈의 전체 길이
    public func currentTotal() -> TimeInterval {
        if isCustomMode, stepIndex < config.steps.count {
            return config.steps[stepIndex].seconds
        }
        return phase == .time ? config.timeSec : config.restSec
    }

    public var phaseLabel: String {
        if isCustomMode, stepIndex < config.steps.count {
            let t = config.steps[stepIndex].title
            if !t.isEmpty { return t }
        }
        return phase == .time ? "Time" : "Rest"
    }

    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .idle:
            return currentTotal()
        case .running(_, let end):
            return max(0, end.timeIntervalSince(now))
        case .paused(let rem):
            return max(0, rem)
        }
    }

    public func displayRemaining(at now: Date) -> Int {
        Int(ceil(remaining(at: now)))
    }

    public func progress(at now: Date) -> Double {
        let total = max(0.001, currentTotal())
        return remaining(at: now) / total
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// 모든 세트/단계를 마친 완료(00:00) 상태인가
    public var isFinished: Bool {
        guard case .paused(let rem) = state, rem <= 0 else { return false }
        if isCustomMode { return stepIndex >= config.steps.count - 1 }
        return phase == .rest && setIndex >= config.totalSets
    }

    /// 이 페이즈가 끝나면 전체 완료가 되는가 (완료 전용 사운드 분기용)
    private var isOnFinalPhase: Bool {
        if isCustomMode { return stepIndex >= config.steps.count - 1 }
        return phase == .rest && setIndex >= config.totalSets
    }

    // MARK: 제어

    public func start() {
        if isFinished { state = .idle; phase = .time }
        switch state {
        case .idle:
            setIndex = 1
            if isCustomMode {
                syncCustomPhase(at: 0)
                startPhase(config.steps[0].seconds)
            } else {
                phase = .time
                startPhase(config.timeSec)
            }
        case .paused(let rem):
            resume(rem)
        case .running:
            break
        }
    }

    public func toggle() {
        switch state {
        case .running:
            pause()
        case .paused(let rem):
            if isFinished { start() } else { resume(rem) }
        case .idle:
            start()
        }
    }

    public func pause() {
        guard case .running(_, let end) = state else { return }
        state = .paused(remaining: max(0, end.timeIntervalSince(Date())))
    }

    public func resume(_ rem: TimeInterval) {
        let now = Date()
        state = .running(start: now, end: now.addingTimeInterval(rem))
    }

    public func stop() {
        state = .idle
        resetPosition()
    }

    /// 다음 세트/단계로 수동 이동. 마지막이면 false.
    @discardableResult
    public func nextSet() -> Bool {
        if isCustomMode {
            guard stepIndex + 1 < config.steps.count else { return false }
            syncCustomPhase(at: stepIndex + 1)
            startPhase(config.steps[stepIndex].seconds)
            return true
        }
        guard setIndex < config.totalSets else { return false }
        setIndex += 1
        phase = .time
        startPhase(config.timeSec)
        return true
    }

    private func startPhase(_ duration: TimeInterval) {
        beepedSeconds.removeAll()
        let now = Date()
        state = .running(start: now, end: now.addingTimeInterval(duration))
    }

    private func syncCustomPhase(at index: Int) {
        guard index < config.steps.count else { return }
        stepIndex = index
        phase = config.steps[index].isRest ? .rest : .time
        let ordinal = config.steps[0...index].filter { !$0.isRest }.count
        setIndex = max(1, ordinal)
    }

    // MARK: 진행 (주기적으로 호출)

    /// 호스트가 0.1~0.2초마다 부른다. 카운트다운 비프와 페이즈 종료를 처리한다.
    public func tick(at now: Date = Date()) {
        guard case .running(_, let end) = state else { return }
        emitBeepsIfNeeded(displayRemaining: displayRemaining(at: now), endTime: end)
        if now >= end { advancePhase() }
    }

    private func emitBeepsIfNeeded(displayRemaining: Int, endTime: Date) {
        if lastBeepEndTime != endTime {
            lastBeepEndTime = endTime
            beepedSeconds.removeAll()
        }
        guard !beepedSeconds.contains(displayRemaining) else { return }
        beepedSeconds.insert(displayRemaining)

        switch displayRemaining {
        case 1, 2, 3:
            onEvent?(.countdownTick(remaining: displayRemaining))
        case 0:
            // 마지막 페이즈의 0초는 finished 이벤트에서 완료 신호로 처리
            if !isOnFinalPhase { onEvent?(.phaseEnded(phase)) }
        default:
            break
        }
    }

    /// 현재 페이즈가 끝났을 때: autoMode 규칙대로 다음으로 넘어가거나 멈춘다.
    private func advancePhase() {
        if isCustomMode {
            let next = stepIndex + 1
            if next < config.steps.count {
                let ended = phase
                syncCustomPhase(at: next)
                let autoStart: Bool
                switch autoMode {
                case .fullAuto: autoStart = true
                case .setAuto:  autoStart = ended == .time
                case .manual:   autoStart = false
                }
                if autoStart {
                    startPhase(config.steps[next].seconds)
                    onEvent?(.advanced(phase: phase, setIndex: setIndex))
                } else {
                    state = .paused(remaining: config.steps[next].seconds)
                    onEvent?(.pausedAtBoundary(phase: phase, setIndex: setIndex))
                }
            } else {
                finish()
            }
            return
        }

        if phase == .time {
            phase = .rest
            switch effectiveAutoMode {
            case .fullAuto, .setAuto:
                startPhase(config.restSec)
                onEvent?(.advanced(phase: .rest, setIndex: setIndex))
            case .manual:
                state = .paused(remaining: config.restSec)
                onEvent?(.pausedAtBoundary(phase: .rest, setIndex: setIndex))
            }
        } else {
            if setIndex < config.totalSets {
                setIndex += 1
                phase = .time
                switch effectiveAutoMode {
                case .fullAuto:
                    startPhase(config.timeSec)
                    onEvent?(.advanced(phase: .time, setIndex: setIndex))
                case .setAuto, .manual:
                    state = .paused(remaining: config.timeSec)
                    onEvent?(.pausedAtBoundary(phase: .time, setIndex: setIndex))
                }
            } else {
                finish()
            }
        }
    }

    private func finish() {
        state = .paused(remaining: 0)
        onEvent?(.finished)
    }
}
