//
//  CircleTimerView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

struct CircleTimerView: View {
    @ObservedObject var controller: TimerController

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 20)
                .opacity(0.2)
                .foregroundColor(.gray)

            Circle()
                .trim(from: 0.0, to: controller.progress)
                .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundColor(.green)
                .animation(.easeInOut(duration: 0.2), value: controller.progress)

            Text("\(controller.timeRemaining)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 240, height: 240)
    }
}
