//
//  PhotoSlideView.swift
//  BeepTimer
//
//  커스텀 영역 사진 슬라이드 — 운동 중 저장해둔 사진을 좌우로 넘겨 본다
//

import SwiftUI
import PhotosUI

struct PhotoSlideView: View {
    let memoKey: String
    let photos: [PhotoSlideStore.Photo]
    /// 사진이 바뀔 때마다 +1 — ContentView가 슬라이드를 다시 불러온다
    @Binding var photoStamp: Int

    @State private var page = 0
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        Group {
            if photos.isEmpty {
                // 빈 상태: 탭하면 바로 사진 선택
                PhotosPicker(selection: $pickerItems,
                             maxSelectionCount: PhotoSlideStore.maxPhotos,
                             matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("탭해서 사진을 추가하세요")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.35))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                GeometryReader { geo in
                    TabView(selection: $page) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
                            Image(uiImage: photo.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                // clipped는 그림만 자르고 터치 판정은 못 자른다 —
                                // 넘친 부분이 바깥 버튼 탭을 먹지 않게 터치 영역을 프레임으로 제한
                                .contentShape(Rectangle())
                                .tag(idx)
                        }

                        // 자리가 남으면 마지막 페이지가 + (넘겨서 바로 추가)
                        if photos.count < PhotoSlideStore.maxPhotos {
                            PhotosPicker(selection: $pickerItems,
                                         maxSelectionCount: PhotoSlideStore.maxPhotos - photos.count,
                                         matching: .images) {
                                VStack(spacing: 10) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 30, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(width: 64, height: 64)
                                        .background(
                                            Circle().strokeBorder(Color.white.opacity(0.35),
                                                                  style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                        )
                                    Text("사진 추가 (\(photos.count)/\(PhotoSlideStore.maxPhotos))")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                                .background(Color.black.opacity(0.5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .tag(photos.count)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .background(Color.black)
                }
            }
        }
        // 설정에서 사진을 지워 장수가 줄면 현재 페이지를 범위 안으로
        .onChange(of: photos.count) { count in
            if page > count { page = max(0, count - 1) }
        }
        // 사진 선택 → 저장 후 슬라이드 갱신
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        PhotoSlideStore.addPhoto(key: memoKey, imageData: data)
                    }
                }
                await MainActor.run { photoStamp += 1 }
            }
        }
    }
}

// MARK: - 설정 시트의 사진 관리 (추가 / 삭제)

struct PhotoManageGrid: View {
    let memoKey: String
    /// 사진이 바뀔 때마다 +1 — ContentView가 슬라이드를 다시 불러온다
    @Binding var photoStamp: Int

    @State private var photos: [PhotoSlideStore.Photo] = []
    @State private var pickerItems: [PhotosPickerItem] = []

    private let thumbSize: CGFloat = 54

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    thumbnail(photo)
                }
                if photos.count < PhotoSlideStore.maxPhotos {
                    PhotosPicker(selection: $pickerItems,
                                 maxSelectionCount: PhotoSlideStore.maxPhotos - photos.count,
                                 matching: .images) {
                        addTile
                    }
                }
                Spacer(minLength: 0)
            }
            Text("최대 \(PhotoSlideStore.maxPhotos)장 · 타이머 위에서 좌우로 넘겨 볼 수 있어요")
                .font(.system(size: 12))
                .foregroundStyle(TimerColor.textSecondary)
        }
        .onAppear { photos = PhotoSlideStore.loadPhotos(key: memoKey) }
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        PhotoSlideStore.addPhoto(key: memoKey, imageData: data)
                    }
                }
                await MainActor.run {
                    photos = PhotoSlideStore.loadPhotos(key: memoKey)
                    photoStamp += 1
                }
            }
        }
    }

    private func thumbnail(_ photo: PhotoSlideStore.Photo) -> some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(width: thumbSize, height: thumbSize)
            // 넘친 터치 판정이 옆 썸네일의 삭제 버튼을 먹지 않게 프레임으로 제한
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    PhotoSlideStore.deletePhoto(key: memoKey, filename: photo.filename)
                    photos = PhotoSlideStore.loadPhotos(key: memoKey)
                    photoStamp += 1
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color.black.opacity(0.65))
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("사진 삭제")
            }
    }

    private var addTile: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(width: thumbSize, height: thumbSize)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            )
            .contentShape(Rectangle())
            .accessibilityLabel("사진 추가")
    }
}
