//
//  CustomAreaModels.swift
//  BeepTimer
//
//  타이머 위에 띄우는 커스텀 영역(그림 메모, 추후 사진 등) 공용 모델
//

import Foundation
import SwiftUI

/// 커스텀 영역이 열려 있는 동안 페이저 스와이프를 막기 위한 공유 상태
final class CustomAreaState: ObservableObject {
    static let shared = CustomAreaState()
    @Published var isOpen = false
    private init() {}
}

/// 커스텀 영역에 띄울 콘텐츠 종류 — 추후 텍스트 메모, 미니 게임 등이 추가될 수 있다
enum CustomAreaMode: String, CaseIterable {
    case drawing    // 그림 메모
    case photos     // 사진 슬라이드
    case web        // 웹 페이지 (기본 Google, 설정에서 시작 URL 변경)

    var label: String {
        switch self {
        case .drawing: return "그림 메모"
        case .photos:  return "사진"
        case .web:     return "웹"
        }
    }

    /// 타이틀 오른쪽 열기 버튼 아이콘
    var icon: String {
        switch self {
        case .drawing: return "scribble.variable"
        case .photos:  return "photo.on.rectangle"
        case .web:     return "globe"
        }
    }
}

/// 그림 메모의 선 하나 (색 / 굵기 / 지나간 점들)
struct DrawingStroke: Codable, Equatable {
    var colorHex: String
    var lineWidth: CGFloat
    var points: [CGPoint]
}

enum DrawingPalette {
    static let colors = ["#F3F4F6", "#111827", "#22D3EE", "#F59E0B", "#F87171"]
    /// 메모장 배경 단색 후보 (빈 문자열 = 투명 배경)
    static let backgrounds = ["#FFFFFF", "#FEF3C7", "#BFDBFE", "#FBCFE8", "#111827"]
}
