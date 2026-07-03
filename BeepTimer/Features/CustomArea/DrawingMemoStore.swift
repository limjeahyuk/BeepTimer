//
//  DrawingMemoStore.swift
//  BeepTimer
//
//  그림 메모 저장/복원 (프로그램별 1개, 기본 타이머는 "default" 키)
//

import Foundation
import RealmSwift

class RDrawingMemo: Object {
    @Persisted(primaryKey: true) var key: String
    @Persisted var data: Data
    @Persisted var bgColorHex: String = ""    // 빈 문자열 = 투명 배경
    @Persisted var penColorHex: String = ""   // 빈 문자열 = 기본 펜 색
    @Persisted var updatedAt: Date = Date()
}

enum DrawingMemoStore {
    static func load(key: String) -> [DrawingStroke] {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RDrawingMemo.self, forPrimaryKey: key),
              let strokes = try? JSONDecoder().decode([DrawingStroke].self, from: obj.data)
        else { return [] }
        return strokes
    }

    static func save(key: String, strokes: [DrawingStroke]) {
        guard let realm = try? Realm(),
              let data = try? JSONEncoder().encode(strokes) else { return }
        try? realm.write {
            if let obj = realm.object(ofType: RDrawingMemo.self, forPrimaryKey: key) {
                obj.data = data
                obj.updatedAt = Date()
            } else {
                let obj = RDrawingMemo()
                obj.key = key
                obj.data = data
                realm.add(obj)
            }
        }
    }

    static func loadBackground(key: String) -> String {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RDrawingMemo.self, forPrimaryKey: key)
        else { return "" }
        return obj.bgColorHex
    }

    static func saveBackground(key: String, colorHex: String) {
        update(key: key) { $0.bgColorHex = colorHex }
    }

    static func loadPenColor(key: String) -> String {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RDrawingMemo.self, forPrimaryKey: key),
              !obj.penColorHex.isEmpty
        else { return DrawingPalette.colors[0] }
        return obj.penColorHex
    }

    static func savePenColor(key: String, colorHex: String) {
        update(key: key) { $0.penColorHex = colorHex }
    }

    /// 있으면 갱신, 없으면 만들어서 갱신
    private static func update(key: String, _ apply: (RDrawingMemo) -> Void) {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            if let obj = realm.object(ofType: RDrawingMemo.self, forPrimaryKey: key) {
                apply(obj)
                obj.updatedAt = Date()
            } else {
                let obj = RDrawingMemo()
                obj.key = key
                obj.data = (try? JSONEncoder().encode([DrawingStroke]())) ?? Data()
                apply(obj)
                realm.add(obj)
            }
        }
    }
}
