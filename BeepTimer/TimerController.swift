//
//  TimerController.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

class TimerController: ObservableObject {
    enum State: Equatable {
        case idle
        case running(start: Date, end: Date)
        case paused(remainig: TimeInterval)
    }
    
    // 외부에서는 읽기만 가능.
    // state는 무조건 내부에서만 변경 가능.
    @Published private(set) var state: State = .idle
    @Published private(set) var totalTime: TimeInterval = 30 // 초
    var onEnded: (() -> Void)?

    // 새로 시작 무조건 처음부터
    func start(total: Int? = nil) {
        if let total { totalTime = TimeInterval(total) }
        let now = Date()
        // state 변경 및 시간 저장 / start & end
        state = .running(start: now, end: now.addingTimeInterval(totalTime))
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
    func resume() {
        // state가 paused일 때만 해당 함수 작동 가능. / 남은 시간이 0이상.
        guard case .paused(let remainig) = state, remainig > 0 else {
            return
        }
        
        let now = Date()
        // state 변경. running (지금 시간 부터 지금으로부터 남은 시간.)
        state = .running(start: now, end: now.addingTimeInterval(remainig))
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
            return totalTime
        case .running(_, let end):
            return max(0, end.timeIntervalSince(now))
        case .paused(let remaing):
            return max(0, remaing)
        }
    }
    
    func progress(at now: Date) -> CGFloat {
        let rem = remaining(at: now)
        guard totalTime > 0 else { return 0}
        return CGFloat(rem / totalTime)
    }
    
    // 종료 체크
    func tryFireEndIfNeeded(now: Date) {
        if case .running(_, let end) = state, now >= end {
            state = .idle
            logger.d("tryFireEndInNeeded")
            onEnded?()
        }
    }
    
    func setTotalTime(_ seconds: Int) {
        totalTime = TimeInterval(max(1, seconds))
    }
    
    func displayRemaing(at now: Date) -> Int {
        switch state {
        case .idle:
            return Int(ceil(totalTime))
        default:
            return Int(ceil(remaining(at: now)))
        }
    }
}
