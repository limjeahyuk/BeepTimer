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

// AppTheme은 위젯 타겟과 공유하는 UIManager.swift에 정의되어 있다

/// 운동/휴식 시간을 설정할 때 띄우는 입력기 종류
enum TimeInputStyle: Int, CaseIterable, Identifiable {
    case keypad = 0   // 숫자패드
    case wheel = 1    // 스크롤 휠
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .keypad: return "숫자패드"
        case .wheel:  return "숫자 스크롤"
        }
    }
}

enum TimerSettingKey {
    static let autoMode = "Timer_Auto_Mode"
    static let phaseAlarm = "Timer_Phase_Alarm"
    static let sound = "App_Sound_Enabled"
    static let vibration = "App_Vibration_Enabled"
    static let theme = "App_Theme"
    static let timeInput = "App_Time_Input_Style"
}

class SettingManager: ObservableObject {
    static let shared = SettingManager()

    @Published var autoMode: AutoPlayMode {
        didSet {
            UserDefaults.standard.set(autoMode.rawValue, forKey: TimerSettingKey.autoMode)
        }
    }

    /// 백그라운드에서 운동/휴식이 끝날 때 소리·배너 알림을 보낼지 여부
    @Published var phaseAlarmEnabled: Bool {
        didSet {
            UserDefaults.standard.set(phaseAlarmEnabled, forKey: TimerSettingKey.phaseAlarm)
        }
    }

    /// 카운트다운·종료 비프음 재생 여부
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: TimerSettingKey.sound)
        }
    }

    /// 카운트다운·종료 진동 여부
    @Published var vibrationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(vibrationEnabled, forKey: TimerSettingKey.vibration)
        }
    }

    /// 앱 배경 테마
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: TimerSettingKey.theme)
        }
    }

    /// 시간 설정 입력기 (숫자패드 / 스크롤)
    @Published var timeInputStyle: TimeInputStyle {
        didSet {
            UserDefaults.standard.set(timeInputStyle.rawValue, forKey: TimerSettingKey.timeInput)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: TimerSettingKey.autoMode) == nil {
            defaults.set(AutoPlayMode.fullAuto.rawValue, forKey: TimerSettingKey.autoMode)
        }
        let raw = defaults.integer(forKey: TimerSettingKey.autoMode)
        autoMode = AutoPlayMode(rawValue: raw) ?? .fullAuto

        if defaults.object(forKey: TimerSettingKey.phaseAlarm) == nil {
            defaults.set(true, forKey: TimerSettingKey.phaseAlarm)
        }
        phaseAlarmEnabled = defaults.bool(forKey: TimerSettingKey.phaseAlarm)

        // 소리·진동은 기본 켬
        if defaults.object(forKey: TimerSettingKey.sound) == nil {
            defaults.set(true, forKey: TimerSettingKey.sound)
        }
        soundEnabled = defaults.bool(forKey: TimerSettingKey.sound)

        if defaults.object(forKey: TimerSettingKey.vibration) == nil {
            defaults.set(true, forKey: TimerSettingKey.vibration)
        }
        vibrationEnabled = defaults.bool(forKey: TimerSettingKey.vibration)

        theme = AppTheme(rawValue: defaults.integer(forKey: TimerSettingKey.theme)) ?? .dark
        timeInputStyle = TimeInputStyle(rawValue: defaults.integer(forKey: TimerSettingKey.timeInput)) ?? .keypad
    }
}
