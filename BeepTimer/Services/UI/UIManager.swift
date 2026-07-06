//
//  ColorManager.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum TimerColor {
    static let bg            = Color(hex: "#1A1E24")
    static let textPrimary   = Color(hex: "#F3F4F6")
    static let textSecondary = Color.white.opacity(0.65)

    static let ringTrack     = Color.white.opacity(0.12)  // ← 항상 고정
    /// 링 색 기본값 (타이머가 색을 지정하지 않았을 때) — hex 문자열
    static let defaultTimeHex = "#22D3EE"                  // Cyan 400
    static let defaultRestHex = "#F59E0B"                  // Amber 500
    static let ringTime      = Color(hex: defaultTimeHex)  // Cyan 400
    static let ringRest      = Color(hex: defaultRestHex)  // Amber 500

    static let btnStartBg    = Color(hex: "#22C55E")      // Green 500
    static let btnResetBg    = Color(hex: "#F59E0B")      // Amber 500
    static let btnText       = Color.white
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// "#RRGGBB" 문자열로 변환 (ColorPicker 결과 저장용). 알파는 무시한다.
    func toHex() -> String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp = { (v: CGFloat) -> Int in Int((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
        #else
        return TimerColor.defaultTimeHex
        #endif
    }
}

extension Font{
    static func fromCSSFont(_ font: Int, weight: Weight) -> Font {
        
        return .system(size: CGFloat(font), weight: weight )
    }
}

