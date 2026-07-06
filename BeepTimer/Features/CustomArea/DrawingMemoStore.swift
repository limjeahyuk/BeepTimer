//
//  DrawingMemoStore.swift
//  BeepTimer
//
//  그림 메모 저장/복원 (프로그램별 1개, 기본 타이머는 "default" 키)
//

import Foundation
import RealmSwift
import UIKit

class RDrawingMemo: Object {
    @Persisted(primaryKey: true) var key: String
    @Persisted var data: Data
    @Persisted var bgColorHex: String = ""    // 빈 문자열 = 투명 배경
    @Persisted var penColorHex: String = ""   // 빈 문자열 = 기본 펜 색
    @Persisted var bgPhotoFile: String = ""   // 배경 사진 파일명 (빈 문자열 = 없음, 있으면 단색보다 우선)
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

    // MARK: - 배경 사진 (있으면 단색 배경보다 우선)

    static func loadBackgroundPhoto(key: String) -> UIImage? {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RDrawingMemo.self, forPrimaryKey: key),
              !obj.bgPhotoFile.isEmpty
        else { return nil }
        return PhotoSlideStore.loadImageFile(obj.bgPhotoFile)
    }

    /// 배경 사진 저장 (기존 사진은 교체) — 표시용 이미지를 반환
    @discardableResult
    static func saveBackgroundPhoto(key: String, imageData: Data) -> UIImage? {
        guard let name = PhotoSlideStore.writeImageFile(imageData) else { return nil }
        let oldName = (try? Realm())?
            .object(ofType: RDrawingMemo.self, forPrimaryKey: key)?.bgPhotoFile ?? ""
        update(key: key) { $0.bgPhotoFile = name }
        if !oldName.isEmpty { PhotoSlideStore.removeImageFile(oldName) }
        return PhotoSlideStore.loadImageFile(name)
    }

    static func clearBackgroundPhoto(key: String) {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RDrawingMemo.self, forPrimaryKey: key),
              !obj.bgPhotoFile.isEmpty else { return }
        let oldName = obj.bgPhotoFile
        try? realm.write {
            obj.bgPhotoFile = ""
            obj.updatedAt = Date()
        }
        PhotoSlideStore.removeImageFile(oldName)
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
