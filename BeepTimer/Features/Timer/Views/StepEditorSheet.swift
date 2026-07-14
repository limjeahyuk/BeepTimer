//
//  StepEditorSheet.swift
//  BeepTimer
//
//  상세 설정: 단계(운동/휴식)를 하나하나 직접 구성하는 편집기.
//  예) 1분 팔굽혀펴기 → 10초 휴식 → 1분 10초 턱걸이 → 20초 휴식 ...
//

import SwiftUI
import RealmSwift

struct StepEditorSheet: View {
    @ObservedObject var controller: TimerController
    @Environment(\.dismiss) private var dismiss

    struct EditStep: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var isRest: Bool
        var seconds: Int
    }

    @State private var steps: [EditStep] = []
    @State private var initialSteps: [EditStep] = []
    @State private var loopForever = false          // 무한 반복 (마지막 단계 후 처음으로)
    @State private var initialLoop = false
    @State private var editingDuration: DurationTarget?
    @State private var isEditing = false            // 편집 모드: − 탭으로 즉시 삭제 + 순서 이동

    /// 시간 피커가 적용될 대상 (단계 하나 / 운동 전체 / 휴식 전체)
    private enum DurationTarget: Identifiable {
        case step(id: UUID, seconds: Int)
        case allTime(seconds: Int)
        case allRest(seconds: Int)

        var id: String {
            switch self {
            case .step(let id, _): return id.uuidString
            case .allTime:         return "allTime"
            case .allRest:         return "allRest"
            }
        }

        var seconds: Int {
            switch self {
            case .step(_, let s), .allTime(let s), .allRest(let s): return s
            }
        }
    }

    private let accent = Color(hex: "#22D3EE")

    private var totalSec: Int { steps.reduce(0) { $0 + $1.seconds } }

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

            VStack(alignment: .leading, spacing: 16) {
                // 헤더
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("상세 설정")
                            .font(.fromCSSFont(22, weight: .bold))
                            .foregroundStyle(TimerColor.textPrimary)
                        Text("단계마다 이름과 시간을 자유롭게 구성하세요")
                            .font(.system(size: 13))
                            .foregroundStyle(TimerColor.textSecondary)
                    }
                    Spacer()
                    Button(isEditing ? "완료" : "편집") {
                        withAnimation { isEditing.toggle() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .tint(accent)
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)

                // 단계 리스트
                List {
                    ForEach($steps) { $step in
                        stepRow($step)
                            .listRowBackground(Color.white.opacity(0.06))
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                            // 평상시 스와이프 삭제: 아이콘 없이 텍스트만, 노출 후 한 번 더 눌러 삭제
                            // (편집 중엔 커스텀 −가 담당하므로 스와이프는 뺀다)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if !isEditing {
                                    Button(role: .destructive) {
                                        let id = step.id
                                        withAnimation { steps.removeAll { $0.id == id } }
                                    } label: {
                                        Text("삭제")
                                    }
                                }
                            }
                    }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 56)
                // 편집 모드는 순서 이동 손잡이 표시용 — 삭제는 커스텀 − 버튼이 담당
                .environment(\.editMode, .constant(isEditing ? .active : .inactive))

                // 일괄 적용 + 추가 버튼 + 총 시간
                VStack(spacing: 12) {
                    if steps.count > 1 {
                        HStack(spacing: 10) {
                            Text("시간 일괄 적용")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TimerColor.textSecondary)
                            Spacer()
                            if let first = steps.first(where: { !$0.isRest }) {
                                bulkButton(label: "운동", color: accent) {
                                    editingDuration = .allTime(seconds: first.seconds)
                                }
                            }
                            if let first = steps.first(where: { $0.isRest }) {
                                bulkButton(label: "휴식", color: .orange) {
                                    editingDuration = .allRest(seconds: first.seconds)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    HStack(spacing: 10) {
                        addButton(label: "운동 추가", icon: "timer", color: accent) {
                            steps.append(EditStep(title: "", isRest: false, seconds: 60))
                        }
                        addButton(label: "휴식 추가", icon: "pause.circle.fill", color: .orange) {
                            steps.append(EditStep(title: "", isRest: true, seconds: 15))
                        }
                    }

                    // 무한 반복: 마지막 단계가 끝나면 첫 단계부터 다시
                    HStack(spacing: 8) {
                        Image(systemName: "infinity")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                        Text("무한 반복")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TimerColor.textPrimary)
                        Spacer()
                        Toggle("", isOn: $loopForever)
                            .labelsHidden()
                            .tint(accent)
                    }
                    .padding(.horizontal, 4)

                    HStack {
                        Text("총 시간")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TimerColor.textSecondary)
                        Spacer()
                        Text(loopForever ? "∞" : mmss(totalSec))
                            .font(.fromCSSFont(20, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(TimerColor.textPrimary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $editingDuration) { editing in
            TimeInputSheet(initialSeconds: editing.seconds, minSeconds: 1, maxSeconds: 59*60+59) { newValue in
                switch editing {
                case .step(let id, _):
                    if let idx = steps.firstIndex(where: { $0.id == id }) {
                        steps[idx].seconds = newValue
                    }
                case .allTime:
                    for idx in steps.indices where !steps[idx].isRest {
                        steps[idx].seconds = newValue
                    }
                case .allRest:
                    for idx in steps.indices where steps[idx].isRest {
                        steps[idx].seconds = newValue
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear { load() }
        .onDisappear { save() }
    }

    // MARK: - Rows

    private func stepRow(_ step: Binding<EditStep>) -> some View {
        HStack(spacing: 10) {
            // 편집 모드: − 탭으로 바로 삭제 (한 번 더 확인하지 않는다)
            if isEditing {
                Button {
                    let id = step.wrappedValue.id
                    withAnimation { steps.removeAll { $0.id == id } }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("단계 바로 삭제")
            }

            // 종류 토글 (운동 ↔ 휴식)
            Button {
                step.wrappedValue.isRest.toggle()
            } label: {
                Text(step.wrappedValue.isRest ? "휴식" : "운동")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(step.wrappedValue.isRest ? Color.orange : accent)
                    .frame(width: 44, height: 26)
                    .background(
                        Capsule().fill((step.wrappedValue.isRest ? Color.orange : accent).opacity(0.15))
                    )
            }
            .buttonStyle(.plain)

            // 단계 이름
            TextField(step.wrappedValue.isRest ? "휴식" : "운동 이름", text: step.title)
                .textFieldStyle(.plain)
                .font(.fromCSSFont(16, weight: .medium))
                .foregroundStyle(TimerColor.textPrimary)
                .disableAutocorrection(true)
                .submitLabel(.done)

            Spacer(minLength: 4)

            // 시간
            Button {
                editingDuration = .step(id: step.wrappedValue.id,
                                        seconds: step.wrappedValue.seconds)
            } label: {
                Text(mmss(step.wrappedValue.seconds))
                    .font(.fromCSSFont(17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func bulkButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(color.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func addButton(label: String, icon: String, color: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load / Save

    /// 활성 프로그램의 단계를 불러온다. 단순 반복 모드면 펼쳐서 보여준다.
    private func load() {
        loopForever = controller.isInfiniteSets
        if controller.isCustomMode {
            steps = controller.customSteps.map {
                EditStep(title: $0.title, isRest: $0.isRest, seconds: Int($0.seconds))
            }
        } else {
            // 무한 반복은 세트 수가 없으므로 time/rest 한 쌍만 펼친다
            let setCount = controller.isInfiniteSets ? 1 : max(1, controller.totalSets)
            var expanded: [EditStep] = []
            for _ in 0..<setCount {
                expanded.append(EditStep(title: "", isRest: false, seconds: max(1, Int(controller.timeSec))))
                if Int(controller.restSec) > 0 {
                    expanded.append(EditStep(title: "", isRest: true, seconds: Int(controller.restSec)))
                }
            }
            steps = expanded
        }
        initialSteps = steps
        initialLoop = loopForever
    }

    /// 변경분이 있으면 Realm + 컨트롤러에 반영. 타이머는 멈춘 상태로 초기화된다.
    private func save() {
        let cleaned = steps.filter { $0.seconds > 0 }
        guard !cleaned.isEmpty else { return }

        // 내용 비교 (id 제외)
        let same = loopForever == initialLoop
            && cleaned.count == initialSteps.count && zip(cleaned, initialSteps).allSatisfy {
            $0.title == $1.title && $0.isRest == $1.isRest && $0.seconds == $1.seconds
        }
        guard !same else { return }

        let model = TimerModel(
            title: controller.timerTitle,
            infiniteSets: loopForever,
            steps: cleaned.map {
                TimerModel.Step(kind: $0.isRest ? .rest : .time,
                                seconds: $0.seconds,
                                title: $0.title.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? nil
                                    : $0.title.trimmingCharacters(in: .whitespaces))
            }
        )

        controller.stop()

        // 컨트롤러 반영
        // 상세 편집기는 색을 다루지 않으므로 컨트롤러의 현재 색을 그대로 유지한다
        let timeHex = controller.timeColorHex
        let restHex = controller.restColorHex
        if model.isCustom {
            controller.configureCustom(title: model.title, steps: model.steps.map {
                TimerController.CustomStep(title: $0.title ?? "",
                                           isRest: $0.kind == .rest,
                                           seconds: TimeInterval(max(1, $0.seconds)))
            }, loops: loopForever, timeColorHex: timeHex, restColorHex: restHex)
        } else if let trs = model.asTimeRestSets() {
            controller.configure(title: model.title, time: trs.time, rest: trs.rest,
                                 sets: loopForever ? TimerController.infiniteSets : trs.sets,
                                 timeColorHex: timeHex, restColorHex: restHex)
            controller.saveLastUsed()
        }

        // Realm(활성 프로그램) 반영
        guard let id = ActiveProgramStore.activeId(),
              let realm = try? Realm(),
              let p = realm.object(ofType: RTimerProgram.self, forPrimaryKey: id) else { return }
        try? realm.write {
            p.infiniteSets = loopForever
            p.steps.removeAll()
            for s in model.steps {
                let rs = RStep()
                rs.kindRaw = s.kind.rawValue
                rs.seconds = s.seconds
                rs.title = s.title ?? ""
                p.steps.append(rs)
            }
        }
    }
}
