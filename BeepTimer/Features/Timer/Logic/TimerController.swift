//
//  TimerController.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI
import UIKit
import ActivityKit
import WidgetKit

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
    /// totalSets에 이 값이 들어가면 세트 무한 반복 (세트가 끝나지 않는다)
    static let infiniteSets = Int.max

    @Published var timerTitle: String = "Beep Timer"
    @Published var timeSec: TimeInterval = 30
    @Published var restSec: TimeInterval = 15
    @Published var totalSets: Int = 3

    var isInfiniteSets: Bool { totalSets == Self.infiniteSets }

    /// 무한 반복이면 전체 자동(fullAuto)은 사용 불가 — 방치 시 끝없이 돌지 않도록
    /// 세트 경계에서 멈추는 setAuto로 강등한다.
    private var effectiveAutoMode: AutoPlayMode {
        let mode = SettingManager.shared.autoMode
        if isInfiniteSets, mode == .fullAuto { return .setAuto }
        return mode
    }

    // MARK: 상세(커스텀) 모드 — 단계 배열을 순서대로 진행
    struct CustomStep: Equatable {
        var title: String          // 단계 이름 (비어있으면 Time/Rest로 표시)
        var isRest: Bool
        var seconds: TimeInterval
    }
    @Published private(set) var customSteps: [CustomStep] = []
    @Published private(set) var stepIndex: Int = 0
    var isCustomMode: Bool { !customSteps.isEmpty }

    /// 원 안에 표시할 페이즈 라벨 (커스텀 모드면 단계 이름)
    var phaseLabel: String {
        if isCustomMode, stepIndex < customSteps.count {
            let t = customSteps[stepIndex].title
            if !t.isEmpty { return t }
        }
        return phase == .time ? "Time" : "Rest"
    }
    
    // 외부에서는 읽기만 가능.
    // state는 무조건 내부에서만 변경 가능.
    @Published private(set) var phase: Phase = .time
    @Published private(set) var setIndex: Int = 1
    @Published private(set) var state: State = .idle

    /// 전체 세트 완료 팝업 표시 여부 (탭하면 닫힘)
    @Published var showCompletionPopup = false
    
    // 포그라운드 / 백그라운드 상태
    @Published var isInBackground: Bool = false {
        didSet {
            guard oldValue != isInBackground else { return }
            // 백그라운드 진입 직후 ~30초(시스템 허용 시간) 동안 프로세스를 살려두어
            // 마지막 5초 링 색 전환·페이즈 경계의 Live Activity 갱신이 가능하게 한다.
            if isInBackground {
                beginBackgroundKeepAlive()
            } else {
                endBackgroundKeepAlive()
            }
        }
    }

    /// Live Activity 갱신용 백그라운드 keep-alive 태스크
    private var bgKeepAlive: UIBackgroundTaskIdentifier = .invalid

    private func beginBackgroundKeepAlive() {
        guard bgKeepAlive == .invalid, case .running = state else { return }
        bgKeepAlive = UIApplication.shared.beginBackgroundTask(withName: "BeepTimer.LiveActivityUpdate") { [weak self] in
            self?.endBackgroundKeepAlive()
        }
    }

    private func endBackgroundKeepAlive() {
        guard bgKeepAlive != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgKeepAlive)
        bgKeepAlive = .invalid
    }
    
    var onStart: (() -> Void)?
    var onEnded: (() -> Void)?
    var onPhaseChanged: ((Phase, Int) -> Void)?
    /// Time/Rest 페이즈가 끝날 때마다 호출 (마지막 세트 완료는 onEnded로만 알림)
    var onPhaseEnded: ((Phase) -> Void)?
    
    // Dynamic
    var liveActivity: Activity<BeepTimerWidgetAttributes>?

    // 위젯(잠금화면/다이나믹 아일랜드) 버튼이 앱 프로세스에서 찾는 기본 인스턴스
    static let shared: TimerController = {
        let c = TimerController()
        c.ownerId = "shared"
        return c
    }()

    /// 알림·Live Activity의 소유자 식별자 — 컨트롤러끼리 서로의 예약/활동을 건드리지 않게 한다.
    /// 저장된 프로그램은 프로그램 id, 기본 타이머는 "shared"로 고정해
    /// 앱 프로세스가 재시작돼도 자기 알림/활동을 다시 찾을 수 있다.
    var ownerId: String = UUID().uuidString {
        didSet { TimerWidgetActionBus.register(self, ownerId: ownerId) }
    }

    // 타이머(프로그램)마다 별도 인스턴스를 만들 수 있다.
    // 위젯 버튼은 눌린 Live Activity의 ownerId로 라우팅되고,
    // ownerId 없는 옛 활동은 가장 최근에 시작된 컨트롤러로 간다 (start() 참고).
    init() {
        if TimerWidgetActionBus.handler == nil {
            TimerWidgetActionBus.handler = self
        }
        TimerWidgetActionBus.register(self, ownerId: ownerId)
    }

    private var beeped: Set<Int> = []   // 3,2,1 중복 방지
    private var didEndBeep = false      // 0초(끝) 중복 방지
    private var lastBeepEndTime: Date? = nil

    // 화면 밖(다른 페이지)에서도 진행/비프가 동작하도록 하는 내부 티커.
    // 보이는 페이지의 TimelineView와 중복 호출돼도 beeped/state 가드로 안전하다.
    private var ticker: Timer?

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tickerFired()
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
        // 백그라운드 상태에서 시작(LA 버튼으로 재개 등)해도 LA 갱신이 가능하게
        if isInBackground { beginBackgroundKeepAlive() }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tickerFired() {
        guard case .running(_, let end) = state else { return }
        // 소리는 포그라운드에서만 (백그라운드 소리는 예약 알림이 담당)
        if !isInBackground {
            handleBeepIfNeeded(displayRemaining: displayRemaining(at: Date()), endTime: end)
        }
        // 마지막 5초: LA 링을 빨간색으로 바꾸는 업데이트 전송
        // (백그라운드에서는 keep-alive가 살아있는 동안만 동작하고, 그 뒤는 복귀 catchUp이 담당)
        sendEndingSoonUpdateIfNeeded(end: end)
        tryFireEndIfNeeded()
    }

    /// 페이즈당 한 번, 남은 시간이 5초에 도달하면 Live Activity를 갱신해
    /// endingSoon(빨간 링) 상태를 반영한다.
    private var endingSoonNotifiedEnd: Date?
    private func sendEndingSoonUpdateIfNeeded(end: Date) {
        guard end.timeIntervalSinceNow <= 5, endingSoonNotifiedEnd != end else { return }
        endingSoonNotifiedEnd = end
        guard #available(iOS 16.1, *) else { return }
        Task { await syncLiveActivityForCurrentState() }
    }
    
    var currentEndTime: Date? {
        if case .running(_, let end) = state { return end }
        return nil
    }
    
    // phase에 맞춰서 설정되어있는 time
    func currentTotal() -> TimeInterval {
        if isCustomMode, stepIndex < customSteps.count {
            return customSteps[stepIndex].seconds
        }
        return phase == .time ? timeSec : restSec
    }
    
    // 초기화 (단순 반복 모드)
    func configure(title: String, time: Int, rest: Int, sets: Int){
        timerTitle = title
        timeSec = TimeInterval(time)
        restSec = TimeInterval(rest)
        totalSets = sets
        customSteps = []
        stepIndex = 0
        publishWidgetSnapshot()
    }

    // 초기화 (상세 모드) — 단계를 순서대로 진행한다. (autoMode 규칙대로 경계에서 멈춤)
    // loops = true면 마지막 단계 후 첫 단계로 돌아가 무한 반복한다 (totalSets = infiniteSets)
    func configureCustom(title: String, steps: [CustomStep], loops: Bool = false) {
        timerTitle = title
        customSteps = steps
        stepIndex = 0
        // 위젯/요약 표시용 대푯값
        timeSec = steps.first(where: { !$0.isRest })?.seconds ?? 30
        restSec = steps.first(where: { $0.isRest })?.seconds ?? 0
        totalSets = loops ? Self.infiniteSets : max(1, steps.filter { !$0.isRest }.count)
        publishWidgetSnapshot()
    }

    /// 커스텀 모드: index 단계 기준 phase/setIndex 동기화
    private func syncCustomPhase(at index: Int) {
        guard index < customSteps.count else { return }
        stepIndex = index
        phase = customSteps[index].isRest ? .rest : .time
        // setIndex = 현재까지 지나온 운동(time) 단계 개수 (표시용)
        let ordinal = customSteps[0...index].filter { !$0.isRest }.count
        setIndex = max(1, ordinal)
    }

    /// 현재 설정/상태를 App Group에 저장하고 홈 화면 위젯 타임라인을 갱신한다.
    func publishWidgetSnapshot() {
        let snapshot: TimerWidgetSnapshot
        switch state {
        case .idle:
            snapshot = TimerWidgetSnapshot(
                title: timerTitle, time: Int(timeSec), rest: Int(restSec), sets: totalSets,
                isActive: false, phaseIsRest: false, setIndex: 1,
                endTime: nil, isPaused: false, pausedRemain: nil
            )
        case .running(let start, let end):
            snapshot = TimerWidgetSnapshot(
                title: timerTitle, time: Int(timeSec), rest: Int(restSec), sets: totalSets,
                isActive: true, phaseIsRest: phase == .rest, setIndex: setIndex,
                startTime: start, endTime: end, isPaused: false, pausedRemain: nil
            )
        case .paused(let rem):
            snapshot = TimerWidgetSnapshot(
                title: timerTitle, time: Int(timeSec), rest: Int(restSec), sets: totalSets,
                isActive: true, phaseIsRest: phase == .rest, setIndex: setIndex,
                endTime: nil, isPaused: true, pausedRemain: Int(ceil(max(0, rem)))
            )
        }
        TimerWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // 새로 시작 무조건 처음부터
    func start() {
        // Live Activity / 위젯 버튼이 가장 최근에 시작한 타이머를 조작하도록 등록
        TimerWidgetActionBus.handler = self
        showCompletionPopup = false
        // 완료(00:00) 상태에서 다시 시작하면 처음부터
        if isFinished {
            state = .idle
            phase = .time
        }
        switch state {
        case .idle:
            setIndex = 1
            if SettingManager.shared.phaseAlarmEnabled {
                NotificationService.shared.requestAuthorizationIfNeeded()
            }
            if isCustomMode {
                syncCustomPhase(at: 0)
                startPhase(customSteps[0].seconds)
            } else {
                startPhase(timeSec)
            }

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
    
    // 재생 ↔ 일시정지 토글 (원 탭 / Live Activity 버튼 공용)
    func toggle() {
        switch state {
        case .running:
            pause()
        case .paused(let rem):
            // 완료(00:00) 상태면 처음부터 재시작
            if isFinished {
                start()
            } else {
                resume(rem)
            }
        case .idle:
            start()
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
        stopTicker()
        refreshLiveActivity()
    }

    // 재시작.
    func resume(_ rem: TimeInterval) {
        let now = Date()
        // state 변경. running (지금 시간 부터 지금으로부터 남은 시간.)
        state = .running(start: now, end: now.addingTimeInterval(rem))
        startTicker()
        // Live Activity 업데이트 (현재 phase 유지, endTime 갱신)
        refreshLiveActivity()
    }

    /// 현재 상태를 Live Activity에 반영한다. (이미 생성돼 있을 때만 업데이트)
    func refreshLiveActivity() {
        publishWidgetSnapshot()
        guard #available(iOS 16.1, *) else { return }
        Task { await syncLiveActivityForCurrentState() }
    }

    // 멈추기
    func stop() {
        showCompletionPopup = false
        state = .idle
        phase = .time
        stopTicker()
        publishWidgetSnapshot()
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
        // 현재 페이즈(time/rest) 기준 비율. total은 이미 0 방지 클램프됨.
        let total = max(0.001, currentTotal())
        let rem = remaining(at: now)
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
    
    // idle일 때 remaining(at:)이 timeSec를 돌려주므로 별도 분기 불필요
    func displayRemaining(at now: Date) -> Int {
        Int(ceil(remaining(at: now)))
    }
    
    // Time Lozic
    func startPhase(_ duration: TimeInterval) {
        beeped.removeAll()
        didEndBeep = false
        
        let now = Date()
        // state 변경 및 시간 저장 / start & end
        state = .running(start: now, end: now.addingTimeInterval(duration))
        startTicker()
        onPhaseChanged?(phase, setIndex)
        refreshLiveActivity()
    }
    
    // 핵심 로직. / 타이머 하나 끝날때 호출
    // 포그라운드에서 TimelineView가 구동될 때만 호출된다.
    // 백그라운드 진행은 예약 알림 + 복귀 시 catchUp으로 처리한다.
    func advancePhase() {
        handleForegroundPhaseChange()
    }

    /// 모든 세트 완료: idle로 되돌리지 않고 00:00(done) 상태로 멈춘다.
    /// (idle이면 화면이 timeSec로 되돌아가 "30초에서 멈춘 것"처럼 보인다)
    private func finishAllSets() {
        state = .paused(remainig: 0)
        stopTicker()
        refreshLiveActivity()
        showCompletionPopup = true
        // 백그라운드에서 완료된 경우 소리는 예약 알림이 담당 (중복 방지)
        if !isInBackground {
            FeedbackService.shared.workoutComplete()
        }
        onEnded?()
    }

    /// 지금 진행 중인 페이즈가 끝나면 전체 완료가 되는가 (완료 전용 사운드 분기용)
    /// 무한 반복은 끝나지 않으므로 항상 false.
    private var isOnFinalPhase: Bool {
        guard !isInfiniteSets else { return false }
        if isCustomMode { return stepIndex >= customSteps.count - 1 }
        return phase == .rest && setIndex >= totalSets
    }

    /// 모든 세트/단계를 마친 완료(00:00) 상태인가.
    /// 수동 모드에서 rest 0초로 생기는 중간 paused(0)과 구분하기 위해 위치까지 확인한다.
    var isFinished: Bool {
        guard !isInfiniteSets else { return false }
        guard case .paused(let rem) = state, rem <= 0 else { return false }
        if isCustomMode { return stepIndex >= customSteps.count - 1 }
        return phase == .rest && setIndex >= totalSets
    }

    // 포그라운드
    func handleForegroundPhaseChange(){
        // 상세(커스텀) 모드: 단계를 순서대로 진행 (autoMode 규칙대로 경계에서 멈춤)
        if isCustomMode {
            let atEnd = stepIndex + 1 >= customSteps.count
            if atEnd && !isInfiniteSets {
                finishAllSets()
                return
            }
            // 무한 반복이면 마지막 단계 후 첫 단계로 되돌아간다
            let next = atEnd ? 0 : stepIndex + 1
            let endedPhase = phase
            onPhaseEnded?(endedPhase)
            syncCustomPhase(at: next)
            let autoStart: Bool
            switch effectiveAutoMode {
            case .fullAuto: autoStart = true
            case .setAuto:  autoStart = endedPhase == .time && !atEnd  // 휴식/한 바퀴가 끝나면 멈춤
            case .manual:   autoStart = false                          // 매 단계 끝마다 멈춤
            }
            if autoStart {
                startPhase(customSteps[next].seconds)
            } else {
                state = .paused(remainig: customSteps[next].seconds)
                stopTicker()
                refreshLiveActivity()
            }
            return
        }

        if phase == .time {
            onPhaseEnded?(.time)
            phase = .rest
            switch effectiveAutoMode {
            case .fullAuto, .setAuto:
                logger.d("autoMode .fullAuto")
                startPhase(restSec)
            case .manual:
                logger.d("autoMode .setAuto / .manual")
                state = .paused(remainig: restSec)
                stopTicker()
                refreshLiveActivity()
            }
        }else{
            if setIndex < totalSets {
                logger.d("advancePhase setIndex < total")
                onPhaseEnded?(.rest)
                setIndex += 1
                phase = .time
                switch effectiveAutoMode {
                case .fullAuto:
                    logger.d("autoMode .fullAuto")
                    startPhase(timeSec)
                case .setAuto, .manual:
                    logger.d("autoMode .setAuto / .manual")
                    state = .paused(remainig: timeSec)
                    stopTicker()
                    refreshLiveActivity()
                }
            }else{
                finishAllSets()
            }
        }
    }
    
    func handleBeepIfNeeded(displayRemaining: Int, endTime: Date) {
        // running일 때만
        guard case .running = state else { return }
        
        if lastBeepEndTime != endTime {
            lastBeepEndTime = endTime
            beeped.removeAll()
            didEndBeep = false
        }
        
        
        // 같은 초에서 중복 방지
        guard beeped.contains(displayRemaining) == false else { return }
        beeped.insert(displayRemaining)

        switch displayRemaining {
        case 3, 2, 1:
            FeedbackService.shared.countdownTick()    //  1초도 여기 포함
        case 0:
            // 마지막 페이즈의 0초는 finishAllSets()에서 완료 사운드가 울리므로 여기선 스킵
            if !isOnFinalPhase {
                FeedbackService.shared.phaseEndDouble()     //  0초는 긴 거
            }
        default:
            break
        }

//        // 3,2,1에서 각각 1번
//        if (1...3).contains(displayRemaining),
//           beeped.contains(displayRemaining) == false {
//            beeped.insert(displayRemaining)
//            FeedbackService.shared.countdownTick()
//        }
//
//        // 0에서 "삐삐~" 1번
//        if displayRemaining == 0, didEndBeep == false {
//            didEndBeep = true
//            FeedbackService.shared.phaseEndDouble()
//        }
    }

    
    // MARK: - << 버튼 (되감기)

    private static let rewindDoubleTapWindow: TimeInterval = 1.0
    private var lastRewindAt: Date?

    /// << 버튼: 한 번 누르면 현재 페이즈를 처음부터,
    /// 짧은 시간 안에 한 번 더 누르면 세트 전체(1세트 / 첫 단계)로 초기화한다.
    /// 어떤 상태에서든 항상 동작한다 (기존 previousSet은 1세트에서 아무 반응이 없었다).
    func rewind() {
        showCompletionPopup = false
        let now = Date()
        let isSecondTap = lastRewindAt.map {
            now.timeIntervalSince($0) < Self.rewindDoubleTapWindow
        } ?? false
        lastRewindAt = isSecondTap ? nil : now

        if isSecondTap {
            resetAllSets()
        } else {
            resetCurrentPhase()
        }
    }

    /// 현재 페이즈를 처음(전체 시간)으로 되돌린다. 실행 중이면 계속 실행, 일시정지면 일시정지 유지.
    private func resetCurrentPhase() {
        switch state {
        case .running:
            startPhase(currentTotal())
        case .paused:
            state = .paused(remainig: currentTotal())
            refreshLiveActivity()
        case .idle:
            break   // 아직 시작 전이라 이미 처음 상태
        }
    }

    /// 세트 초기화: 1세트(커스텀 모드는 첫 단계)의 Time 페이즈 처음으로 되돌린다.
    private func resetAllSets() {
        let wasRunning: Bool
        if case .running = state { wasRunning = true } else { wasRunning = false }

        if isCustomMode {
            syncCustomPhase(at: 0)
        } else {
            setIndex = 1
            phase = .time
        }

        switch state {
        case .idle:
            break   // 이미 처음 상태
        default:
            if wasRunning {
                startPhase(currentTotal())
            } else {
                state = .paused(remainig: currentTotal())
                refreshLiveActivity()
            }
        }
    }

    func nextSet() -> Bool {
        if isCustomMode {
            if stepIndex + 1 < customSteps.count {
                syncCustomPhase(at: stepIndex + 1)
            } else if isInfiniteSets {
                syncCustomPhase(at: 0)   // 무한 반복: 마지막 단계에서 첫 단계로
            } else {
                return false
            }
            startPhase(customSteps[stepIndex].seconds)
            return true
        }
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
        publishWidgetSnapshot()
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
    
    /// 자신의 Live Activity를 찾는다. 앱 프로세스가 재시작돼 메모리 참조(liveActivity)가
    /// 사라졌어도, 활동 속성에 박아둔 ownerId로 시스템에 등록된 활동을 다시 찾아 이어서 쓴다.
    /// (이게 없으면 재시작 후 모든 update가 조용히 무시돼 잠금화면 위젯이 얼어붙는다)
    @available(iOS 16.1, *)
    private func resolveLiveActivity() -> Activity<BeepTimerWidgetAttributes>? {
        if let liveActivity,
           liveActivity.activityState == .active || liveActivity.activityState == .stale {
            return liveActivity
        }
        let found = Activity<BeepTimerWidgetAttributes>.activities.first {
            $0.attributes.ownerId == ownerId &&
            ($0.activityState == .active || $0.activityState == .stale)
        }
        liveActivity = found
        return found
    }

    @available(iOS 16.1, *)
    func ensureLiveActivityCreated() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 이미 LiveActivity 살아있으면 반환
        if resolveLiveActivity() != nil { return }

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

        let attr = BeepTimerWidgetAttributes(title: timerTitle, ownerId: ownerId)
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
        guard #available(iOS 16.1, *), let liveActivity = resolveLiveActivity() else { return }
        await liveActivity.update(using: makeState(end: end, remain: nil))
    }

    private func updateLiveActivityPaused(remain: TimeInterval) async {
        guard #available(iOS 16.1, *), let liveActivity = resolveLiveActivity() else { return }
        await liveActivity.update(using: makeState(end: Date().addingTimeInterval(remain), remain: remain))
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
        
        // 카운트다운 렌더링 기준 시작시각. running이면 실제 페이즈 시작시각,
        // 그 외에는 end에서 남은 시간을 역산한다.
        let start: Date = {
            if case .running(let s, _) = state { return s }
            return end.addingTimeInterval(-max(remain ?? 0, 0.001))
        }()

        logger.d("make State \(state)")
        return BeepTimerWidgetAttributes.ContentState(
            phase: phaseString(),
            status: statusString,
            startTime: start,
            endTime: end,
            remainSec: remain != nil ? Int(ceil(remain!)) : nil,
            setIndex: setIndex,
            totalSets: totalSets,
            // 마지막 5초: 링을 빨간색으로 (T-5초에 보내는 업데이트에서 true가 된다)
            endingSoon: statusString == "running" && end.timeIntervalSinceNow <= 5.25
        )
    }

    private func phaseString() -> String {
        return phase == .rest ? "rest" : "time"
    }

    fileprivate func endLiveActivity(immediate: Bool) async {
        guard #available(iOS 16.1, *) else { return }
        let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .default
        // 메모리 참조가 끊긴 고아/중복 활동까지 ownerId로 전부 정리한다
        for activity in Activity<BeepTimerWidgetAttributes>.activities
        where activity.attributes.ownerId == ownerId {
            await activity.end(dismissalPolicy: policy)
        }
        if let liveActivity {
            await liveActivity.end(dismissalPolicy: policy)
        }
        liveActivity = nil
    }
}

// MARK: - 백그라운드 타임라인 / 로컬 알림
extension TimerController {

    /// 자동 진행되는 페이즈 한 구간
    struct Seg {
        let phase: Phase
        let setIndex: Int
        let start: Date
        let end: Date
        var stepIdx: Int = 0   // 커스텀 모드에서 단계 인덱스 복원용
    }

    /// 타임라인 생성 결과 (자동 진행 구간들 + 멈추는 지점)
    struct Timeline {
        enum Terminal {
            case done(lastSet: Int)
            case pause(phase: Phase, setIndex: Int, duration: TimeInterval, stepIdx: Int)
        }
        var segments: [Seg]
        var terminal: Terminal
    }

    /// 현재 running 상태(firstEnd = 현재 페이즈 종료시각)에서 출발해
    /// autoMode 규칙대로 자동 진행되는 페이즈 경계들을 계산한다.
    /// 자동 진행이 멈추는 지점(.pause) 또는 전체 종료(.done)에서 끝난다.
    func buildTimeline(firstEnd: Date) -> Timeline {
        // 상세(커스텀) 모드: 남은 단계를 순서대로 이어붙인다 (autoMode 규칙대로 경계에서 멈춤)
        if isCustomMode {
            let mode = effectiveAutoMode
            let loops = isInfiniteSets
            // 무한 반복은 fullAuto가 setAuto로 강등되어 항상 pause 지점에서 끝나지만,
            // 휴식 없는 구성 등으로 무한 루프에 빠지지 않도록 안전망으로 구간 수를 제한한다
            let maxSegments = loops ? 31 : Int.max
            var segments: [Seg] = [Seg(phase: phase, setIndex: setIndex,
                                       start: Date(), end: firstEnd, stepIdx: stepIndex)]
            var curEnd = firstEnd
            var ordinal = setIndex
            var lastPhase = phase
            var prevIdx = stepIndex
            while true {
                let atEnd = prevIdx + 1 >= customSteps.count
                if atEnd && !loops {
                    return Timeline(segments: segments, terminal: .done(lastSet: ordinal))
                }
                let i = atEnd ? 0 : prevIdx + 1
                let st = customSteps[i]
                let nextOrdinal = atEnd ? 1 : (st.isRest ? ordinal : ordinal + 1)
                // 직전 단계가 끝나는 경계에서 멈추는가?
                let stops: Bool
                switch mode {
                case .fullAuto: stops = false
                case .setAuto:  stops = lastPhase == .rest || atEnd   // 휴식/한 바퀴 끝
                case .manual:   stops = true
                }
                if stops {
                    return Timeline(segments: segments,
                                    terminal: .pause(phase: st.isRest ? .rest : .time,
                                                     setIndex: nextOrdinal,
                                                     duration: st.seconds,
                                                     stepIdx: i))
                }
                if segments.count >= maxSegments {
                    return Timeline(segments: segments, terminal: .done(lastSet: ordinal))
                }
                let s = curEnd
                curEnd = curEnd.addingTimeInterval(st.seconds)
                segments.append(Seg(phase: st.isRest ? .rest : .time, setIndex: nextOrdinal,
                                    start: s, end: curEnd, stepIdx: i))
                ordinal = nextOrdinal
                lastPhase = st.isRest ? .rest : .time
                prevIdx = i
            }
        }

        let mode = effectiveAutoMode
        // 무한 반복은 fullAuto가 차단되어 항상 pause 지점에서 끝나지만,
        // 로직이 바뀌어도 무한 루프에 빠지지 않도록 안전망으로 구간 수를 제한한다
        let maxSegments = isInfiniteSets ? 31 : Int.max

        var segments: [Seg] = []
        var curPhase = phase
        var curSet = setIndex
        var curEnd = firstEnd
        segments.append(Seg(phase: curPhase, setIndex: curSet, start: Date(), end: curEnd))

        while true {
            if segments.count >= maxSegments {
                return Timeline(segments: segments, terminal: .done(lastSet: curSet))
            }
            if curPhase == .time {
                // time 종료 → rest (manual이면 여기서 멈춤)
                guard mode == .fullAuto || mode == .setAuto else {
                    return Timeline(segments: segments,
                                    terminal: .pause(phase: .rest, setIndex: curSet, duration: restSec, stepIdx: 0))
                }
                let s = curEnd
                curEnd = curEnd.addingTimeInterval(restSec)
                curPhase = .rest
                segments.append(Seg(phase: curPhase, setIndex: curSet, start: s, end: curEnd))
            } else {
                // rest 종료 → 다음 세트 or 전체 종료
                guard curSet < totalSets else {
                    return Timeline(segments: segments, terminal: .done(lastSet: curSet))
                }
                curSet += 1
                // setAuto는 세트 경계에서 멈춘다 (fullAuto만 계속)
                guard mode == .fullAuto else {
                    return Timeline(segments: segments,
                                    terminal: .pause(phase: .time, setIndex: curSet, duration: timeSec, stepIdx: 0))
                }
                let s = curEnd
                curEnd = curEnd.addingTimeInterval(timeSec)
                curPhase = .time
                segments.append(Seg(phase: curPhase, setIndex: curSet, start: s, end: curEnd))
            }
        }
    }

    private func boundaries(from timeline: Timeline) -> [PhaseBoundary] {
        let segs = timeline.segments
        return segs.indices.map { i in
            let next: PhaseBoundary.NextKind
            if i + 1 < segs.count {
                let n = segs[i + 1]
                next = (n.phase == .time) ? .time(set: n.setIndex) : .rest(set: n.setIndex)
            } else {
                switch timeline.terminal {
                case .done:
                    next = .done
                case .pause(let p, let s, _, _):
                    // 이 경계에서 타이머는 자동 시작하지 않고 멈추므로 "시작" 대신 "끝" 문구로 알린다
                    next = (p == .time) ? .pauseBeforeTime(set: s) : .pauseBeforeRest(set: s)
                }
            }
            return PhaseBoundary(fireDate: segs[i].end, next: next)
        }
    }

    /// 백그라운드 진입 시: 남은 운동 전체에 대해 페이즈 알림을 예약한다.
    /// (자신의 예약만 갱신/취소 — 동시에 도는 다른 타이머의 알림은 건드리지 않는다)
    func scheduleBackgroundNotifications() {
        // 설정에서 종료 알림을 꺼두면 예약하지 않는다
        guard SettingManager.shared.phaseAlarmEnabled,
              case .running(_, let end) = state else {
            NotificationService.shared.cancel(ownerId: ownerId)
            return
        }
        let timeline = buildTimeline(firstEnd: end)
        NotificationService.shared.schedule(boundaries: boundaries(from: timeline),
                                            ownerId: ownerId)
    }

    /// 포그라운드 복귀 시: 예약 알림을 지우고, 백그라운드에서 흘러간 만큼 상태를 따라잡는다.
    func handleReturnToForeground() async {
        NotificationService.shared.cancel(ownerId: ownerId)
        catchUpFromBackground()
        publishWidgetSnapshot()
        await syncLiveActivityForCurrentState()
    }

    /// 백그라운드 동안 흘러간 시간을 반영해 현재 phase/setIndex/state를 보정한다.
    private func catchUpFromBackground() {
        guard case .running(_, let firstEnd) = state else { return }
        let now = Date()
        guard now >= firstEnd else { return }   // 현재 페이즈 진행 중이면 그대로 둔다

        // 무한 반복도 fullAuto가 차단되어 세트 경계에서 멈추므로,
        // 사이클을 통째로 건너뛰는 보정 없이 타임라인만 따라가면 된다
        let timeline = buildTimeline(firstEnd: firstEnd)

        if let seg = timeline.segments.first(where: { now < $0.end }) {
            // now가 어떤 자동 진행 구간 안에 있다 → 그 구간을 진행 중으로
            phase = seg.phase
            setIndex = seg.setIndex
            if isCustomMode { stepIndex = seg.stepIdx }
            state = .running(start: seg.start, end: seg.end)
        } else {
            // 모든 자동 구간을 지났다 → 종료 또는 멈춤 지점
            switch timeline.terminal {
            case .done(let lastSet):
                setIndex = lastSet
                if let last = timeline.segments.last {
                    phase = last.phase
                    if isCustomMode { stepIndex = last.stepIdx }
                }
                finishAllSets()
            case .pause(let p, let s, let dur, let stepIdx):
                if isCustomMode {
                    syncCustomPhase(at: stepIdx)
                } else {
                    phase = p
                    setIndex = s
                }
                state = .paused(remainig: dur)
            }
        }
    }
}

// MARK: - 위젯(잠금화면 / 다이나믹 아일랜드) 버튼 처리
extension TimerController: TimerWidgetActionHandling {
    /// LiveActivityIntent.perform()이 앱 프로세스에서 호출한다.
    /// 앱을 화면에 띄우지 않고도 동작이 실행되므로, 여기서 LA와 예약 알림을 직접 동기화한다.
    func handleWidgetAction(_ action: TimerWidgetAction) async {
        await MainActor.run {
            // 백그라운드 동안 지나간 페이즈를 먼저 반영한 뒤 동작을 적용한다.
            // (안 하면 이미 끝난 페이즈 기준으로 toggle/next가 동작해 상태·알림이 어긋난다)
            let wasActive = !(self.state == .idle)
            self.catchUpFromBackground()
            if wasActive, self.state == .idle, action != .stop {
                return   // catch-up 결과 운동이 이미 끝났다 — 버튼 입력은 무시 (재시작 방지)
            }
            switch action {
            case .toggle: self.toggle()
            case .next:   _ = self.nextSet()
            case .stop:   self.stop()
            }
        }

        // 잠금화면/백그라운드에서 눌린 것이므로 LA를 즉시 갱신하고,
        // 예약된 페이즈 알림(소리)을 현재 상태에 맞게 다시 맞춘다.
        await syncLiveActivityForCurrentState()

        await MainActor.run {
            if case .running = self.state {
                self.scheduleBackgroundNotifications()
            } else {
                NotificationService.shared.cancel(ownerId: self.ownerId)
            }
        }
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
