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

    /// 무음 스위치가 켜져 있으면 소리가 자동으로 안 들리도록(.ambient) 설정
    func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // 설정 실패해도 시스템 사운드/진동은 동작함
            print("AudioSession configure error:", error)
        }
    }

    /// 3/2/1 짧은 '띠' + 짧은 진동(징)
    func countdownTick() {
        configureIfNeeded()

        // 짧은 소리(띠) — 무음이면 자동으로 안 들림
        AudioServicesPlaySystemSound(1104)

        // 짧은 진동(징)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    /// 페이즈 끝(0초) 긴 소리 + 진동
    func phaseEnd() {
        configureIfNeeded()

        // 조금 더 긴 느낌의 시스템 사운드 (원하면 다른 ID로 교체 가능)
        AudioServicesPlaySystemSound(1013)

        // 진동도 한 번
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    func phaseEndDouble() {
        configureIfNeeded()
        AudioServicesPlaySystemSound(1013)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            AudioServicesPlaySystemSound(1013)
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

