//
//  CircleTimerView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

struct CircleTimerView: View {
    @ObservedObject var controller: TimerController
    
    @ObservedObject var settings = SettingManager.shared
    
    var ringWidth: CGFloat = 20
    
    let timeGrad = Color(hex: "#22D3EE")

    let restGrad = Color(hex: "#FB923C")
    
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
                    .foregroundColor(controller.phase == .time ? timeGrad : restGrad)
                
                Circle()
                    .trim(from: 0.0, to: p)
                    .stroke(style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(controller.phase == .time ? restGrad : timeGrad)
                
                VStack {
                    Spacer()
                    
                    Text("\(formattedValue(remaining))")
                        .font(.system(size: max(24, ringWidth * 1.8), weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#F3F4F6"))
                    
                    Spacer()
                    
                    HStack{
                        Button {
                            switch settings.autoMode {
                            case .fullAuto:
                                settings.autoMode = .setAuto
                            case .setAuto:
                                settings.autoMode = .manual
                            case .manual:
                                settings.autoMode = .fullAuto
                            }
                        }label: {
                            switch settings.autoMode {
                            case .fullAuto:
                                Image(systemName: "repeat")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            case .setAuto:
                                Image(systemName: "repeat.1")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            case .manual:
                                Image(systemName: "forward.end")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .foregroundStyle(Color(hex: "#F3F4F6"))
                    }
                    .padding(.bottom, 20 + ringWidth)
                }
            }
            .onChange(of: p) { _ in
                controller.tryFireEndIfNeeded()
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}
