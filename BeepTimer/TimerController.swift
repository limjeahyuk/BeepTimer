//
//  TimerController.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

class TimerController: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var progress: CGFloat = 1.0
    var totalTime: Int = 30
    var timer: Timer?
    var onEnded: (() -> Void)? = nil

    func start() {
        timer?.invalidate()
        if totalTime != timeRemaining {
            timeRemaining = totalTime
        }
        progress = 1.0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                self.progress = CGFloat(self.timeRemaining) / CGFloat(self.totalTime)
            } else {
                self.timer?.invalidate()
                self.onEnded?()
            }
        }
    }

    func stop() {
        timer?.invalidate()
    }
}
