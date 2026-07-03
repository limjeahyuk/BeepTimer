//
//  ProgramRowCard.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/23/25.
//

import SwiftUI
import RealmSwift

struct ProgramRowCard: View {
    @ObservedRealmObject var program: RTimerProgram
    let onStart: () -> Void
    let onDelete: () -> Void
    let onDuplicate: (RTimerProgram) -> Void
    @State private var expanded = false
    @State private var editingField: EditingField?
    @State private var keypadField: EditingField?
    var isActive: Bool = false

    private enum EditingField: Identifiable {
        case time, rest, sets
        var id: Self { self }
    }

    private let accent = Color(hex: "#22D3EE")

    func mmss(_ sec: Int) -> String {
        let s = max(0, sec)
        let m = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", m, ss)
    }
    
    func nextCloneTitle(base: String) -> String {
        // "Timer5 copy" 같은 심플 규칙
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Timer Copy" : "\(trimmed) copy"
    }

    
    // 파생값 (type-checker 부담을 줄이기 위해 분리)
    private var allSteps: [RStep] { Array(program.steps) }
    private var setCount: Int { allSteps.filter { $0.kindRaw.lowercased() == "time" }.count }
    private var totalSec: Int { allSteps.reduce(0) { $0 + $1.seconds } }
    private var firstTimeSec: Int { allSteps.first { $0.kindRaw.lowercased() == "time" }?.seconds ?? 0 }
    private var firstRestSec: Int { allSteps.first { $0.kindRaw.lowercased() == "rest" }?.seconds ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            if expanded {
                expandedEditor
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.10 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isActive ? Color(hex: "#22D3EE").opacity(0.5) : Color.white.opacity(0.08),
                        lineWidth: isActive ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.20), radius: 10, x: 0, y: 6)
    }

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                expanded.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if isActive {
                            Circle()
                                .fill(accent)
                                .frame(width: 7, height: 7)
                        }

                        Text(program.title)
                            .font(.fromCSSFont(17, weight: .bold))
                            .foregroundStyle(TimerColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)

                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(TimerColor.textSecondary)
                    }

                    HStack(spacing: 6) {
                        statChip(icon: "repeat", text: program.infiniteSets ? "∞" : "\(setCount)")
                        statChip(icon: "clock", text: program.infiniteSets ? "∞" : mmss(totalSec))
                    }
                }
                // Spacer보다 먼저 폭을 차지해야 여백이 남아 있는데 제목이 잘리는 일이 없다
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    // 재생을 누르면 바로 시작되는 운동 시간
                    Text(mmss(firstTimeSec))
                        .font(.fromCSSFont(20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(TimerColor.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
                    Text("휴식 \(mmss(firstRestSec))")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(TimerColor.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                Button {
                    onStart()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(accent.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(TimerColor.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.07)))
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 이름
            VStack(alignment: .leading, spacing: 6) {
                Text("이름")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TimerColor.textSecondary)

                TextField("타이머 이름", text: $program.title)
                    .textFieldStyle(.plain)
                    .font(.fromCSSFont(16, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(TimerColor.textPrimary)
                    .disableAutocorrection(true)
            }

            // 시간 구성 (탭하여 수정)
            VStack(alignment: .leading, spacing: 6) {
                Text("시간 구성")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TimerColor.textSecondary)

                VStack(spacing: 0) {
                    editRow(icon: "timer", iconColor: accent,
                            label: "운동 시간",
                            value: mmss(representativeSeconds(kind: "time")),
                            mixed: !isUniform(kind: "time"),
                            onLongPress: { keypadField = .time }) {
                        editingField = .time
                    }
                    rowDivider
                    editRow(icon: "pause.circle.fill", iconColor: .orange,
                            label: "휴식 시간",
                            value: mmss(representativeSeconds(kind: "rest")),
                            mixed: !isUniform(kind: "rest"),
                            onLongPress: { keypadField = .rest }) {
                        editingField = .rest
                    }
                    rowDivider
                    editRow(icon: "repeat", iconColor: .green,
                            label: "세트",
                            value: program.infiniteSets ? "∞" : "\(currentSets())") {
                        editingField = .sets
                    }
                }
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // 액션
            HStack(spacing: 10) {
                Button {
                    // 간단 복제
                    let clone = RTimerProgram()
                    clone.title = nextCloneTitle(base: program.title)
                    clone.createdAt = Date()
                    let list = RealmSwift.List<RStep>()
                    for s in program.steps {
                        let c = RStep()
                        c.kindRaw = s.kindRaw
                        c.seconds = s.seconds
                        list.append(c)
                    }

                    clone.steps = list
                    clone.infiniteSets = program.infiniteSets

                    onDuplicate(clone)
                } label: {
                    Label("복제", systemImage: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(TimerColor.textPrimary)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 38, height: 38)
                        .background(Color.red.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onStart()
                } label: {
                    Label("시작", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(accent.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .sheet(item: $editingField) { field in
            switch field {
            case .time:
                TimePickerSheet(initialSeconds: representativeSeconds(kind: "time"),
                                minSeconds: 1, maxSeconds: 59*60+59) { newValue in
                    bindingForKind("time").wrappedValue = newValue
                }
                .presentationDetents([.medium])
            case .rest:
                TimePickerSheet(initialSeconds: representativeSeconds(kind: "rest"),
                                minSeconds: 0, maxSeconds: 59*60+59) { newValue in
                    bindingForKind("rest").wrappedValue = newValue
                }
                .presentationDetents([.medium])
            case .sets:
                SetsPickerSheet(title: "세트", initial: currentSets(),
                                minSets: 1, maxSets: 99) { newValue in
                    setsBinding.wrappedValue = newValue
                }
                .presentationDetents([.medium])
            }
        }
        // 시간/휴식 행을 길게 누르면 숫자 키패드로 직접 입력
        .sheet(item: $keypadField) { field in
            let kind = (field == .time) ? "time" : "rest"
            TimeKeypadSheet(initialSeconds: representativeSeconds(kind: kind),
                            minSeconds: field == .time ? 1 : 0,
                            maxSeconds: 59*60+59) { newValue in
                bindingForKind(kind).wrappedValue = newValue
            }
            .presentationDetents([.fraction(0.6)])
        }
    }

    private func editRow(icon: String, iconColor: Color, label: String, value: String,
                         mixed: Bool = false, onLongPress: (() -> Void)? = nil,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(iconColor.opacity(0.15)))

                Text(label)
                    .font(.fromCSSFont(15, weight: .medium))
                    .foregroundStyle(TimerColor.textPrimary)

                if mixed {
                    Text("혼합")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                }

                Spacer()

                Text(value)
                    .font(.fromCSSFont(17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(iconColor)
                    .lineLimit(1)
                    .fixedSize()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TimerColor.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            onLongPress?()
        })
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 50)
    }
}

struct TimePickerSheet: View {
    let initialSeconds: Int
    let minSeconds: Int
    let maxSeconds: Int
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("시간 설정")
                    .font(.title3).bold()
                Spacer()
                Button("완료") {
                    let total = clamp(minutes * 60 + seconds, minSeconds, maxSeconds)
                    print("done")
                    onDone(total)
                    dismiss()
                }
                .font(.headline)
            }

            HStack {
                Picker("분", selection: $minutes) {
                    ForEach(0...59, id: \.self) { Text("\($0) 분") }
                }
                .pickerStyle(.wheel)
                Picker("초", selection: $seconds) {
                    ForEach(0...59, id: \.self) { Text("\($0) 초") }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 180)

            Text(String(format: "%02d:%02d", minutes, seconds))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.top, 4)

            Spacer(minLength: 8)
        }
        .padding(16)
        .onAppear {
            let m = initialSeconds / 60
            let s = initialSeconds % 60
            minutes = clamp(m, 0, 59)
            seconds = clamp(s, 0, 59)
        }
        .sensoryFeedback(.selection, trigger: minutes)
        .sensoryFeedback(.selection, trigger: seconds)
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int {
        max(lo, min(hi, v))
    }
}


struct TimeKeypadSheet: View {
    let initialSeconds: Int
    let minSeconds: Int
    let maxSeconds: Int
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var digits: String = "" // "mmss" (0~4자, 앞쪽 0 생략 가능)

    var body: some View {
        VStack(spacing: 16) {
            // 상단 여백을 조금 주고, 드래그 인디케이터도 노출
            HStack {
                Text("시간 직접 입력")
                    .font(.title3).bold()
                Spacer()
                Button("완료") {
                    let total = clamp(parsedSeconds(), minSeconds, maxSeconds)
                    onDone(total); dismiss()
                }
                .font(.headline)
            }
            .padding(.top, 20)  //  상단 여백

            Text(display())
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.vertical, 8)

            VStack(spacing: 10) {
                ForEach([["1","2","3"],["4","5","6"],["7","8","9"]], id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { key in
                            KeyButton(title: key) { appendDigit(key) }
                        }
                    }
                }
                HStack(spacing: 10) {
                    KeyButton(title: "지우기") { if !digits.isEmpty { digits.removeLast() } }
                    KeyButton(title: "0") { appendDigit("0") }
                    KeyButton(title: "초기화") { digits.removeAll() }
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 8)
        }
        .padding(16)
        .onAppear {
            digits.removeAll()
        }
    }

    // 왼쪽 패딩 방식으로 4자리 보정 ("2" -> "0002")
    private func leftPad4(_ s: String) -> String {
        String(("0000" + s).suffix(4))
    }

    private func display() -> String {
        let padded = leftPad4(digits)
        let m = Int(padded.prefix(2)) ?? 0
        let s = Int(padded.suffix(2)) ?? 0
        return String(format: "%02d:%02d", m, s)
    }

    private func parsedSeconds() -> Int {
        let padded = leftPad4(digits)
        let m = Int(padded.prefix(2)) ?? 0
        let s = Int(padded.suffix(2)) ?? 0
        return m * 60 + s
    }

    private func appendDigit(_ d: String) {
        guard digits.count < 4 else { return }
        digits.append(d)
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(hi, v)) }
}

private struct KeyButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

extension ProgramRowCard {
    /// 특정 kind("time"/"rest")의 초값이 모두 같은지
    private func isUniform(kind: String) -> Bool {
        let vals = program.steps.filter { $0.kindRaw.lowercased() == kind }.map(\.seconds)
        guard let first = vals.first else { return true }
        return vals.allSatisfy { $0 == first }
    }

    /// 특정 kind의 대표 초값(전부 동일하면 그 값, 아니면 첫 값)
    private func representativeSeconds(kind: String) -> Int {
        program.steps
            .filter { $0.kindRaw.lowercased() == kind }
            .first?.seconds ?? 0
    }

    /// 특정 kind의 초값을 읽고-쓰기 위한 바인딩
    private func bindingForKind(_ kind: String) -> Binding<Int> {
        Binding<Int>(
            get: { representativeSeconds(kind: kind) },
            set: { newSec in
                guard let thawed = program.thaw(),
                      let realm = thawed.realm else { return }
                try? realm.write {
                    for step in thawed.steps where step.kindRaw.lowercased() == kind {
                        step.seconds = newSec
                    }
                }
            }
        )
    }

    /// 현재 세트 수(time/rest 쌍의 개수). 리스트 구성 규칙: time → rest 순으로 반복했다고 가정
    private func currentSets() -> Int {
        let t = program.steps.filter { $0.kindRaw.lowercased() == "time" }.count
        let r = program.steps.filter { $0.kindRaw.lowercased() == "rest" }.count
        return max(1, min(t, r))
    }

    private func makeStep(kind: String, seconds: Int) -> RStep {
        let s = RStep()
        s.kindRaw = kind
        s.seconds = seconds
        return s
    }

    private func setSets(_ newCount: Int) {
        let old = currentSets()
        guard newCount != old,
              let thawed = program.thaw(),
              let realm = thawed.realm else { return }

        let timeSec = representativeSeconds(kind: "time")
        let restSec = representativeSeconds(kind: "rest")

        try? realm.write {
            thawed.infiniteSets = false   // 세트 수를 직접 정하면 무한 반복 해제
            if newCount > old {
                for _ in old..<newCount {
                    thawed.steps.append(makeStep(kind: "time", seconds: timeSec))
                    thawed.steps.append(makeStep(kind: "rest", seconds: restSec))
                }
            } else {
                var toRemove = (old - newCount) * 2
                while toRemove > 0, thawed.steps.isEmpty == false {
                    thawed.steps.removeLast()
                    toRemove -= 1
                }
            }
        }
    }

    /// 세트 수 바인딩(증감 시 위 로직 호출)
    private var setsBinding: Binding<Int> {
        Binding(
            get: { currentSets() },
            set: { setSets($0) }
        )
    }
}

struct SetsPickerSheet: View {
    let title: String
    let initial: Int
    let minSets: Int
    let maxSets: Int
    var allowInfinite: Bool = false   // 맨 아래 "∞ 무한 반복" 옵션 노출
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Int = 1

    private var isInfinite: Bool { value == TimerController.infiniteSets }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(title) 선택")
                    .font(.title3).bold()
                Spacer()
                Button("완료") {
                    onDone(value)
                    dismiss()
                }
                .font(.headline)
            }

            Picker("Sets", selection: $value) {
                ForEach(minSets...maxSets, id: \.self) { v in
                    Text("\(v) 세트").tag(v)
                }
                if allowInfinite {
                    Text("∞ 무한 반복").tag(TimerController.infiniteSets)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)

            Text(isInfinite ? "∞ Sets" : "\(value) Sets")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.top, 4)

            if isInfinite {
                Text("세트가 끝나지 않고 계속 반복해요. 전체 자동(Auto) 모드는 사용할 수 없어 세트가 끝날 때마다 멈춥니다.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .onAppear {
            value = (allowInfinite && initial == TimerController.infiniteSets)
                ? initial
                : clamp(initial, minSets, maxSets)
        }
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(hi, v)) }
}
