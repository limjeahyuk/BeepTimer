//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI
import RealmSwift

struct ContentView: View {
    @EnvironmentObject var controller: TimerController

    @ObservedObject var settings = SettingManager.shared

    @State private var showSettings = false

    private var isIdle: Bool {
        if case .idle = controller.state { return true }
        return false
    }

    func mmss(_ sec: Int) -> String {
        let s = max(0, sec)
        let m = s / 60
        let ss = s % 60
        return String(format: "%02d : %02d", m, ss)
    }
    
    func clockString(_ total: Int) -> String {
        let s = max(0, total)
        if s >= 3600 {
            let h = s / 3600
            let m = (s % 3600) / 60
            let ss = s % 60
            return String(format: "%02d : %02d : %02d", h, m, ss)
        }else{
            return mmss(s)
        }
    }

    var body: some View {
        ZStack {
            // 화면 전체 색상.
            TimerColor.bg
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(controller.timerTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(TimerColor.textPrimary)
                .font(.fromCSSFont(36, weight: .bold))
                .lineLimit(1)
                .padding(.horizontal, 40)
                .padding(.top, 48)   // 상단 바(+ / 인디케이터 / 리스트)와 겹치지 않도록

                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let ringWidth = max(22, side * 0.06)
                    
                    // 타이머 영역
                    CircleTimerView(controller: controller, ringWidth: ringWidth)
                        .frame(width: side - 24, height: side - 24)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                
                HStack(spacing: 24){
                    
                    Button {
                        logger.d("backward fill")
                        controller.rewind()
                    } label: {
                        Image(systemName: "backward.fill")
                            .resizable()
                            .frame(width: 22, height: 18)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("한 번: 현재 타이머 처음으로, 두 번: 세트 초기화")
                    
                    Spacer()
                    
                    Button {
                        switch settings.autoMode {
                        case .fullAuto: settings.autoMode = .setAuto
                        case .setAuto:  settings.autoMode = .manual
                        case .manual:   settings.autoMode = .fullAuto
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: {
                                switch settings.autoMode {
                                case .fullAuto: "repeat"        // 전체 자동 반복
                                case .setAuto:  "repeat.1"      // 세트 단위 자동
                                case .manual:   "hand.raised.fill" // 수동
                                }
                            }())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                            Text({
                                switch settings.autoMode {
                                case .fullAuto: "Auto"
                                case .setAuto:  "Set"
                                case .manual:   "Manual"
                                }
                            }())
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                        }
                    }
                    .accessibilityLabel("자동 모드: \(settings.autoMode == .fullAuto ? "전체 자동" : settings.autoMode == .setAuto ? "세트 자동" : "수동")")
                    
                    Spacer()
                    
                    Button {
                        logger.d("forward fill")
                        if !controller.nextSet() {
                            logger.d("end point")
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                            .resizable()
                            .frame(width: 22, height: 18)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                }
                .frame(height: 48)
                .frame(maxWidth: 220, alignment: .center)
                .padding(.horizontal, 40)
                .background(
                    ZStack {
                        Capsule().fill(.ultraThinMaterial).opacity(0.18)
                        Capsule().fill(Color.white.opacity(0.22))
                    }
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
                .foregroundStyle(Color.white)

                // 설정 요약 (탭 또는 위로 스와이프 → 설정 시트)
                VStack(spacing: 20) {
                    HStack(spacing: 0) {
                        if controller.isCustomMode {
                            summaryColumn(label: "단계",
                                          value: isIdle
                                            ? "\(controller.customSteps.count)"
                                            : "\(controller.stepIndex + 1)/\(controller.customSteps.count)")
                            summaryColumn(label: "총 시간",
                                          value: clockString(Int(controller.customSteps.reduce(0) { $0 + $1.seconds })))
                        } else {
                            summaryColumn(label: "Timer", value: clockString(Int(controller.timeSec)))
                            summaryColumn(label: "Rest", value: clockString(Int(controller.restSec)))
                            summaryColumn(label: "Set",
                                          value: isIdle ? "\(controller.totalSets)" : "\(controller.setIndex)/\(controller.totalSets)")
                        }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        Image(systemName: "chevron.compact.up")
                        Text("위로 밀어서 설정")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TimerColor.textSecondary.opacity(0.6))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    showSettings = true
                }

            }
        }
        // 아래에서 위로 스와이프 → 설정 시트
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < -50,
                       abs(value.translation.height) > abs(value.translation.width) {
                        showSettings = true
                    }
                }
        )
        .sheet(isPresented: $showSettings) {
            TimerSettingsSheet(controller: controller)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func summaryColumn(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.fromCSSFont(14, weight: .medium))
                .foregroundStyle(TimerColor.textSecondary)
            Text(value)
                .font(.fromCSSFont(24, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(TimerColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 타이머 설정 시트 (이름/시간/휴식/세트 편집)

struct TimerSettingsSheet: View {
    @ObservedObject var controller: TimerController
    @ObservedObject private var settings = SettingManager.shared

    @State private var title: String = ""
    @State private var timeSec: Int = 30
    @State private var restSec: Int = 10
    @State private var sets: Int = 3

    @State private var editingField: EditingField?
    @State private var showStepEditor = false

    private enum EditingField: Identifiable {
        case time, rest, sets
        var id: Self { self }
    }

    private let accent = Color(hex: "#22D3EE")

    private var totalSec: Int {
        if controller.isCustomMode {
            return Int(controller.customSteps.reduce(0) { $0 + $1.seconds })
        }
        return (timeSec + restSec) * sets
    }

    private func mmss(_ s: Int) -> String {
        let v = max(0, s)
        if v >= 3600 {
            return String(format: "%d:%02d:%02d", v / 3600, (v % 3600) / 60, v % 60)
        }
        return String(format: "%02d:%02d", v / 60, v % 60)
    }

    var body: some View {
        ZStack {
            TimerColor.bg.ignoresSafeArea()

            ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 헤더
                Text("타이머 설정")
                    .font(.fromCSSFont(22, weight: .bold))
                    .foregroundStyle(TimerColor.textPrimary)
                    .padding(.top, 40)

                // 이름
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("이름")
                    HStack(spacing: 10) {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TimerColor.textSecondary)
                        TextField("타이머 이름", text: $title)
                            .textFieldStyle(.plain)
                            .font(.fromCSSFont(18, weight: .semibold))
                            .foregroundStyle(TimerColor.textPrimary)
                            .disableAutocorrection(true)
                            .submitLabel(.done)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // 시간 구성
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("시간 구성")
                    VStack(spacing: 0) {
                        if controller.isCustomMode {
                            // 상세 모드: 단계 구성으로만 편집
                            settingRow(icon: "list.number", iconColor: .purple,
                                       label: "단계 구성", value: "\(controller.customSteps.count)단계") {
                                showStepEditor = true
                            }
                        } else {
                            settingRow(icon: "timer", iconColor: accent,
                                       label: "운동 시간", value: mmss(timeSec)) {
                                editingField = .time
                            }
                            rowDivider
                            settingRow(icon: "pause.circle.fill", iconColor: .orange,
                                       label: "휴식 시간", value: mmss(restSec)) {
                                editingField = .rest
                            }
                            rowDivider
                            settingRow(icon: "repeat", iconColor: .green,
                                       label: "세트", value: "\(sets)") {
                                editingField = .sets
                            }
                            rowDivider
                            settingRow(icon: "slider.horizontal.3", iconColor: .purple,
                                       label: "상세 설정", value: "") {
                                showStepEditor = true
                            }
                        }
                    }
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // 알림
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("알림")
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.yellow.opacity(0.15)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("종료 알림")
                                .font(.fromCSSFont(16, weight: .medium))
                                .foregroundStyle(TimerColor.textPrimary)
                            Text("운동·휴식이 끝날 때 소리와 배너로 알려요")
                                .font(.system(size: 12))
                                .foregroundStyle(TimerColor.textSecondary)
                        }

                        Spacer()

                        Toggle("", isOn: $settings.phaseAlarmEnabled)
                            .labelsHidden()
                            .tint(accent)
                            .onChange(of: settings.phaseAlarmEnabled) { enabled in
                                if enabled {
                                    NotificationService.shared.requestAuthorizationIfNeeded()
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // 총 시간 미리보기
                HStack {
                    Image(systemName: "sum")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TimerColor.textSecondary)
                    Text("총 시간")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TimerColor.textSecondary)
                    Spacer()
                    Text(mmss(totalSec))
                        .font(.fromCSSFont(20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(TimerColor.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            }
        }
        .sheet(item: $editingField) { field in
            switch field {
            case .time:
                TimePickerSheet(initialSeconds: timeSec, minSeconds: 1, maxSeconds: 59*60+59) { timeSec = $0 }
                    .presentationDetents([.medium])
            case .rest:
                TimePickerSheet(initialSeconds: restSec, minSeconds: 0, maxSeconds: 59*60+59) { restSec = $0 }
                    .presentationDetents([.medium])
            case .sets:
                SetsPickerSheet(title: "세트", initial: sets, minSets: 1, maxSets: 99) { sets = $0 }
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showStepEditor) {
            StepEditorSheet(controller: controller)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            title = controller.timerTitle
            timeSec = max(1, Int(controller.timeSec))
            restSec = max(0, Int(controller.restSec))
            sets = max(1, controller.totalSets)
        }
        // 어떤 방식으로 닫혀도(완료 버튼, 아래로 스와이프) 변경분이 있으면 저장
        .onDisappear {
            apply()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(TimerColor.textSecondary)
            .padding(.leading, 4)
    }

    private func settingRow(icon: String, iconColor: Color, label: String, value: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

                Text(value)
                    .font(.fromCSSFont(20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(accent)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TimerColor.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 62)
    }

    /// 컨트롤러 적용 + 활성 프로그램(Realm)에도 저장
    private func apply() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let finalTitle = trimmed.isEmpty ? controller.timerTitle : trimmed

        // 상세(커스텀) 모드: 단계는 상세 편집기가 관리하므로 이름만 반영
        if controller.isCustomMode {
            guard finalTitle != controller.timerTitle else { return }
            controller.timerTitle = finalTitle
            if let id = ActiveProgramStore.activeId(),
               let realm = try? Realm(),
               let p = realm.object(ofType: RTimerProgram.self, forPrimaryKey: id) {
                try? realm.write { p.title = finalTitle }
            }
            return
        }

        // 아무것도 바뀌지 않았으면 진행 중인 타이머를 건드리지 않는다
        let unchanged = finalTitle == controller.timerTitle
            && timeSec == Int(controller.timeSec)
            && restSec == Int(controller.restSec)
            && sets == controller.totalSets
        guard !unchanged else { return }

        // 변경 시: 완전히 멈추고 새 설정으로 초기화 (재시작은 사용자가 직접)
        controller.stop()
        controller.configure(title: finalTitle, time: timeSec, rest: restSec, sets: sets)
        controller.saveLastUsed()

        // 활성 타이머가 있으면 Realm에도 반영
        guard let id = ActiveProgramStore.activeId(),
              let realm = try? Realm(),
              let p = realm.object(ofType: RTimerProgram.self, forPrimaryKey: id) else { return }
        try? realm.write {
            p.title = finalTitle
            p.steps.removeAll()
            for _ in 0..<sets {
                let t = RStep(); t.kindRaw = "time"; t.seconds = timeSec
                let r = RStep(); r.kindRaw = "rest"; r.seconds = restSec
                p.steps.append(t)
                p.steps.append(r)
            }
        }
    }
}
