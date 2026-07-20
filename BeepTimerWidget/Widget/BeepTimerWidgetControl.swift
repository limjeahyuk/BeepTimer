//
//  BeepTimerWidgetControl.swift
//  BeepTimerWidget
//
//  Created by 임재혁 on 11/13/25.
//

import AppIntents
import SwiftUI
import WidgetKit

// 제어 센터 위젯(Control Widget)은 iOS 18부터 지원된다.
// 위젯 확장 전체를 iOS 18로 올리지 않도록 이 파일만 18.0 전용으로 표시한다.
// (현재 BeepTimerWidgetBundle에서 주석 처리되어 실제로 등록되지는 않는다)
@available(iOS 18.0, *)
struct BeepTimerWidgetControl: ControlWidget {
    static let kind: String = "com.LimJH.BeepTimer.BeepTimerWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

@available(iOS 18.0, *)
extension BeepTimerWidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            BeepTimerWidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = true // Check if the timer is running
            return BeepTimerWidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

@available(iOS 18.0, *)
struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: "Timer Name", default: "Timer")
    var timerName: String
}

@available(iOS 18.0, *)
struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        // Start the timer…
        return .result()
    }
}
