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
        public var phase: String /// "time" | "rest" |
        public var status: String /// "running" | "paused" | "done"
        /// 카운트다운용 종료시각 (running일 때만 의미 있음)
        public var endTime: Date
        /// 일시정지 시 표시용 남은 초(옵션)
        public var remainSec: Int?
        public var setIndex: Int
        public var totalSets: Int

        public init(phase: String, status: String, endTime: Date, remainSec: Int?, setIndex: Int, totalSets: Int) {
            self.phase = phase
            self.status = status
            self.endTime = endTime
            self.remainSec = remainSec
            self.setIndex = setIndex
            self.totalSets = totalSets
        }
    }

    public var title: String
    public init(title: String) { self.title = title }
}
