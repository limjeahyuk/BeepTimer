//
//  PhotoSlideStore.swift
//  BeepTimer
//
//  커스텀 영역 모드 + 사진 슬라이드 저장 (프로그램별, 기본 타이머는 "default" 키)
//  사진 파일은 Documents/CustomAreaPhotos/ 에 두고 Realm에는 파일명 순서만 저장한다
//

import Foundation
import RealmSwift
import UIKit

class RCustomArea: Object {
    @Persisted(primaryKey: true) var key: String
    @Persisted var modeRaw: String = CustomAreaMode.drawing.rawValue
    @Persisted var photoFiles: List<String>
    @Persisted var webUrl: String = ""    // 웹 모드 시작 URL (빈 문자열 = Google)
    @Persisted var updatedAt: Date = Date()
}

enum PhotoSlideStore {
    static let maxPhotos = 5

    struct Photo: Identifiable, Equatable {
        let filename: String
        let image: UIImage
        var id: String { filename }

        static func == (lhs: Photo, rhs: Photo) -> Bool { lhs.filename == rhs.filename }
    }

    // MARK: - 모드

    static func loadMode(key: String) -> CustomAreaMode {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RCustomArea.self, forPrimaryKey: key),
              let mode = CustomAreaMode(rawValue: obj.modeRaw)
        else { return .drawing }
        return mode
    }

    static func saveMode(key: String, mode: CustomAreaMode) {
        update(key: key) { $0.modeRaw = mode.rawValue }
    }

    // MARK: - 웹 시작 URL

    static func loadWebUrl(key: String) -> String {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RCustomArea.self, forPrimaryKey: key)
        else { return "" }
        return obj.webUrl
    }

    static func saveWebUrl(key: String, url: String) {
        update(key: key) { $0.webUrl = url }
    }

    // MARK: - 사진

    static func loadPhotos(key: String) -> [Photo] {
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RCustomArea.self, forPrimaryKey: key)
        else { return [] }
        return obj.photoFiles.compactMap { name in
            guard let image = loadImageFile(name) else { return nil }
            return Photo(filename: name, image: image)
        }
    }

    /// 사진 추가 (최대 maxPhotos장) — 성공 여부 반환
    @discardableResult
    static func addPhoto(key: String, imageData: Data) -> Bool {
        guard let realm = try? Realm() else { return false }
        let count = realm.object(ofType: RCustomArea.self, forPrimaryKey: key)?.photoFiles.count ?? 0
        guard count < maxPhotos,
              let name = writeImageFile(imageData)
        else { return false }

        try? realm.write {
            if let obj = realm.object(ofType: RCustomArea.self, forPrimaryKey: key) {
                obj.photoFiles.append(name)
                obj.updatedAt = Date()
            } else {
                let obj = RCustomArea()
                obj.key = key
                obj.photoFiles.append(name)
                realm.add(obj)
            }
        }
        return true
    }

    static func deletePhoto(key: String, filename: String) {
        removeImageFile(filename)
        guard let realm = try? Realm(),
              let obj = realm.object(ofType: RCustomArea.self, forPrimaryKey: key) else { return }
        try? realm.write {
            if let idx = obj.photoFiles.firstIndex(of: filename) {
                obj.photoFiles.remove(at: idx)
            }
            obj.updatedAt = Date()
        }
    }

    // MARK: - 이미지 파일 공용 (사진 슬라이드 / 그림 메모 배경)

    /// 이미지 데이터를 축소·JPEG로 저장하고 파일명 반환
    static func writeImageFile(_ data: Data) -> String? {
        guard let image = UIImage(data: data),
              let jpeg = downscaled(image).jpegData(compressionQuality: 0.82)
        else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: fileURL(name), options: .atomic)
        } catch {
            return nil
        }
        return name
    }

    static func loadImageFile(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(name).path)
    }

    static func removeImageFile(_ name: String) {
        try? FileManager.default.removeItem(at: fileURL(name))
    }

    // MARK: - 내부

    /// 있으면 갱신, 없으면 만들어서 갱신
    private static func update(key: String, _ apply: (RCustomArea) -> Void) {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            if let obj = realm.object(ofType: RCustomArea.self, forPrimaryKey: key) {
                apply(obj)
                obj.updatedAt = Date()
            } else {
                let obj = RCustomArea()
                obj.key = key
                apply(obj)
                realm.add(obj)
            }
        }
    }

    private static var dirURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomAreaPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func fileURL(_ name: String) -> URL {
        dirURL.appendingPathComponent(name)
    }

    /// 화면 표시용으로 충분한 크기까지만 줄여 저장 용량을 아낀다
    private static func downscaled(_ image: UIImage, maxSide: CGFloat = 1600) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide else { return image }
        let scale = maxSide / side
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
