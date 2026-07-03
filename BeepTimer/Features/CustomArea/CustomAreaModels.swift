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
