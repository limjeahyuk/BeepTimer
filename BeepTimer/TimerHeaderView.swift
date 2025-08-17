//
//  TimerHeaderView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

struct TimerHeaderData {
    let totalTime: Int       // ex: 45초
    let restTime: Int        // ex: 10초
    let totalSets: Int       // ex: 3세트
    var currentSet: Int      // ex: 현재 1세트 진행 중
}

struct TimerHeaderView: View {
    let totalTime: Int
    let restTime: Int
    let totalSets: Int
    var currentSet: Int
    
    var body: some View {
        HStack {
            TimerInfoView(title: "Time", value: totalTime)
            Spacer()
            TimerInfoView(title: "Rest", value: restTime)
            Spacer()
            VStack {
                Text("Set")
                    .font(.fromCSSFont(22, weight: .semibold))
                    .foregroundStyle(ColorManager.lightGray)

                HStack(spacing: 8) {

                Text("\(currentSet) / \(totalSets)")
                    .font(.fromCSSFont(26, weight: .bold))
                    .foregroundStyle(ColorManager.white)
                }
            }
        }
    }
}

struct TimerInfoView: View {
    let title: String
    let value: Int
    
    var formattedValue: (main: String, sub: String?) {
        if value < 60 {
            return (String(value), "s")
        } else if value % 60 == 0 {
            return ("\(value / 60)", "m")
        } else {
            return ("\(value / 60)m", "\(value % 60)s")
        }
    }

    var body: some View {
        VStack {
            Text(title)
                .font(.fromCSSFont(22, weight: .semibold))
                .foregroundStyle(ColorManager.lightGray)

            
            HStack(alignment: .bottom, spacing: 4) {
                Text(formattedValue.main)
                    .font(.fromCSSFont(26, weight: .bold))
                if let sub = formattedValue.sub {
                    Text(sub)
                        .font(.fromCSSFont(22, weight: .bold))
                }
            }
            .foregroundStyle(ColorManager.white)
        }
    }
}
