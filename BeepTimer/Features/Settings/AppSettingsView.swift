//
//  AppSettingsView.swift
//  BeepTimer
//
//  앱 전체 설정 — 소리 / 진동 / 소리 미리듣기 / 종료 알림 / 테마 / 시간 입력 방식.
//  타이머 하나에 종속되지 않는 설정은 전부 여기서 다룬다.
//

import SwiftUI

struct AppSettingsView: View {
    @ObservedObject private var settings = SettingManager.shared

    private let accent = Color(hex: "#22D3EE")

    var body: some View {
        ZStack {
            TimerColor.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("전체 설정")
                        .font(.fromCSSFont(22, weight: .bold))
                        .foregroundStyle(TimerColor.textPrimary)
                        .padding(.top, 40)

                    // 소리 · 진동
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("소리 · 진동")
                        VStack(spacing: 0) {
                            toggleRow(icon: "speaker.wave.2.fill", iconColor: accent,
                                      label: "소리",
                                      caption: "카운트다운과 종료 비프음",
                                      isOn: $settings.soundEnabled)
                            rowDivider
                            toggleRow(icon: "iphone.gen2.radiowaves.left.and.right", iconColor: .pink,
                                      label: "진동",
                                      caption: "카운트다운과 종료 진동",
                                      isOn: $settings.vibrationEnabled)
                        }
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 소리 미리듣기 — 지금 켜진 소리·진동 설정 그대로 재생된다
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("소리 미리듣기")
                        VStack(spacing: 0) {
                            soundPreviewRow(icon: "3.circle.fill", iconColor: .blue,
                                            label: "카운트다운 (3·2·1)") {
                                FeedbackService.shared.countdownTick()
                            }
                            rowDivider
                            soundPreviewRow(icon: "bell.fill", iconColor: .orange,
                                            label: "운동·휴식 종료") {
                                FeedbackService.shared.phaseEndDouble()
                            }
                            rowDivider
                            soundPreviewRow(icon: "checkmark.circle.fill", iconColor: .green,
                                            label: "전체 세트 완료") {
                                FeedbackService.shared.workoutComplete()
                            }
                        }
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text("위의 소리·진동 설정이 적용된 상태로 들려요")
                            .font(.system(size: 12))
                            .foregroundStyle(TimerColor.textSecondary)
                            .padding(.leading, 4)
                    }

                    // 알림
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("알림")
                        toggleRow(icon: "bell.badge.fill", iconColor: .yellow,
                                  label: "종료 알림",
                                  caption: "백그라운드에서 운동·휴식이 끝나면 소리와 배너로 알려요",
                                  isOn: $settings.phaseAlarmEnabled)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onChange(of: settings.phaseAlarmEnabled) { enabled in
                                if enabled {
                                    NotificationService.shared.requestAuthorizationIfNeeded()
                                }
                            }
                    }

                    // 테마
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("테마")
                        HStack(spacing: 14) {
                            ForEach(AppTheme.allCases) { theme in
                                themeSwatch(theme)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 시간 입력 방식
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("시간 입력 방식")
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("시간 입력 방식", selection: $settings.timeInputStyle) {
                                ForEach(TimeInputStyle.allCases) { style in
                                    Text(style.label).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("운동·휴식 시간을 누르면 열리는 입력기를 고릅니다")
                                .font(.system(size: 12))
                                .foregroundStyle(TimerColor.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 워치 화면 스타일 — 해와 달 연출 / 심플
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("워치 화면")
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("워치 화면", selection: $settings.watchScreenStyle) {
                                ForEach(WatchScreenStyle.allCases) { style in
                                    Text(style.label).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("해와 달은 운동이 지고 휴식이 뜨는 연출, 심플은 연출 없이 숫자만 보여줘요")
                                .font(.system(size: 12))
                                .foregroundStyle(TimerColor.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 구성 요소

    /// 테마 색 견본 — 누르면 바로 적용된다
    private func themeSwatch(_ theme: AppTheme) -> some View {
        Button {
            settings.theme = theme
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: theme.bgHex))
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    .overlay(
                        Circle()
                            .stroke(accent, lineWidth: settings.theme == theme ? 2 : 0)
                            .frame(width: 44, height: 44)
                    )
                    .frame(width: 46, height: 46)

                Text(theme.label)
                    .font(.system(size: 11, weight: settings.theme == theme ? .bold : .medium))
                    .foregroundStyle(settings.theme == theme ? TimerColor.textPrimary : TimerColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.label) 테마")
        .accessibilityAddTraits(settings.theme == theme ? .isSelected : [])
    }

    private func toggleRow(icon: String, iconColor: Color, label: String, caption: String,
                           isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(Circle().fill(iconColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.fromCSSFont(16, weight: .medium))
                    .foregroundStyle(TimerColor.textPrimary)
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(TimerColor.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    /// 소리 미리듣기 행 — 행 전체를 누르면 해당 소리·진동이 재생된다
    private func soundPreviewRow(icon: String, iconColor: Color, label: String,
                                 play: @escaping () -> Void) -> some View {
        Button(action: play) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(iconColor.opacity(0.15)))

                Text(label)
                    .font(.fromCSSFont(16, weight: .medium))
                    .foregroundStyle(TimerColor.textPrimary)

                Spacer()

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TimerColor.textSecondary.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(TimerColor.textSecondary)
            .padding(.leading, 4)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 62)
    }
}

/// 전체 설정의 "시간 입력 방식"에 따라 숫자패드 또는 스크롤 휠을 보여주는 공용 시트
struct TimeInputSheet: View {
    let initialSeconds: Int
    let minSeconds: Int
    let maxSeconds: Int
    let onDone: (Int) -> Void

    var body: some View {
        if SettingManager.shared.timeInputStyle == .keypad {
            TimeKeypadSheet(initialSeconds: initialSeconds,
                            minSeconds: minSeconds,
                            maxSeconds: maxSeconds,
                            onDone: onDone)
        } else {
            TimePickerSheet(initialSeconds: initialSeconds,
                            minSeconds: minSeconds,
                            maxSeconds: maxSeconds,
                            onDone: onDone)
        }
    }
}
