//
//  TimerModel.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/15/25.
//

import SwiftUI

struct TimerModel: Codable, Identifiable, Equatable {
    var id = UUID()
    let title: String
    var infiniteSets: Bool = false   // 세트 무한 반복
    /// 링 색상 (운동 / 휴식) — hex 문자열. 기본값은 앱 기본 색(시안 / 앰버).
    var timeColorHex: String = TimerColor.defaultTimeHex
    var restColorHex: String = TimerColor.defaultRestHex
    let steps: [Step]
    
    struct Step: Codable, Equatable {
        enum Kind: String, Codable { case time, rest }
        let kind: Kind
        let seconds: Int
        var title: String? = nil   // 상세 모드 단계 이름 (예: 팔굽혀펴기)
    }
}

extension TimerModel {
    var setsCount: Int {
        let t = steps.filter { $0.kind == .time }.count
        let r = steps.filter { $0.kind == .rest }.count
        return min(t, r)
    }

    /// 모든 time이 동일, 모든 rest가 동일하면 (time, rest, sets) 반환. 아니면 nil.
    func asTimeRestSets() -> (time: Int, rest: Int, sets: Int)? {
        let times = steps.filter { $0.kind == .time }.map(\.seconds)
        let rests = steps.filter { $0.kind == .rest }.map(\.seconds)
        guard let t0 = times.first, let r0 = rests.first else { return nil }
        guard times.allSatisfy({ $0 == t0 }), rests.allSatisfy({ $0 == r0 }) else { return nil }
        return (time: t0, rest: r0, sets: setsCount)
    }

    /// 상세(커스텀) 프로그램 여부:
    /// 단계 이름이 하나라도 있거나, 시간이 균일하지 않거나, time/rest 교대 패턴이 아니면 커스텀.
    var isCustom: Bool {
        guard !steps.isEmpty else { return false }
        if steps.contains(where: { !($0.title ?? "").isEmpty }) { return true }
        guard asTimeRestSets() != nil else { return true }
        for (i, s) in steps.enumerated() {
            let expected: Step.Kind = (i % 2 == 0) ? .time : .rest
            if s.kind != expected { return true }
        }
        return false
    }

    var totalSeconds: Int {
        steps.reduce(0) { $0 + $1.seconds }
    }
}
