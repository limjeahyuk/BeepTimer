//
//  FeedbackService.swift
//  BeepTimer
//
//  Created by 임재혁 on 12/24/25.
//

import Foundation
import AVFoundation
import AudioToolbox
import UIKit

final class FeedbackService {
    static let shared = FeedbackService()
    private init() {}

    private var configured = false

    /// 무음(벨소리/무음) 스위치와 상관없이, 재생 중인 음악과 섞여서 비프음이 들리도록 설정.
    /// - .playback  : 무음 스위치가 켜져 있어도 소리가 난다 (운동/타이머 알림 용도)
    /// - .mixWithOthers : 이어폰으로 듣던 음악을 끊지 않고 그 위로 비프음을 얹는다
    func configureIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            if !configured {
                try session.setCategory(.playback, options: [.mixWithOthers])
                configured = true
            }
            // 통화·다른 앱 등으로 세션이 비활성화됐을 수 있으므로 매번 활성 보장
            try session.setActive(true)
        } catch {
            // 설정 실패해도 시스템 사운드/진동은 동작함
            print("AudioSession configure error:", error)
        }
    }

    /// 전체 설정의 소리 토글
    private var soundOn: Bool { SettingManager.shared.soundEnabled }
    /// 전체 설정의 진동 토글
    private var vibrationOn: Bool { SettingManager.shared.vibrationEnabled }

    /// 3/2/1 짧은 '띠' + 짧은 진동(징)
    func countdownTick() {
        configureIfNeeded()

        // 짧은 소리(띠) — 무음이면 자동으로 안 들림
        if soundOn { AudioServicesPlaySystemSound(1104) }

        // 짧은 진동(징)
        if vibrationOn { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }

        // 워치가 연결돼 있으면 손목 햅틱도 함께
        PhoneConnectivity.shared.sendBeep("tick")
    }

    /// 페이즈 끝(0초) 긴 소리 + 진동
    func phaseEndDouble() {
        configureIfNeeded()
        if soundOn {
            AudioServicesPlaySystemSound(1013)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                AudioServicesPlaySystemSound(1013)
            }
        }
        if vibrationOn { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }

        PhoneConnectivity.shared.sendBeep("phaseEnd")
    }

    /// 전체 세트 완료: 3연타 긴 소리 + 진동 2번 (페이즈 종료음과 구분)
    func workoutComplete() {
        configureIfNeeded()
        if soundOn { AudioServicesPlaySystemSound(1013) }
        if vibrationOn { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        if soundOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                AudioServicesPlaySystemSound(1013)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            if soundOn { AudioServicesPlaySystemSound(1013) }
            if vibrationOn { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        }

        PhoneConnectivity.shared.sendBeep("complete")
    }
}

