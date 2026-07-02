//
//  TimerLiveActivityIntents.swift
//  BeepTimer
//
//  Live Activity / Dynamic Island 버튼이 사용하는 App Intents.
//  이 파일은 앱(BeepTimer)과 위젯(BeepTimerWidgetExtension) 두 타겟 모두에 포함된다.
//
//  LiveActivityIntent는 "앱 프로세스"에서 perform()이 실행되므로,
//  앱이 TimerWidgetActionBus.handler에 자신을 등록해두면
//  잠금화면 버튼을 눌렀을 때 앱을 화면에 띄우지 않고도 동작이 실행된다.
//

import Foundation
import AppIntents

/// Live Activity 버튼이 앱에 전달하는 동작
enum TimerWidgetAction: String {
    case toggle   // 재생 ↔ 일시정지
    case next     // 다음 세트
    case stop     // 정지
}

/// 앱(메인 프로세스)에서 위젯 동작을 실제로 처리하는 객체
protocol TimerWidgetActionHandling: AnyObject {
    func handleWidgetAction(_ action: TimerWidgetAction) async
}

/// 위젯 인텐트 ↔ 앱 핸들러를 잇는 인프로세스 버스.
/// LiveActivityIntent.perform()은 앱 프로세스에서 돌기 때문에 여기서 핸들러를 찾을 수 있다.
enum TimerWidgetActionBus {
    static weak var handler: TimerWidgetActionHandling?

    static func dispatch(_ action: TimerWidgetAction) async {
        // 앱이 콜드 런치되는 경우 핸들러 등록이 약간 늦을 수 있어 잠깐 기다린다 (최대 ~2초)
        for _ in 0..<20 {
            if let handler {
                await handler.handleWidgetAction(action)
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
    }
}

struct ToggleTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "재생 / 일시정지"
    init() {}
    func perform() async throws -> some IntentResult {
        await TimerWidgetActionBus.dispatch(.toggle)
        return .result()
    }
}

struct NextSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "다음 세트"
    init() {}
    func perform() async throws -> some IntentResult {
        await TimerWidgetActionBus.dispatch(.next)
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "정지"
    init() {}
    func perform() async throws -> some IntentResult {
        await TimerWidgetActionBus.dispatch(.stop)
        return .result()
    }
}
