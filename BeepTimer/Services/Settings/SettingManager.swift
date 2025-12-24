//
//  SettingManager.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/17/25.
//

import SwiftUI
import UIKit

enum AutoPlayMode: Int, CaseIterable, Identifiable {
    case fullAuto = 0   // 완전 auto : Set 끝날때까지 auto
    case setAuto = 1    // 세트 auto : 한 세트 끝나면 멈춤
    case manual = 2     // 수동 : 각 단계 끝나면 멈춤
    var id: Int { rawValue }
}

enum TimerSettingKey {
    static let autoMode = "Timer_Auto_Mode"
}

class SettingManager: ObservableObject {
    static let shared = SettingManager()
    
    @Published var autoMode: AutoPlayMode {
        didSet {
            UserDefaults.standard.set(autoMode.rawValue, forKey: TimerSettingKey.autoMode)
        }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: TimerSettingKey.autoMode) == nil {
            defaults.set(AutoPlayMode.fullAuto.rawValue, forKey: TimerSettingKey.autoMode)
        }
        let raw = defaults.integer(forKey: TimerSettingKey.autoMode)
        autoMode = AutoPlayMode(rawValue: raw) ?? .fullAuto
    }
}
