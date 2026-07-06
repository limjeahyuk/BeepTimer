//
//  BeepTimerWidgetAttributes.swift
//  BeepTimer
//
//  Created by 임재혁 on 11/13/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

public struct BeepTimerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// "time" | "rest" |
        public var phase: String
        /// "running" | "paused" | "done"
        public var status: String
        /// 카운트다운용 시작시각 — timerInterval 렌더링용 (endTime이 지나면 00:00에서 멈춘다)
        public var startTime: Date
        /// 카운트다운용 종료시각 (running일 때만 의미 있음)
        public var endTime: Date
        /// 일시정지 시 표시용 남은 초(옵션)
        public var remainSec: Int?
        public var setIndex: Int
        public var totalSets: Int
        /// 남은 시간 5초 이하 — 링을 빨간색으로 전환 (앱이 T-5초에 업데이트를 보내 갱신한다)
        public var endingSoon: Bool

        /// "1/3" 또는 무한 반복(Int.max)이면 세트를 세지 않고 "∞"
        public var setCountText: String {
            totalSets == Int.max ? "∞" : "\(setIndex)/\(totalSets)"
        }

        public init(phase: String, status: String, startTime: Date, endTime: Date, remainSec: Int?, setIndex: Int, totalSets: Int, endingSoon: Bool = false) {
            self.phase = phase
            self.status = status
            self.startTime = startTime
            self.endTime = endTime
            self.remainSec = remainSec
            self.setIndex = setIndex
            self.totalSets = totalSets
            self.endingSoon = endingSoon
        }
    }

    public var title: String
    /// 이 활동을 소유한 타이머 식별자 (프로그램 id / "shared").
    /// 앱 프로세스가 재시작돼도 컨트롤러가 자기 활동을 다시 찾아 갱신·종료할 수 있게 한다.
    public var ownerId: String
    public init(title: String, ownerId: String = "") {
        self.title = title
        self.ownerId = ownerId
    }
}
