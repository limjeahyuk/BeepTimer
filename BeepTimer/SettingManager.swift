//
//  SettingManager.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/17/25.
//

import SwiftUI
import UIKit

enum TimerSettingKey {
    static let autoPlay = "TimerAutoPlay"
}

class SettingManager: ObservableObject {
    static let shared = SettingManager()
    
    @Published var autoPlay: Bool {
        didSet {
            UserDefaults.standard.set(autoPlay, forKey: TimerSettingKey.autoPlay)
        }
    }
    
    private init() {
        // 기본값은 UserDefaults에서 불러오거나, 없으면 초기값으로 설정
        autoPlay = UserDefaults.standard.object(forKey: TimerSettingKey.autoPlay) as? Bool ?? true
    }
}
