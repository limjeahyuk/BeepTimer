//
//  TimerController.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI
import ActivityKit

enum TimerPhaseState {
    case running
    case paused
    case done
}

class TimerController: ObservableObject {
    // 현재 돌고 있는 시간 ( Time / Rest )
    enum Phase: Equatable {
        case time
        case rest
    }
    
    // 현재 상태
    enum State: Equatable {
        case idle
        case running(start: Date, end: Date)
        case paused(remainig: TimeInterval)
    }
    
    // config를 이용하여 설정
    @Published var timerTitle: String = "Beep Timer"
    @Published var timeSec: TimeInterval = 30
    @Published var restSec: TimeInterval = 15
    @Published var totalSets: Int = 3
    
    // 외부에서는 읽기만 가능.
    // state는 무조건 내부에서만 변경 가능.
    @Published private(set) var phase: Phase = .time
    @Published private(set) var setIndex: Int = 1
    @Published private(set) var state: State = .idle
    
    // 포그라운드 / 백그라운드 상태
    @Published var isInBackground: Bool = false
    
    var onStart: (() -> Void)?
    var onEnded: (() -> Void)?
    var onPhaseChanged: ((Phase, Int) -> Void)?
    
    // Dynamic
    var liveActivity: Activity<BeepTimerWidgetAttributes>?
    
    // phase에 맞춰서 설정되어있는 time
    func currentTotal() -> TimeInterval {
        phase == .time ? timeSec : restSec
    }
    
    // 초기화
    func configure(title: String, time: Int, rest: Int, sets: Int){
        timerTitle = title
        timeSec = TimeInterval(time)
        restSec = TimeInterval(rest)
        totalSets = sets
    }

    // 새로 시작 무조건 처음부터
    func start() {
        switch state {
        case .idle:
            setIndex = 1
            startPhase(timeSec)
            
            Task {
                await ensureLiveActivityCreated()
            }
        case .paused(let rem):
            resume(rem)
            
            Task {
                await ensureLiveActivityCreated()
            }
        case .running:
            break
        }
    }
    
    // 일시정지 : 남은 시간 저장
    func pause() {
        // running 일 때만 해당 함수 사용 가능.
        guard case .running(_, let end) = state else { return }
        // remaining 값 구하기 : 무조건 0 보다 높고 현재 Date와 end의 간격
        // timeIntervalSince : Date() - end
        let rem = max(0, end.timeIntervalSince(Date()))
        state = .paused(remainig: rem)
    }
    
    // 재시작.
    func resume(_ rem: TimeInterval) {
        let now = Date()
        // state 변경. running (지금 시간 부터 지금으로부터 남은 시간.)
        state = .running(start: now, end: now.addingTimeInterval(rem))
        
        // Live Activity 업데이트 (현재 phase 유지, endTime 갱신)
//        Task { await updateLiveActivityRunning(end: now.addingTimeInterval(rem)) }
    }
    
    // 멈추기
    func stop() {
        state = .idle
        phase = .time
        // Live Activity 종료
        Task { await endLiveActivity(immediate: true) }
    }
    
    // 현재 시각 기준 남은 시간 / 진행률
    // idle : 전체시각 ( 시작을 안했기 때문 )
    // running : end 시간 - 지금시각 (현재 돌고 있음)
    // paused : 저장 되어있는 remaing
    func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .idle:
            return timeSec
        case .running(_, let end):
            return max(0, end.timeIntervalSince(now))
        case .paused(let remaing):
            return max(0, remaing)
        }
    }
    
    func progress(at now: Date) -> CGFloat {
        let total = max(0.001, currentTotal())
        let rem = remaining(at: now)
        guard timeSec > 0 else { return 0 }
        return CGFloat(rem / total)
    }
    
    // 종료 체크
    func tryFireEndIfNeeded() {
        let now = Date()
        if case .running(_, let end) = state, now >= end {
            logger.d("tryFireEndIfNeeded running now \(now) end \(end)")
            advancePhase()
        }
    }
    
    func displayRemaing(at now: Date) -> Int {
        switch state {
        case .idle:
            return Int(ceil(timeSec))
        default:
            return Int(ceil(remaining(at: now)))
        }
    }
    
    func displayRemaining(at now: Date) -> Int {
        Int(ceil(remaining(at: now)))
    }
    
    // Time Lozic
    func startPhase(_ duration: TimeInterval) {
        let now = Date()
        // state 변경 및 시간 저장 / start & end
        state = .running(start: now, end: now.addingTimeInterval(duration))
        onPhaseChanged?(phase, setIndex)
    }
    
    // 핵심 로직. / 타이머 하나 끝날때 호출
    func advancePhase() {
        // 포그라운드 / 백그라운드에 따라 다른 행동.
        if isInBackground {
            handleBackgroundPhaseChange()
            return
        }
        
        handleForegroundPhaseChange()
    }
    
    // 백그라운드
    func handleBackgroundPhaseChange(){
        if phase == .time {
            phase = .rest
            state = .paused(remainig: restSec)
        } else { // rest
            if setIndex < totalSets {
                setIndex += 1
                phase = .time
                state = .paused(remainig: timeSec)
            } else {
                state = .idle
                phase = .time
                onEnded?()
            }
        }

        // Live Activity → 0초 + 체크로 고정
        Task { await markLiveActivityDone() }
    }
    
    // 포그라운드
    func handleForegroundPhaseChange(){
        if phase == .time {
            phase = .rest
            switch SettingManager.shared.autoMode {
            case .fullAuto, .setAuto:
                logger.d("autoMode .fullAuto")
                startPhase(restSec)
            case .manual:
                logger.d("autoMode .setAuto / .manual")
                state = .paused(remainig: restSec)
            }
        }else{
            if setIndex < totalSets {
                logger.d("advancePhase setIndex < total")
                setIndex += 1
                phase = .time
                switch SettingManager.shared.autoMode {
                case .fullAuto:
                    logger.d("autoMode .fullAuto")
                    startPhase(timeSec)
                case .setAuto, .manual:
                    logger.d("autoMode .setAuto / .manual")
                    state = .paused(remainig: timeSec)
                }
            }else{
                state = .idle
                phase = .time
                stop()
                onEnded?()
            }
        }
    }
    
    func goToSet(_ target: Int) -> Bool {
        let clamped = max(1, min(totalSets, target))
        guard clamped != setIndex || phase != .time else {
            startPhase(timeSec)
            return true
        }
        
        setIndex = clamped
        phase = .time
        startPhase(timeSec)
        return true
    }
    
    func previousSet() -> Bool {
        guard setIndex > 1 else { return false }
        setIndex -= 1
        phase = .time
        startPhase(timeSec)
        return true
    }
    
    func nextSet() -> Bool {
        guard setIndex < totalSets else {
            // 마지막 세트에서 더 못 올라감.
            // stop() & onEnded?()
            return false
        }
        setIndex += 1
        phase = .time
        startPhase(timeSec)
        return true
    }
    
    // 저장
    struct LastConfig: Codable {
        let title: String
        let time: Int
        let rest: Int
        let sets: Int
        let updatedAt: Date
    }

    let lastConfigKey = "TimerController.lastConfig.v1"

    // 저장
    func saveLastUsed() {
        let cfg = LastConfig(
            title: timerTitle,
            time: Int(timeSec),
            rest: Int(restSec),
            sets: totalSets,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: lastConfigKey)
        }
    }

    // 로드
    func loadLastUsed() -> LastConfig? {
        guard let data = UserDefaults.standard.data(forKey: lastConfigKey),
              let cfg = try? JSONDecoder().decode(LastConfig.self, from: data)
        else { return nil }
        return cfg
    }
    
}

extension TimerController {
    
    // scenePhase가 background로 갈 때 호출
    func syncLiveActivityForCurrentState() async {
        logger.d("syncLiveActivityForCurrentState called")
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        logger.d("syncLiveActivityForCurrentState called \(state)")
        
        switch state {
        case .running(_, let end):
            await updateLiveActivityRunning(end: end)
    
        case .paused(let remain):
            await updateLiveActivityPaused(remain: remain)

        case .idle:
            await endLiveActivity(immediate: true)
        }
    }
    
    @available(iOS 16.1, *)
    func ensureLiveActivityCreated() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 이미 LiveActivity 살아있으면 반환
        if let liveActivity,
           liveActivity.activityState == .active || liveActivity.activityState == .stale {
            return
        }

        // 여기서 한 번만 생성!
        await startLiveActivityFromCurrentState()
    }
    
    @available(iOS 16.1, *)
    func startLiveActivityFromCurrentState() async {
        logger.d("start Live Activity 생성")
        switch state {
        case .running(_, let end):
            await startLiveActivity(end: end)

        case .paused(let remain):
            let end = Date().addingTimeInterval(remain)
            await startLiveActivity(end: end)

        case .idle:
            break
        }
    }
    
    private func startLiveActivity(end: Date) async {
        guard #available(iOS 16.1, *) else { return }

        let attr = BeepTimerWidgetAttributes(title: timerTitle)
        let state = makeState(end: end, remain: nil)

        do {
            liveActivity = try Activity.request(
                attributes: attr,
                contentState: state,
                pushType: nil
            )
        } catch {
            print("LiveActivity request error: \(error)")
        }
    }

    private func updateLiveActivityRunning(end: Date) async {
        guard let liveActivity else { return }
        await liveActivity.update(using: makeState(end: end, remain: nil))
    }

    private func updateLiveActivityPaused(remain: TimeInterval) async {
        guard let liveActivity else { return }
        await liveActivity.update(using: makeState(end: Date(), remain: remain))
    }

    private func makeState(end: Date, remain: TimeInterval?) -> BeepTimerWidgetAttributes.ContentState {
        let statusString: String = {
            if let remain = remain, remain <= 0 {
                return "done"
            }
            
            if case .paused = state {
                return "paused"
            }
            
            return "running"
        }()
        
        logger.d("make State \(state)")
        return BeepTimerWidgetAttributes.ContentState(
            phase: phaseString(),
            status: statusString,
            endTime: end,
            remainSec: remain != nil ? Int(ceil(remain!)) : nil,
            setIndex: setIndex,
            totalSets: totalSets
        )
    }

    private func phaseString() -> String {
        return phase == .rest ? "rest" : "time"
    }

    fileprivate func markLiveActivityDone() async {
        guard let liveActivity else { return }
        
        logger.d("liveActivity Done \(phaseString())")

        let state = BeepTimerWidgetAttributes.ContentState(
            phase: phaseString(),
            status: "done",
            endTime: Date(),
            remainSec: 0,
            setIndex: setIndex,
            totalSets: totalSets
        )

        await liveActivity.update(using: state)
    }

    fileprivate func endLiveActivity(immediate: Bool) async {
        guard let liveActivity else { return }
        await liveActivity.end(dismissalPolicy: immediate ? .immediate : .default)
        self.liveActivity = nil
    }
}

extension TimerController {
    var phaseStatusForUI: TimerPhaseState {
        switch state {
        case .running(_, _):
            return .running
        case .paused(let rem):
            return rem <= 0 ? .done : .paused
        case .idle:
            return .paused
        }
    }
}
