//
//  ActiveProgramStore.swift
//  BeepTimer
//
//  Created by 임재혁 on 11/12/25.
//

import RealmSwift
import SwiftUI

enum ActiveProgramStore {
    private static let key = "ActiveProgramID.v1"

    static func setActive(_ p: RTimerProgram) {
        UserDefaults.standard.set(p._id.stringValue, forKey: key)
    }

    static func activeId() -> ObjectId? {
        guard let s = UserDefaults.standard.string(forKey: key) else { return nil }
        return try? ObjectId(string: s)
    }

    static func isActive(_ p: RTimerProgram, activeId: ObjectId?) -> Bool {
        guard let activeId else { return false }
        return p._id == activeId
    }

    static func clearIfMatches(_ p: RTimerProgram) {
        if activeId() == p._id {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
