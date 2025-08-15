//
//  CircleTimerView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

struct CircleTimerView: View {
    @ObservedObject var controller: TimerController
    
    var ringWidth: CGFloat = 20
    
    func formattedValue(_ sec: Int) -> String {
        if sec < 60 {
            return "\(String(sec)) s"
        } else if sec % 60 == 0 {
            return "\(sec / 60) m"
        } else {
            return "\(sec / 60)m \(sec % 60)s"
        }
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let now = ctx.date
            let p = controller.progress(at: now)
            let remaining = controller.displayRemaing(at: now)
            
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: ringWidth))
                    .opacity(0.15)
                    .foregroundColor(.gray)
                
                Circle()
                    .trim(from: 0.0, to: p)
                    .stroke(style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(.green)
                
                Text("\(formattedValue(remaining))")
                    .font(.system(size: max(24, ringWidth * 1.8), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .onChange(of: p) { _ in
                controller.tryFireEndIfNeeded(now: Date())
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}
