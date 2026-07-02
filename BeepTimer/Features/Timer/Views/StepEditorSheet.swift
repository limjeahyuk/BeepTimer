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
    @State private var editingDuration: EditingDuration?

    private struct EditingDuration: Identifiable {
        let id: UUID          // step id
        let seconds: Int
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
                    EditButton()
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
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 56)

                // 추가 버튼 + 총 시간
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        addButton(label: "운동 추가", icon: "timer", color: accent) {
                            steps.append(EditStep(title: "", isRest: false, seconds: 60))
                        }
                        addButton(label: "휴식 추가", icon: "pause.circle.fill", color: .orange) {
                            steps.append(EditStep(title: "", isRest: true, seconds: 15))
                        }
                    }

                    HStack {
                        Text("총 시간")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TimerColor.textSecondary)
                        Spacer()
                        Text(mmss(totalSec))
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
            TimePickerSheet(initialSeconds: editing.seconds, minSeconds: 1, maxSeconds: 59*60+59) { newValue in
                if let idx = steps.firstIndex(where: { $0.id == editing.id }) {
                    steps[idx].seconds = newValue
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
                editingDuration = EditingDuration(id: step.wrappedValue.id,
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
        if controller.isCustomMode {
            steps = controller.customSteps.map {
                EditStep(title: $0.title, isRest: $0.isRest, seconds: Int($0.seconds))
            }
        } else {
            var expanded: [EditStep] = []
            for _ in 0..<max(1, controller.totalSets) {
                expanded.append(EditStep(title: "", isRest: false, seconds: max(1, Int(controller.timeSec))))
                if Int(controller.restSec) > 0 {
                    expanded.append(EditStep(title: "", isRest: true, seconds: Int(controller.restSec)))
                }
            }
            steps = expanded
        }
        initialSteps = steps
    }

    /// 변경분이 있으면 Realm + 컨트롤러에 반영. 타이머는 멈춘 상태로 초기화된다.
    private func save() {
        let cleaned = steps.filter { $0.seconds > 0 }
        guard !cleaned.isEmpty else { return }

        // 내용 비교 (id 제외)
        let same = cleaned.count == initialSteps.count && zip(cleaned, initialSteps).allSatisfy {
            $0.title == $1.title && $0.isRest == $1.isRest && $0.seconds == $1.seconds
        }
        guard !same else { return }

        let model = TimerModel(
            title: controller.timerTitle,
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
        if model.isCustom {
            controller.configureCustom(title: model.title, steps: model.steps.map {
                TimerController.CustomStep(title: $0.title ?? "",
                                           isRest: $0.kind == .rest,
                                           seconds: TimeInterval(max(1, $0.seconds)))
            })
        } else if let trs = model.asTimeRestSets() {
            controller.configure(title: model.title, time: trs.time, rest: trs.rest, sets: trs.sets)
            controller.saveLastUsed()
        }

        // Realm(활성 프로그램) 반영
        guard let id = ActiveProgramStore.activeId(),
              let realm = try? Realm(),
              let p = realm.object(ofType: RTimerProgram.self, forPrimaryKey: id) else { return }
        try? realm.write {
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
