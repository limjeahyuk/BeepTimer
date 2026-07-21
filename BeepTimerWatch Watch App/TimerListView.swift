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

    #if DEBUG
    /// 스토어 스크린샷용: 첫 타이머 실행 화면으로 바로 들어간다
    /// (simctl launch ... -openRun)
    @State private var autoOpenRun = ProcessInfo.processInfo.arguments.contains("-openRun")
    #endif

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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(timer.title)
                            .font(.headline)
                            .lineLimit(1)
                        // 타이머 시간 · 휴식 시간(색으로 구분) · 세트 수
                        HStack(spacing: 6) {
                            if timer.isCustom {
                                Text("\(timer.steps.count)단계")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(shortDuration(timer.timeSec))
                                    .foregroundStyle(WatchPalette.time)
                                if timer.restSec > 0 {
                                    Text(shortDuration(timer.restSec))
                                        .foregroundStyle(WatchPalette.rest)
                                }
                            }
                            Text(timer.isInfinite ? "∞세트" : "\(timer.totalSets)세트")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption2)
                        .monospacedDigit()
                        .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WatchPalette.bg.ignoresSafeArea())
        .navigationTitle("Beep Timer")
        .onAppear { sync.requestTimers() }
        #if DEBUG
        // 스토어 스크린샷용 자동 진입 — 목록이 동기화된 뒤 첫 타이머를 연다
        .navigationDestination(isPresented: $autoOpenRun) {
            TimerRunView(timer: timers[0], autoMode: sync.autoMode)
        }
        #endif
    }
}
