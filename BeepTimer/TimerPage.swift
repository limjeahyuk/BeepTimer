//
//  File.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/14/25.
//

import SwiftUI

struct TimerPager: View {
    @StateObject var controller = TimerController()

    @State private var page = 0
    private let presets: [TimerPreset] = [
        .init(name: "Quick 5", time: 300, rest: 60, sets: 3),
        .init(name: "EMOM 20", time: 60, rest: 0, sets: 20),
        .init(name: "HIIT 30/15", time: 30, rest: 15, sets: 10),
    ]

    var body: some View {
        TabView(selection: $page) {
            // 0: 메인 타이머
            ContentView()
                .tag(0)

            // 1: 라이브러리
            NavigationStack {
                TimerLibraryView(presets: presets) { p in
                    controller.configure(time: p.time, rest: p.rest, sets: p.sets)
                    controller.stop()
                    controller.start()
                    page = 0 // 선택 후 메인으로 스와이프 백
                }
            }
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(hex: "#1A1E24").ignoresSafeArea())
    }
}

