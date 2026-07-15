//
//  WatchColor.swift
//  BeepTimerWatch Watch App
//
//  아이폰에서 받은 hex 색 문자열을 Color로 변환한다.
//  (앱 타깃의 UIManager.Color(hex:)와 동일 규칙 — 워치 타깃에는 그 파일이 없어 따로 둔다)
//

import SwiftUI

/// 워치 화면 고정 팔레트 — 사용자가 바꾸지 못하며 모든 타이머에 통일 적용된다.
/// 검정 배경 위에서 잘 보이고 서로 잘 어울리는 조합으로 고정한다.
enum WatchPalette {
    // 해·달 은유 — 운동은 해(노랑), 휴식은 달(은회색).
    // 실행 화면에서 해가 지고 달이 뜨는 궤도 연출과 색을 공유한다.
    static let bg     = Color.black                // 뒷배경 — 검정 고정
    static let time   = Color(hex: "#FBBF24")      // 운동 = 해 — 노랑
    static let rest   = Color(hex: "#A1A1AA")      // 휴식 = 달 — 은회색
    static let label  = Color(hex: "#E5E7EB")      // 단계명(Time/Rest·단계 제목) — 밝은 회색
    static let number = Color.white                // 남은 시간 숫자 — 흰색 고정.
                                                   // 궤도(페이즈 색)와 겹쳐도 항상 읽히게 하려는 의도.
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
}
