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
    let steps: [Step]
    
    struct Step: Codable, Equatable {
        enum Kind: String, Codable { case time, rest }
        let kind: Kind
        let seconds: Int
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
}
