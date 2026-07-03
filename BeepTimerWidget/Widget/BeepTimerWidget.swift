//
//  BeepTimerWidget.swift
//  BeepTimerWidget
//
//  홈 화면 위젯: App Group에 저장된 타이머 스냅샷을 읽어
//  설정값(운동/휴식/세트) 또는 진행 중 카운트다운을 보여준다.
//  탭하면 앱이 열리고(idle이면) 타이머가 바로 시작된다.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct TimerEntry: TimelineEntry {
    let date: Date
    let snapshot: TimerWidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(date: Date(), snapshot: .idleDefault)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        completion(TimerEntry(date: Date(), snapshot: TimerWidgetStore.load() ?? .idleDefault))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let snapshot = TimerWidgetStore.load() ?? .idleDefault
        let entry = TimerEntry(date: Date(), snapshot: snapshot)

        // 진행 중이면 종료시각에 한 번 더 갱신해 다음 페이즈/완료 상태를 반영한다.
        if let end = snapshot.endTime, end > Date() {
            completion(Timeline(entries: [entry], policy: .after(end)))
        } else {
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}

// MARK: - 공용 헬퍼

private func mmss(_ total: Int) -> String {
    let s = max(0, total)
    return String(format: "%02d:%02d", s / 60, s % 60)
}

// MARK: - View

struct BeepTimerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var snap: TimerWidgetSnapshot { entry.snapshot }
    private var accent: Color { snap.phaseIsRest ? TimerColor.ringRest : TimerColor.ringTime }

    /// idle이면 시작, 진행 중이면 그냥 앱 열기
    private var deepLink: URL {
        URL(string: snap.isActive ? "beeptimer://open" : "beeptimer://start")!
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(deepLink)
            .containerBackground(TimerColor.bg, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if family == .systemSmall {
            smallBody
        } else {
            mediumBody
        }
    }

    // MARK: 제목 줄
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(snap.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TimerColor.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: 큰 숫자 (진행 중) 또는 설정 요약 (idle)
    @ViewBuilder
    private var bigValue: some View {
        if snap.isActive {
            if let end = snap.endTime, !snap.isPaused {
                // style: .timer는 end가 지나면 카운트업으로 바뀌므로 timerInterval로 00:00에 고정
                let start = min(snap.startTime ?? entry.date, end)
                Text(timerInterval: start...end, countsDown: true)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(TimerColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(mmss(snap.pausedRemain ?? 0))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        } else {
            Text(mmss(snap.time))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(TimerColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: 상태 라벨
    private var statusLabel: some View {
        Group {
            if snap.isActive {
                Text(snap.isPaused ? "일시정지" : (snap.phaseIsRest ? "Rest" : "Time"))
                    .foregroundStyle(snap.isPaused ? Color.secondary : accent)
            } else {
                Label("탭하여 시작", systemImage: "play.fill")
                    .foregroundStyle(accent)
            }
        }
        .font(.caption2.weight(.semibold))
    }

    private var setText: String { "Set \(snap.setIndex)/\(snap.sets)" }

    // MARK: Small
    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            bigValue
            HStack {
                statusLabel
                Spacer()
                Text(snap.isActive ? setText : "\(snap.sets)세트")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    // MARK: Medium
    private var mediumBody: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer(minLength: 0)
                bigValue
                statusLabel
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                Text(setText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TimerColor.textPrimary)
                infoRow("운동", snap.time, color: TimerColor.ringTime)
                infoRow("휴식", snap.rest, color: TimerColor.ringRest)
            }
        }
        .padding(16)
    }

    private func infoRow(_ title: String, _ seconds: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(mmss(seconds))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(TimerColor.textPrimary)
        }
    }
}

// MARK: - Widget

struct BeepTimerWidget: Widget {
    let kind: String = "BeepTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BeepTimerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Beep Timer")
        .description("운동/휴식 타이머를 한눈에 보고 바로 시작하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
