//
//  WatchSyncModels.swift
//  BeepTimer
//
//  아이폰 → 워치로 보내는 타이머 목록 페이로드. (한 방향 동기화 — 워치는 편집 불가)
//  아이폰(BeepTimer)과 워치(BeepTimerWatch) 두 타겟에 함께 포함된다.
//

import Foundation

/// 상세(커스텀) 타이머의 한 단계
struct SyncStep: Codable, Equatable {
    var title: String
    var isRest: Bool
    var seconds: Int
}

/// 워치로 보내는 타이머 하나
struct SyncTimer: Codable, Equatable, Identifiable {
    var id: String            // 아이폰 프로그램 _id (없으면 "default")
    var title: String
    var timeSec: Int
    var restSec: Int
    var totalSets: Int        // Int.max = 무한 반복
    var steps: [SyncStep]     // 비어있으면 단순 반복 모드
    /// 링 색상 (운동 / 휴식) — hex 문자열. 기본값 없이 디코딩 대비 default 지정.
    var timeColorHex: String = "#22D3EE"
    var restColorHex: String = "#F59E0B"

    var isCustom: Bool { !steps.isEmpty }
    var isInfinite: Bool { totalSets == Int.max }

    /// 목록에 보여줄 짧은 요약
    var summary: String {
        if isCustom { return "\(steps.count)단계" }
        let sets = isInfinite ? "∞" : "\(totalSets)"
        return "\(timeSec)s · 휴식 \(restSec)s · \(sets)세트"
    }

    /// 아이폰이 없을 때 워치에서 쓰는 기본 타이머
    static let fallback = SyncTimer(id: "default", title: "Beep Timer",
                                    timeSec: 30, restSec: 15, totalSets: 3, steps: [])
}

/// 워치 실행 화면 스타일 — 아이폰 전체 설정에서 고르며 워치의 모든 타이머에 적용된다.
enum WatchScreenStyle: Int, Codable, CaseIterable, Identifiable {
    case sunMoon = 0   // 해와 달 — 운동(해)이 지고 휴식(달)이 뜨는 연출 (기본)
    case plain   = 1   // 심플 — 연출 없이 숫자만 깔끔하게

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sunMoon: return "해와 달"
        case .plain:   return "심플"
        }
    }
}

/// 아이폰이 App Context로 보내는 전체 페이로드
struct SyncPayload: Codable, Equatable {
    var timers: [SyncTimer]
    var autoModeRaw: Int      // AutoPlayMode / EngineAutoMode 공통 raw 값
    var updatedAt: Date
    /// 워치 화면 스타일 raw — 구버전 페이로드에는 없으므로 옵셔널로 둔다
    var screenStyleRaw: Int?

    /// 값이 없거나 알 수 없으면 기본(해와 달)
    var screenStyle: WatchScreenStyle {
        WatchScreenStyle(rawValue: screenStyleRaw ?? 0) ?? .sunMoon
    }
}

extension SyncTimer {
    /// 공용 TimerEngine이 바로 쓰는 설정으로 변환
    func toEngineConfig() -> EngineConfig {
        let engineSteps = steps.map {
            EngineStep(title: $0.title, isRest: $0.isRest, seconds: TimeInterval($0.seconds))
        }
        return EngineConfig(title: title,
                            timeSec: TimeInterval(timeSec),
                            restSec: TimeInterval(restSec),
                            totalSets: totalSets,
                            steps: engineSteps)
    }
}
