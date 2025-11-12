//
//  RealmManager.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/15/25.
//

import Foundation
import RealmSwift

class RTimerProgram: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var title: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var steps: List<RStep>
}

class RStep: EmbeddedObject {
    @Persisted var kindRaw: String = "time"
    @Persisted var seconds: Int = 10
}


extension RTimerProgram {
    convenience init(from p: TimerModel) {
        self.init()
        self.title = p.title
        self.createdAt = Date()
        let list = List<RStep>()
        p.steps.forEach { s in
            let rs = RStep()
            rs.kindRaw = s.kind.rawValue
            rs.seconds = s.seconds
            list.append(rs)
        }
        self.steps = list
    }
    
    func toModel() -> TimerModel {
        TimerModel(
            title: title,
            steps: steps.map {
                TimerModel.Step(kind: .init(rawValue: $0.kindRaw) ?? .time,
                                seconds: $0.seconds)
            }
        )
    }
}

struct ProgramStore {
    let realm: Realm
    
    static func open() throws -> ProgramStore {
        let config = Realm.Configuration(
            schemaVersion: 1) { _, _ in
                logger.d("migration nothing")
            }
        return try ProgramStore(realm: Realm(configuration: config))
    }
    
    @discardableResult
    func insert(_ program: TimerModel) throws -> ObjectId {
        let obj = RTimerProgram(from: program)
        try realm.write { realm.add(obj) }
        return obj._id
    }
    
    func all() -> Results<RTimerProgram> {
        realm.objects(RTimerProgram.self).sorted(byKeyPath: "createdAt", ascending: false)
    }

    func delete(_ obj: RTimerProgram) throws {
        try realm.write { realm.delete(obj) }
    }

    func upsert(id: ObjectId?, with program: TimerModel) throws -> ObjectId {
        if let id, let target = realm.object(ofType: RTimerProgram.self, forPrimaryKey: id) {
            try realm.write {
                target.title = program.title
                target.steps.removeAll()
                program.steps.forEach { s in
                    let rs = RStep()
                    rs.kindRaw = s.kind.rawValue
                    rs.seconds = s.seconds
                    target.steps.append(rs)
                }
            }
            return id
        } else {
            return try insert(program)
        }
    }
}

