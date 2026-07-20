//
//  ContentView.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/2/25.
//

import SwiftUI
import RealmSwift
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var controller: TimerController

    /// 이 페이지가 표시하는 프로그램 id — 그림 메모 저장 키로 사용 (기본 타이머는 nil)
    var programId: ObjectId?

    @ObservedObject var settings = SettingManager.shared

    @State private var showSettings = false

    // 커스텀 영역(그림 메모 / 사진 슬라이드)
    @State private var showMemoArea = false
    @State private var areaMode: CustomAreaMode = .drawing
    @State private var memoStrokes: [DrawingStroke] = []
    @State private var memoBgHex = ""   // 빈 문자열 = 투명 배경
    @State private var memoBgPhoto: UIImage?   // 메모 사진 배경 (있으면 단색보다 우선)
    @State private var memoPenHex = DrawingPalette.colors[0]
    @State private var slidePhotos: [PhotoSlideStore.Photo] = []
    @State private var photoStamp = 0   // 설정에서 사진이 바뀌면 +1

    private var memoKey: String { programId?.stringValue ?? "default" }

    /// 커스텀 영역이 열려 타이머 원이 가려진 상태 (그림 메모는 투명 배경일 때만 시간이 비친다)
    private var isMemoCoveringTimer: Bool {
        showMemoArea && (areaMode != .drawing || !memoBgHex.isEmpty || memoBgPhoto != nil)
    }

    private var isIdle: Bool {
        if case .idle = controller.state { return true }
        return false
    }

    private var isRunning: Bool {
        if case .running = controller.state { return true }
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
                ZStack {
                    if isMemoCoveringTimer {
                        // 단색 배경이 타이머를 가리므로 남은 시간을 타이틀 자리에 보여준다
                        TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
                            Text(clockString(controller.displayRemaining(at: ctx.date)))
                                .foregroundStyle(controller.phase == .time ? TimerColor.ringTime : TimerColor.ringRest)
                                .font(.fromCSSFont(36, weight: .bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .padding(.horizontal, 64)
                        }
                    } else {
                        Text(controller.timerTitle)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(TimerColor.textPrimary)
                            .font(.fromCSSFont(36, weight: .bold))
                            .lineLimit(1)
                            .padding(.horizontal, 64)
                    }

                    HStack {
                        Spacer()
                        customAreaButton
                    }
                    .padding(.trailing, 20)
                }
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
                .layoutPriority(1)   // 작은 화면에서 원이 다른 요소보다 먼저 공간을 차지
                .overlay { memoOverlay }

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

                    if showMemoArea {
                        // 그림 메모가 원의 재생 버튼을 가리므로 가운데 버튼이 재생/일시정지를 대신한다
                        Button {
                            controller.toggle()
                        } label: {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isRunning ? "일시정지" : "재생")
                    } else {
                    Button {
                        if controller.isInfiniteSets {
                            // 무한 반복은 전체 자동(Auto) 선택 불가 — 끝없이 돌지 않게 Set ↔ Manual만 순환
                            settings.autoMode = (settings.autoMode == .manual) ? .setAuto : .manual
                        } else {
                            switch settings.autoMode {
                            case .fullAuto: settings.autoMode = .setAuto
                            case .setAuto:  settings.autoMode = .manual
                            case .manual:   settings.autoMode = .fullAuto
                            }
                        }
                    } label: {
                        // 무한 반복 중 fullAuto는 setAuto로 동작하므로 표시도 Set으로 맞춘다
                        let displayMode: AutoPlayMode =
                            (controller.isInfiniteSets && settings.autoMode == .fullAuto)
                            ? .setAuto : settings.autoMode
                        VStack(spacing: 2) {
                            Image(systemName: {
                                switch displayMode {
                                case .fullAuto: return "repeat"        // 전체 자동 반복
                                case .setAuto:  return "repeat.1"      // 세트 단위 자동
                                case .manual:   return "hand.raised.fill" // 수동
                                }
                            }())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                            Text({
                                switch displayMode {
                                case .fullAuto: return "Auto"
                                case .setAuto:  return "Set"
                                case .manual:   return "Manual"
                                }
                            }())
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                        }
                    }
                    .accessibilityLabel(controller.isInfiniteSets
                                        ? "자동 모드 (무한 반복 중에는 전체 자동 사용 불가): \(settings.autoMode == .manual ? "수동" : "세트 자동")"
                                        : "자동 모드: \(settings.autoMode == .fullAuto ? "전체 자동" : settings.autoMode == .setAuto ? "세트 자동" : "수동")")
                    }

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
                                          value: controller.isInfiniteSets
                                            ? "∞"
                                            : clockString(Int(controller.customSteps.reduce(0) { $0 + $1.seconds })))
                        } else {
                            summaryColumn(label: "Timer", value: clockString(Int(controller.timeSec)))
                            summaryColumn(label: "Rest", value: clockString(Int(controller.restSec)))
                            // 무한 반복은 세트를 세지 않고 ∞만 표시한다
                            summaryColumn(label: "Set",
                                          value: controller.isInfiniteSets
                                            ? "∞"
                                            : (isIdle ? "\(controller.totalSets)" : "\(controller.setIndex)/\(controller.totalSets)"))
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

            // 전체 세트 완료 팝업 — 아무 곳이나 탭하면 닫힘
            if controller.showCompletionPopup {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { controller.showCompletionPopup = false }

                VStack(spacing: 14) {
                    Text("🎉")
                        .font(.system(size: 52))
                    Text("타이머 완료!")
                        .font(.fromCSSFont(26, weight: .bold))
                        .foregroundStyle(TimerColor.textPrimary)
                    Text("\"\(controller.timerTitle)\" 모든 세트를 끝냈어요.\n수고하셨습니다!")
                        .font(.fromCSSFont(15, weight: .medium))
                        .foregroundStyle(TimerColor.textSecondary)
                        .multilineTextAlignment(.center)
                    Text("탭하여 닫기")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TimerColor.textSecondary.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(hex: "#262C35"))
                        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 10)
                )
                .padding(.horizontal, 40)
                .onTapGesture { controller.showCompletionPopup = false }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: controller.showCompletionPopup)
        // 아래에서 위로 스와이프 → 설정 시트 (simultaneous라야 내부 버튼 탭을 먹지 않는다)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < -50,
                       abs(value.translation.height) > abs(value.translation.width) {
                        showSettings = true
                    }
                }
        )
        .sheet(isPresented: $showSettings) {
            TimerSettingsSheet(controller: controller,
                               memoKey: memoKey,
                               areaMode: $areaMode,
                               memoBgHex: $memoBgHex,
                               memoBgPhoto: $memoBgPhoto,
                               memoPenHex: $memoPenHex,
                               photoStamp: $photoStamp)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // 선 하나 그릴 때마다 바로 저장 — 앱이 어떻게 종료돼도 그림이 남는다
        .onChange(of: memoStrokes) { strokes in
            guard showMemoArea else { return }
            DrawingMemoStore.save(key: memoKey, strokes: strokes)
        }
        .onChange(of: memoBgHex) { hex in
            DrawingMemoStore.saveBackground(key: memoKey, colorHex: hex)
        }
        .onChange(of: memoPenHex) { hex in
            DrawingMemoStore.savePenColor(key: memoKey, colorHex: hex)
        }
        // 설정에서 모드를 바꾸면 저장하고, 열려 있으면 해당 모드 내용을 불러온다
        .onChange(of: areaMode) { mode in
            PhotoSlideStore.saveMode(key: memoKey, mode: mode)
            guard showMemoArea else { return }
            switch mode {
            case .drawing: memoStrokes = DrawingMemoStore.load(key: memoKey)
            case .photos:  slidePhotos = PhotoSlideStore.loadPhotos(key: memoKey)
            case .sudoku:  break   // 스도쿠는 열릴 때 저장된 진행 상태를 스스로 불러온다
            }
        }
        // 설정에서 사진을 추가/삭제하면 슬라이드를 다시 불러온다
        .onChange(of: photoStamp) { _ in
            slidePhotos = PhotoSlideStore.loadPhotos(key: memoKey)
        }
        .onAppear {
            areaMode = PhotoSlideStore.loadMode(key: memoKey)
            memoBgHex = DrawingMemoStore.loadBackground(key: memoKey)
            memoBgPhoto = DrawingMemoStore.loadBackgroundPhoto(key: memoKey)
            memoPenHex = DrawingMemoStore.loadPenColor(key: memoKey)
            #if DEBUG
            // 개발용: 샘플 그림 저장 (simctl launch ... -seedDrawing)
            if ProcessInfo.processInfo.arguments.contains("-seedDrawing") {
                let wave = stride(from: 0.0, through: 240.0, by: 8.0).map {
                    CGPoint(x: 60 + $0, y: 200 + 30 * sin($0 / 24))
                }
                DrawingMemoStore.save(key: memoKey, strokes: [
                    DrawingStroke(colorHex: "#22D3EE", lineWidth: 4, points: wave),
                    DrawingStroke(colorHex: "#F3F4F6", lineWidth: 4,
                                  points: [CGPoint(x: 80, y: 260), CGPoint(x: 280, y: 260)])
                ])
            }
            // 개발용: 메모 배경을 단색으로 저장 (simctl launch ... -seedMemoBg)
            if ProcessInfo.processInfo.arguments.contains("-seedMemoBg") {
                DrawingMemoStore.saveBackground(key: memoKey, colorHex: "#FEF3C7")
            }
            // 개발용: 메모 배경을 샘플 사진으로 저장 (simctl launch ... -seedMemoBgPhoto)
            // 9:16 세로 사진 — scaledToFill 넘침이 가장 큰 최악 케이스
            if ProcessInfo.processInfo.arguments.contains("-seedMemoBgPhoto") {
                let size = CGSize(width: 600, height: 1067)
                let img = UIGraphicsImageRenderer(size: size).image { ctx in
                    UIColor(hue: 0.75, saturation: 0.5, brightness: 0.75, alpha: 1).setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    UIColor(hue: 0.12, saturation: 0.7, brightness: 0.95, alpha: 1).setFill()
                    UIBezierPath(ovalIn: CGRect(x: 150, y: 250, width: 300, height: 300)).fill()
                }
                if let data = img.jpegData(compressionQuality: 0.9) {
                    DrawingMemoStore.saveBackgroundPhoto(key: memoKey, imageData: data)
                }
            }
            // 개발용: 커스텀 영역 모드 전환 (simctl launch ... -photoMode / -drawMode)
            if ProcessInfo.processInfo.arguments.contains("-photoMode") {
                PhotoSlideStore.saveMode(key: memoKey, mode: .photos)
                areaMode = .photos
            }
            if ProcessInfo.processInfo.arguments.contains("-drawMode") {
                PhotoSlideStore.saveMode(key: memoKey, mode: .drawing)
                areaMode = .drawing
            }
            // 개발용: 샘플 사진 채우기 (simctl launch ... -seedPhotos)
            if ProcessInfo.processInfo.arguments.contains("-seedPhotos"),
               PhotoSlideStore.loadPhotos(key: memoKey).isEmpty {
                for (hue, label) in [(0.58, "1"), (0.33, "2"), (0.08, "3")] {
                    let size = CGSize(width: 600, height: 800)
                    let img = UIGraphicsImageRenderer(size: size).image { _ in
                        UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1).setFill()
                        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
                        (label as NSString).draw(at: CGPoint(x: 260, y: 340),
                                                 withAttributes: [.font: UIFont.boldSystemFont(ofSize: 120),
                                                                  .foregroundColor: UIColor.white])
                    }
                    if let data = img.jpegData(compressionQuality: 0.9) {
                        PhotoSlideStore.addPhoto(key: memoKey, imageData: data)
                    }
                }
            }
            // 개발용: 그림 메모 영역을 바로 연다 (simctl launch ... -openMemo)
            if ProcessInfo.processInfo.arguments.contains("-openMemo"), !showMemoArea {
                toggleMemoArea()
            }
            // 개발용: 설정 시트를 바로 연다 (simctl launch ... -openSettings)
            if ProcessInfo.processInfo.arguments.contains("-openSettings") {
                showSettings = true
            }
            #endif
        }
    }

    // MARK: - 커스텀 영역 (그림 메모 / 사진 슬라이드)

    /// 타이틀 오른쪽 커스텀 버튼 — 탭하면 타이머 위에 커스텀 영역을 열고 닫는다
    private var customAreaButton: some View {
        Button {
            toggleMemoArea()
        } label: {
            Image(systemName: showMemoArea ? "xmark" : areaMode.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(
                    Circle().stroke(Color.white.opacity(showMemoArea ? 0.7 : 0.35), lineWidth: 1.5)
                )
                // 시각은 30pt 원이지만 탭 영역은 44pt로 넓혀 놓친 탭을 막는다
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showMemoArea ? "\(areaMode.label) 닫기" : "\(areaMode.label) 열기")
    }

    /// 타이머 사각 영역 위에 겹치는 커스텀 영역 — 그림 메모(투명이면 시간이 비침) 또는 사진 슬라이드
    @ViewBuilder
    private var memoOverlay: some View {
        if showMemoArea {
            Group {
                switch areaMode {
                case .drawing:
                    DrawingMemoCanvas(strokes: $memoStrokes, penColorHex: memoPenHex)
                        .background {
                            if let photo = memoBgPhoto {
                                // scaledToFill로 넘친 부분은 clipShape가 "그림"만 잘라내고
                                // 터치 판정은 남아 X/재생 버튼 탭을 먹는다 → 히트테스트 자체를 끈다
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .allowsHitTesting(false)
                            } else if !memoBgHex.isEmpty {
                                Color(hex: memoBgHex)
                            }
                        }
                case .photos:
                    PhotoSlideView(memoKey: memoKey, photos: slidePhotos, photoStamp: $photoStamp)
                case .sudoku:
                    SudokuView(memoKey: memoKey)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        }
    }

    private func toggleMemoArea() {
        if showMemoArea {
            if areaMode == .drawing {
                DrawingMemoStore.save(key: memoKey, strokes: memoStrokes)
            }
        } else {
            switch areaMode {
            case .drawing:
                memoStrokes = DrawingMemoStore.load(key: memoKey)
                memoBgHex = DrawingMemoStore.loadBackground(key: memoKey)
                memoBgPhoto = DrawingMemoStore.loadBackgroundPhoto(key: memoKey)
                memoPenHex = DrawingMemoStore.loadPenColor(key: memoKey)
            case .photos:
                slidePhotos = PhotoSlideStore.loadPhotos(key: memoKey)
            case .sudoku:
                break   // 스도쿠는 열릴 때 저장된 진행 상태를 스스로 불러온다
            }
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showMemoArea.toggle()
        }
        // 열려 있는 동안엔 그림/사진 스와이프가 페이지 넘김으로 새지 않도록
        CustomAreaState.shared.isOpen = showMemoArea
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
    /// 커스텀 영역 저장 키 (프로그램 id, 기본 타이머는 "default")
    var memoKey: String = "default"
    /// 커스텀 영역 모드 (그림 메모 / 사진)
    @Binding var areaMode: CustomAreaMode
    /// 그림 메모 배경색 (빈 문자열 = 투명)
    @Binding var memoBgHex: String
    /// 그림 메모 사진 배경 (있으면 단색보다 우선)
    @Binding var memoBgPhoto: UIImage?
    /// 그림 메모 펜 색
    @Binding var memoPenHex: String
    /// 사진 추가/삭제 신호 — ContentView가 슬라이드를 다시 불러온다
    @Binding var photoStamp: Int
    @ObservedObject private var settings = SettingManager.shared

    @State private var title: String = ""
    @State private var timeSec: Int = 30
    @State private var restSec: Int = 10
    @State private var sets: Int = 3

    @State private var editingField: EditingField?
    @State private var showStepEditor = false
    @State private var bgPickerItem: PhotosPickerItem?
    @State private var timeColor: Color = TimerColor.ringTime   // 운동 링 색
    @State private var restColor: Color = TimerColor.ringRest   // 휴식 링 색
    @State private var colorTarget: ColorTarget?                // 색상 선택기를 띄운 대상

    private enum EditingField: Identifiable {
        case time, rest, sets
        var id: Self { self }
    }

    /// 링 색상 행을 눌렀을 때 어떤 링의 색을 고르는지
    private enum ColorTarget: Identifiable {
        case time, rest
        var id: Self { self }
    }

    private let accent = Color(hex: "#22D3EE")

    private var isInfinite: Bool { sets == TimerController.infiniteSets }

    private var totalSec: Int {
        if controller.isCustomMode {
            return Int(controller.customSteps.reduce(0) { $0 + $1.seconds })
        }
        if isInfinite { return 0 }   // 무한 반복 — 표시 시 ∞로 대체
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
                                       label: "단계 구성",
                                       value: controller.isInfiniteSets
                                        ? "\(controller.customSteps.count)단계 · ∞"
                                        : "\(controller.customSteps.count)단계") {
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
                                       label: "세트", value: isInfinite ? "∞" : "\(sets)") {
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

                // 링 색상 — 원형 타이머 · 다이나믹 아일랜드 · 워치에 함께 반영
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("링 색상")
                    VStack(spacing: 0) {
                        colorRow(icon: "timer", iconColor: timeColor,
                                 label: "운동 링", selection: $timeColor) {
                            colorTarget = .time
                        }
                        rowDivider
                        colorRow(icon: "pause.circle.fill", iconColor: restColor,
                                 label: "휴식 링", selection: $restColor) {
                            colorTarget = .rest
                        }
                    }
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // 종료 알림·소리 미리듣기는 전체 설정(메인 상단 톱니바퀴)으로 옮겼다

                // 커스텀 영역 (그림 메모 / 사진 슬라이드)
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("타이머 위 영역")
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("모드", selection: $areaMode) {
                            ForEach(CustomAreaMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch areaMode {
                        case .drawing:
                            VStack(alignment: .leading, spacing: 4) {
                                Text("펜 색상")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TimerColor.textSecondary)
                                HStack(spacing: 10) {
                                    ForEach(DrawingPalette.colors, id: \.self) { hex in
                                        colorSwatch(hex, selected: memoPenHex == hex) {
                                            memoPenHex = hex
                                        }
                                    }
                                    Spacer()
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("배경")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TimerColor.textSecondary)
                                HStack(spacing: 10) {
                                    colorSwatch("", selected: memoBgPhoto == nil && memoBgHex.isEmpty) {
                                        memoBgHex = ""
                                        clearBgPhoto()
                                    }
                                    ForEach(DrawingPalette.backgrounds, id: \.self) { hex in
                                        colorSwatch(hex, selected: memoBgPhoto == nil && memoBgHex == hex) {
                                            memoBgHex = hex
                                            clearBgPhoto()
                                        }
                                    }
                                    bgPhotoSwatch
                                    Spacer()
                                }
                            }

                            memoPreview
                        case .photos:
                            PhotoManageGrid(memoKey: memoKey, photoStamp: $photoStamp)
                        case .sudoku:
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.3x3")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(TimerColor.textSecondary)
                                Text("타이머 위에서 스도쿠를 풀 수 있어요. 난이도 선택과 새 게임은 영역 안에서 조절해요")
                                    .font(.system(size: 13))
                                    .foregroundStyle(TimerColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(areaMode == .drawing
                         ? "단색이나 사진 배경을 고르면 타이머가 가려지는 대신 남은 시간이 상단에 표시돼요"
                         : "영역이 열려 있는 동안 남은 시간이 상단에 표시돼요")
                        .font(.system(size: 12))
                        .foregroundStyle(TimerColor.textSecondary)
                        .padding(.leading, 4)
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
                    Text((controller.isCustomMode ? controller.isInfiniteSets : isInfinite) ? "∞" : mmss(totalSec))
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
                TimeInputSheet(initialSeconds: timeSec, minSeconds: 1, maxSeconds: 59*60+59) { timeSec = $0 }
                    .presentationDetents([.medium])
            case .rest:
                TimeInputSheet(initialSeconds: restSec, minSeconds: 0, maxSeconds: 59*60+59) { restSec = $0 }
                    .presentationDetents([.medium])
            case .sets:
                SetsPickerSheet(title: "세트", initial: sets, minSets: 1, maxSets: 99, allowInfinite: true) { sets = $0 }
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showStepEditor) {
            StepEditorSheet(controller: controller)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $colorTarget) { target in
            NativeColorPickerSheet(color: target == .time ? $timeColor : $restColor)
                .ignoresSafeArea()
        }
        .onAppear {
            title = controller.timerTitle
            timeSec = max(1, Int(controller.timeSec))
            restSec = max(0, Int(controller.restSec))
            sets = max(1, controller.totalSets)
            timeColor = Color(hex: controller.timeColorHex.isEmpty ? TimerColor.defaultTimeHex : controller.timeColorHex)
            restColor = Color(hex: controller.restColorHex.isEmpty ? TimerColor.defaultRestHex : controller.restColorHex)
        }
        // 색을 고르는 즉시 링에 반영 (컨트롤러 갱신 → 원형/아일랜드/워치는 닫을 때 저장)
        .onChange(of: timeColor) { newVal in
            controller.updateColors(timeColorHex: newVal.toHex(), restColorHex: restColor.toHex())
        }
        .onChange(of: restColor) { newVal in
            controller.updateColors(timeColorHex: timeColor.toHex(), restColorHex: newVal.toHex())
        }
        // 배경 사진 선택 → 축소 저장 후 즉시 반영
        .onChange(of: bgPickerItem) { item in
            guard let item else { return }
            bgPickerItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = DrawingMemoStore.saveBackgroundPhoto(key: memoKey, imageData: data)
                else { return }
                await MainActor.run { memoBgPhoto = image }
            }
        }
        // 어떤 방식으로 닫혀도(완료 버튼, 아래로 스와이프) 변경분이 있으면 저장
        .onDisappear {
            apply()
        }
    }

    /// 색상 선택 원 (빈 문자열 = 투명)
    private func colorSwatch(_ hex: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if hex.isEmpty {
                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    Image(systemName: "line.diagonal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.75))
                } else {
                    Circle().fill(Color(hex: hex))
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
            }
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(accent, lineWidth: selected ? 2 : 0)
                    .frame(width: 38, height: 38)
            )
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hex.isEmpty ? "투명" : "색상 \(hex)")
    }

    /// 사진 배경 선택 원 — 선택된 사진이 있으면 썸네일로 표시
    private var bgPhotoSwatch: some View {
        PhotosPicker(selection: $bgPickerItem, matching: .images) {
            ZStack {
                if let photo = memoBgPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else {
                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(accent, lineWidth: memoBgPhoto != nil ? 2 : 0)
                    .frame(width: 38, height: 38)
            )
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("사진 배경 선택")
    }

    private func clearBgPhoto() {
        guard memoBgPhoto != nil else { return }
        DrawingMemoStore.clearBackgroundPhoto(key: memoKey)
        memoBgPhoto = nil
    }

    /// 선택한 배경 + 펜 색 미리보기 — 투명 배경이면 뒤로 타이머가 비치는 느낌을 준다
    private var memoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(memoBgHex.isEmpty ? TimerColor.bg : Color(hex: memoBgHex))

            if let photo = memoBgPhoto {
                GeometryReader { geo in
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        // 넘친 터치 판정이 주변 색상 버튼 탭을 먹지 않도록
                        .allowsHitTesting(false)
                }
            } else if memoBgHex.isEmpty {
                Text("00 : 41")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(TimerColor.textPrimary.opacity(0.3))
            }

            Text("test")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .italic()
                .foregroundStyle(Color(hex: memoPenHex))
                .rotationEffect(.degrees(-6))
        }
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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

    /// 링 색 선택 행 — 행 전체를 누르면 색상 선택기가 열린다
    private func colorRow(icon: String, iconColor: Color, label: String,
                          selection: Binding<Color>,
                          onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
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

                // 현재 선택된 색 미리보기
                Circle()
                    .fill(selection.wrappedValue)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TimerColor.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 컨트롤러 적용 + 활성 프로그램(Realm)에도 저장
    private func apply() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let finalTitle = trimmed.isEmpty ? controller.timerTitle : trimmed

        // 링 색상은 진행 상태와 무관하게 항상 반영 (앱·아일랜드·워치 공통)
        applyColorsIfNeeded()

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
        // 색은 위 applyColorsIfNeeded에서 이미 반영됐으므로 현재 값을 그대로 넘겨 유지한다
        controller.stop()
        controller.configure(title: finalTitle, time: timeSec, rest: restSec, sets: sets,
                             timeColorHex: controller.timeColorHex,
                             restColorHex: controller.restColorHex)
        controller.saveLastUsed()

        // 활성 타이머가 있으면 Realm에도 반영
        guard let id = ActiveProgramStore.activeId(),
              let realm = try? Realm(),
              let p = realm.object(ofType: RTimerProgram.self, forPrimaryKey: id) else { return }
        try? realm.write {
            p.title = finalTitle
            p.infiniteSets = isInfinite
            p.steps.removeAll()
            // 무한 반복은 time/rest 한 쌍만 저장하고 플래그로 표현한다
            for _ in 0..<(isInfinite ? 1 : sets) {
                let t = RStep(); t.kindRaw = "time"; t.seconds = timeSec
                let r = RStep(); r.kindRaw = "rest"; r.seconds = restSec
                p.steps.append(t)
                p.steps.append(r)
            }
        }
    }

    /// 링 색이 바뀌었으면 컨트롤러(→아일랜드/워치)와 활성 프로그램(Realm)에 반영.
    /// 진행 중인 타이머는 멈추지 않고 색만 갱신한다.
    private func applyColorsIfNeeded() {
        let timeHex = timeColor.toHex()
        let restHex = restColor.toHex()

        // 링(컨트롤러)에는 onChange로 이미 실시간 반영됨 — 여기선 최종값 확정 + 영속화
        controller.updateColors(timeColorHex: timeHex, restColorHex: restHex)

        guard let id = ActiveProgramStore.activeId(),
              let realm = try? Realm(),
              let p = realm.object(ofType: RTimerProgram.self, forPrimaryKey: id) else { return }
        // 저장된 값과 다를 때만 기록 (onChange로 컨트롤러는 이미 같을 수 있으므로 Realm 기준 비교)
        guard p.timeColorHex != timeHex || p.restColorHex != restHex else { return }
        try? realm.write {
            p.timeColorHex = timeHex
            p.restColorHex = restHex
        }
        // 바뀐 색을 워치로도 즉시 반영
        PhoneConnectivity.shared.resyncFromRealm(autoModeRaw: settings.autoMode.rawValue)
    }
}

/// 행 전체 탭으로 열 수 있는 네이티브 색상 선택기.
/// SwiftUI의 ColorPicker는 스와치를 눌러야만 열려서, 프로그램적으로 띄우기 위해 UIKit 선택기를 감싼다.
struct NativeColorPickerSheet: UIViewControllerRepresentable {
    @Binding var color: Color
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let vc = UIColorPickerViewController()
        vc.selectedColor = UIColor(color)
        vc.supportsAlpha = false
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        let parent: NativeColorPickerSheet
        init(_ parent: NativeColorPickerSheet) { self.parent = parent }

        func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                       didSelect color: UIColor, continuously: Bool) {
            parent.color = Color(color)
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            parent.dismiss()
        }
    }
}
