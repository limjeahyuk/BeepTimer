//
//  TimerController.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

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
    @Published var timeSec: TimeInterval = 30
    @Published var restSec: TimeInterval = 15
    @Published var totalSets: Int = 3
    
    // 외부에서는 읽기만 가능.
    // state는 무조건 내부에서만 변경 가능.
    @Published private(set) var phase: Phase = .time
    @Published private(set) var setIndex: Int = 1
    @Published private(set) var state: State = .idle
    
    var onStart: (() -> Void)?
    var onEnded: (() -> Void)?
    var onPhaseChanged: ((Phase, Int) -> Void)?
    
    func currentTotal() -> TimeInterval {
        phase == .time ? timeSec : restSec
    }
    
    func configure(time: Int, rest: Int, sets: Int){
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
        case .paused(let rem):
            resume(rem)
        case .running:
            break
        }
    }
    
    // 일시정지 : 남은 시간 저장
    func pause() {
        // running 일 때만 해당 함수 사용 가능.
        guard case .running(_, let end) = state else {
            return
        }
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
    }
    
    func stop() {
        state = .idle
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
        guard timeSec > 0 else { return 0}
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
    
    // Time Lozic
    func startPhase(_ duration: TimeInterval) {
        let now = Date()
        // state 변경 및 시간 저장 / start & end
        state = .running(start: now, end: now.addingTimeInterval(duration))
        logger.d("startPhase \(phase) \(setIndex)")
        onPhaseChanged?(phase, setIndex)
    }
    
    func advancePhase() {
        logger.d("advancePhase")
        if phase == .time {
            logger.d("advancePhase phase == .time")
            phase = .rest
            startPhase(restSec)
        }else{
            if setIndex < totalSets {
                logger.d("advancePhase setIndex < total")
                setIndex += 1
                phase = .time
                startPhase(timeSec)
            }else{
                state = .idle
                stop()
                // 전체 끝
                onEnded?()
            }
        }
    }
}
