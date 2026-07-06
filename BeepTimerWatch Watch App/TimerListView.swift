//
//  TimerListView.swift
//  BeepTimerWatch Watch App
//
//  아이폰에서 동기화된 타이머 목록. 하나를 고르면 실행 화면으로 이동한다.
//  (워치에서는 편집하지 않는다 — 선택·실행만)
//

import SwiftUI

struct TimerListView: View {
    @ObservedObject private var sync = WatchConnectivityManager.shared

    /// 동기화된 타이머가 없으면 기본 타이머 하나만 보여준다
    private var timers: [SyncTimer] {
        sync.timers.isEmpty ? [.fallback] : sync.timers
    }

    var body: some View {
        List {
            if sync.timers.isEmpty {
                Text("iPhone에서 타이머를 추가하면 여기에 나타납니다")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(timers) { timer in
                NavigationLink {
                    TimerRunView(timer: timer, autoMode: sync.autoMode)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: timer.timeColorHex))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timer.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(timer.summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Beep Timer")
        .onAppear { sync.requestTimers() }
    }
}
