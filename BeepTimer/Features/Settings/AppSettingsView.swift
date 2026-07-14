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

    /// 워치 색상 편집 대상 (색상 선택기 시트용)
    private enum WatchColorField: Int, Identifiable {
        case bg, time, rest
        var id: Int { rawValue }
    }
    @State private var pickerField: WatchColorField?

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

                    // 워치 화면 색상 — 모든 타이머에 통일 적용 (배경 / 운동 / 휴식)
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("워치 화면 색상")

                        watchPreview
                            .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            watchColorRow(icon: "square.fill", label: "뒷배경",
                                          hex: settings.watchBgColorHex, field: .bg)
                            rowDivider
                            watchColorRow(icon: "figure.run", label: "운동(타이머)",
                                          hex: settings.watchTimeColorHex, field: .time)
                            rowDivider
                            watchColorRow(icon: "pause.circle.fill", label: "휴식",
                                          hex: settings.watchRestColorHex, field: .rest)
                        }
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text("애플워치의 모든 타이머에 이 세 가지 색이 통일 적용돼요")
                            .font(.system(size: 12))
                            .foregroundStyle(TimerColor.textSecondary)
                            .padding(.leading, 4)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(item: $pickerField) { field in
            NativeColorPickerSheet(color: colorBinding(for: field))
                .ignoresSafeArea()
        }
    }

    // MARK: - 워치 색상

    /// 워치 실행 화면을 흉내 낸 미리보기 — 배경·운동·휴식 색이 실시간 반영된다
    private var watchPreview: some View {
        let bg = Color(hex: settings.watchBgColorHex)
        let time = Color(hex: settings.watchTimeColorHex)
        let rest = Color(hex: settings.watchRestColorHex)
        return ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(bg)
            VStack(spacing: 6) {
                Text("00:30")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(time)
                HStack(spacing: 10) {
                    Text("30s").foregroundStyle(time)
                    Text("1/3").foregroundStyle(.white.opacity(0.6))
                    Text("15s").foregroundStyle(rest)
                }
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    /// 색 한 줄 — 누르면 색상 선택기가 열린다
    private func watchColorRow(icon: String, label: String, hex: String,
                               field: WatchColorField) -> some View {
        Button {
            pickerField = field
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.12)))

                Text(label)
                    .font(.fromCSSFont(16, weight: .medium))
                    .foregroundStyle(TimerColor.textPrimary)

                Spacer()

                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TimerColor.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func colorBinding(for field: WatchColorField) -> Binding<Color> {
        let hex: Binding<String>
        switch field {
        case .bg:   hex = $settings.watchBgColorHex
        case .time: hex = $settings.watchTimeColorHex
        case .rest: hex = $settings.watchRestColorHex
        }
        return Binding(get: { Color(hex: hex.wrappedValue) },
                       set: { hex.wrappedValue = $0.toHex() })
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
