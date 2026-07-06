//
//  TimerLiveActivityIntents.swift
//  BeepTimer
//
//  Live Activity / Dynamic Island 버튼이 사용하는 App Intents.
//  이 파일은 앱(BeepTimer)과 위젯(BeepTimerWidgetExtension) 두 타겟 모두에 포함된다.
//
//  LiveActivityIntent는 "앱 프로세스"에서 perform()이 실행되므로,
//  앱이 TimerWidgetActionBus에 자신을 등록해두면
//  잠금화면 버튼을 눌렀을 때 앱을 화면에 띄우지 않고도 동작이 실행된다.
//

import Foundation
import AppIntents
import ActivityKit

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
/// 버튼이 눌린 Live Activity의 ownerId로 "그 타이머의 컨트롤러"를 정확히 찾아 전달한다.
enum TimerWidgetActionBus {
    /// ownerId 없는 (구버전) 활동을 위한 폴백 핸들러 — 가장 최근에 시작한 컨트롤러
    static weak var handler: TimerWidgetActionHandling?

    /// ownerId → 컨트롤러 (약한 참조라 컨트롤러가 해제되면 자동으로 빠진다)
    private static let registry = NSMapTable<NSString, AnyObject>.strongToWeakObjects()

    static func register(_ h: TimerWidgetActionHandling & AnyObject, ownerId: String) {
        registry.setObject(h, forKey: ownerId as NSString)
    }

    private static func handler(for ownerId: String?) -> TimerWidgetActionHandling? {
        if let ownerId, !ownerId.isEmpty {
            return registry.object(forKey: ownerId as NSString) as? TimerWidgetActionHandling
        }
        return handler
    }

    static func dispatch(_ action: TimerWidgetAction, ownerId: String?) async {
        // 앱이 콜드 런치되는 경우 핸들러 등록이 약간 늦을 수 있어 잠깐 기다린다 (최대 ~2초)
        for _ in 0..<20 {
            if let h = handler(for: ownerId) {
                await h.handleWidgetAction(action)
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        // 매칭되는 컨트롤러가 없다 — 앱 프로세스가 죽어 타이머 상태가 사라진 경우다.
        // 엉뚱한 타이머를 건드리지 않고, 정지 버튼이면 고아가 된 활동만 정리한다.
        if action == .stop, let ownerId, !ownerId.isEmpty {
            for activity in Activity<BeepTimerWidgetAttributes>.activities
            where activity.attributes.ownerId == ownerId {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}

struct ToggleTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "재생 / 일시정지"
    @Parameter(title: "Timer ID") var ownerId: String?
    init() {}
    init(ownerId: String) { self.ownerId = ownerId }
    func perform() async throws -> some IntentResult {
        await TimerWidgetActionBus.dispatch(.toggle, ownerId: ownerId)
        return .result()
    }
}

struct NextSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "다음 세트"
    @Parameter(title: "Timer ID") var ownerId: String?
    init() {}
    init(ownerId: String) { self.ownerId = ownerId }
    func perform() async throws -> some IntentResult {
        await TimerWidgetActionBus.dispatch(.next, ownerId: ownerId)
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "정지"
    @Parameter(title: "Timer ID") var ownerId: String?
    init() {}
    init(ownerId: String) { self.ownerId = ownerId }
    func perform() async throws -> some IntentResult {
        await TimerWidgetActionBus.dispatch(.stop, ownerId: ownerId)
        return .result()
    }
}
