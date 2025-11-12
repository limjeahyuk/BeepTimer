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
    var isActive: Bool = false
    
    func mmss(_ sec: Int) -> String {
        let s = max(0, sec)
        let m = s / 60
        let ss = s % 60
        return String(format: "%02d : %02d", m, ss)
    }
    
    func nextCloneTitle(base: String) -> String {
        // "Timer5 copy" 같은 심플 규칙
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Timer Copy" : "\(trimmed) copy"
    }

    
    var body: some View {
        let steps = Array(program.steps)
        let timeCount = steps.filter { $0.kindRaw.lowercased() == "time" }
        let restCount = steps.filter { $0.kindRaw.lowercased() == "rest" }
        let setCount = steps.filter { $0.kindRaw.lowercased() == "time" }.count
        let totalSec = steps.reduce(0) { $0 + $1.seconds }
        
        VStack(spacing: 0) {
            VStack {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 14) {
                        Circle().fill(isActive ? Color.red : Color(hex: "#22D3EE"))
                            .frame(width: 10, height: 10)
                        
                        Text(program.title)
                            .font(.fromCSSFont(17, weight: .semibold))
                            .foregroundStyle(TimerColor.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.fromCSSFont(14, weight: .bold))
                            .foregroundStyle(TimerColor.textSecondary)
                    }
                    .padding(.bottom, 5)
                }
                .buttonStyle(.plain)
                
                
                if !expanded {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack{
                                Text("Total \(mmss(totalSec)) - Sets \(setCount)")
                                Spacer()
                            }
                            HStack{
                                Text("Time \(mmss(timeCount.first?.seconds ?? 0)) - Rest \(mmss(restCount.first?.seconds ?? 0))")
                                Spacer()
                            }
                        }
                        .font(.fromCSSFont(13, weight: .medium))
                        .fontDesign(.rounded)
                        .foregroundStyle(TimerColor.textSecondary)
                        .lineLimit(2)
                        
                        Spacer()
                        
                        Button {
                            onStart()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.fromCSSFont(14, weight: .bold))
                                .foregroundStyle(Color.blue)                   // 아이콘 파랑
                                .padding(10)
                                .background(Circle().fill(Color.blue.opacity(0.18))) // 연파랑 배경
                        }
                        .buttonStyle(.plain)
                    }
                }
                    
            }
            
            
            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.caption)
                            .foregroundStyle(TimerColor.textSecondary)
                        
                        TextField("Title", text: $program.title)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(TimerColor.textPrimary)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 6){
                        
                        Text("Setting")
                            .font(.caption)
                            .foregroundStyle(TimerColor.textSecondary)
                        
                        HStack(spacing: 8) {
                            // Time
                            TimeFieldButton(
                                title: "Time \(isUniform(kind: "time") ? "" : " • mixed")",
                                seconds: bindingForKind("time"),
                                minSeconds: 1,
                                maxSeconds: 59*60+59
                            )
                            
                            // Rest
                            TimeFieldButton(
                                title: "Rest \(isUniform(kind: "rest") ? "" : " • mixed")",
                                seconds: bindingForKind("rest"),
                                minSeconds: 0,
                                maxSeconds: 59*60+59
                            )
                            
                            Spacer()
                            
                        }
                        HStack(spacing: 8) {
                            // Sets
                            SetsFieldButton(title: "Sets", sets: setsBinding, minSets: 1, maxSets: 99)
                            
                            Spacer()
                        }
                    }
                    
                    HStack(spacing: 12) {
                        
                        
                        Button {
                            // 간단 복제
                            let clone = RTimerProgram()
                            clone.title = nextCloneTitle(base: program.title)
                            clone.createdAt = Date()
                            let list = List<RStep>()
                            for s in program.steps {
                                let c = RStep()
                                c.kindRaw = s.kindRaw
                                c.seconds = s.seconds
                                list.append(c)
                            }
                            
                            clone.steps = list
                            
                            onDuplicate(clone)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.fromCSSFont(16, weight: .bold))
                                .padding(10)
                                .background(Color.red.opacity(0.18), in: Circle())
                        }
                        
                        Spacer()
                        
                        
                        Button {
                            onStart()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .font(.fromCSSFont(15, weight: .semibold))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(TimerColor.ringTime.opacity(0.22), in: Capsule())
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.20), radius: 10, x: 0, y: 6)
    }
}

struct TimeFieldButton: View {
    let title: String              // "Time", "Rest"
    @Binding var seconds: Int      // 총 초
    var minSeconds: Int = 0
    var maxSeconds: Int = 59*60+59 // 59:59 까지 예시 (필요 시 늘리세요)

    @State private var showSheet = false
    @State private var showKeypad = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.fromCSSFont(14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(mmss(seconds))
                    .font(.fromCSSFont(18, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        // 길게 누르면 숫자 키패드
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            showKeypad = true
        })
        .sheet(isPresented: $showSheet) {
            TimePickerSheet(
                initialSeconds: seconds,
                minSeconds: minSeconds,
                maxSeconds: maxSeconds
            ) { newValue in
                seconds = newValue
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showKeypad) {
            TimeKeypadSheet(
                initialSeconds: seconds,
                minSeconds: minSeconds,
                maxSeconds: maxSeconds
            ) { newValue in
                seconds = newValue
            }
            .presentationDetents([.fraction(0.6)])
        }
        .accessibilityLabel("\(title) \(mmss(seconds)) 설정")
    }

    private func mmss(_ s: Int) -> String {
        let m = s / 60, sec = s % 60
        return String(format: "%02d:%02d", m, sec)
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

struct SetsFieldButton: View {
    let title: String
    @Binding var sets: Int
    var minSets: Int = 1
    var maxSets: Int = 99

    @State private var showSheet = false
    @State private var startSets: Int = 0
    @GestureState private var dragOffset: CGFloat = .zero

    // 드래그 민감도: 가로 18pt당 1증감(원하는 감도로 조정)
    private let ptPerStep: CGFloat = 18

    var body: some View {
        let drag = DragGesture(minimumDistance: 0)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onChanged { value in
                // 드래그 양에 따라 증감
                let delta = Int(value.translation.width / ptPerStep)
                let newVal = clamp(startSets + delta, minSets, maxSets)
                if newVal != sets {
                    sets = newVal
                }
            }
            .onEnded { _ in
                startSets = sets
            }

        Button {
            startSets = sets
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                Text("\(title) \(sets)")
                    .font(.fromCSSFont(14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onAppear { startSets = sets }
        .sensoryFeedback(.selection, trigger: sets) // 촉각 피드백
        .sheet(isPresented: $showSheet) {
            SetsPickerSheet(
                title: title,
                initial: sets,
                minSets: minSets,
                maxSets: maxSets
            ) { newVal in
                sets = newVal
            }
            .presentationDetents([.medium])
        }
        .accessibilityLabel("\(title) \(sets) 설정")
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(hi, v)) }
}


struct SetsPickerSheet: View {
    let title: String
    let initial: Int
    let minSets: Int
    let maxSets: Int
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Int = 1

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
            }
            .pickerStyle(.wheel)
            .frame(height: 180)

            Text("\(value) Sets")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.top, 4)

            Spacer(minLength: 8)
        }
        .padding(16)
        .onAppear { value = clamp(initial, minSets, maxSets) }
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(hi, v)) }
}
