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

        /// "1/3" 또는 무한 반복(Int.max)이면 "1/∞"
        public var setCountText: String {
            totalSets == Int.max ? "\(setIndex)/∞" : "\(setIndex)/\(totalSets)"
        }

        public init(phase: String, status: String, startTime: Date, endTime: Date, remainSec: Int?, setIndex: Int, totalSets: Int) {
            self.phase = phase
            self.status = status
            self.startTime = startTime
            self.endTime = endTime
            self.remainSec = remainSec
            self.setIndex = setIndex
            self.totalSets = totalSets
        }
    }

    public var title: String
    public init(title: String) { self.title = title }
}
