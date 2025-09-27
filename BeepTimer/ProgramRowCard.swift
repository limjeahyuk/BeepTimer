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
        let timeCount = steps.filter { $0.kindRaw.lowercased() == "time" }.count
        let restCount = steps.filter { $0.kindRaw.lowercased() == "rest" }.count
        let totalSec = steps.reduce(0) { $0 + $1.seconds }
        
        VStack(spacing: 0) {
            Button{
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    expanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    Circle().fill(TimerColor.ringTime)
                        .frame(width: 10, height: 10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.title)
                            .font(.fromCSSFont(17, weight: .semibold))
                            .foregroundStyle(TimerColor.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 10) {
                            Text("Total \(mmss(totalSec))")
                            Text("Time \(timeCount) - Rest \(restCount)")
                        }
                        .font(.fromCSSFont(13, weight: .medium))
                        .fontDesign(.rounded)
                        .foregroundStyle(TimerColor.textSecondary)
                        .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.fromCSSFont(14, weight: .bold))
                        .foregroundStyle(TimerColor.textSecondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            
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
                    
                    HStack(spacing: 8) {
                        SummaryChip(text: "Total \(mmss(totalSec))") {
                            logger.d("123")
                        }
                        SummaryChip(text: "Time \(timeCount)")
                        SummaryChip(text: "Rest \(restCount)")
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            onStart()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .font(.fromCSSFont(15, weight: .semibold))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(TimerColor.ringTime.opacity(0.22), in: Capsule())
                        }
                        
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
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.fromCSSFont(16, weight: .bold))
                                .padding(10)
                                .background(Color.red.opacity(0.18), in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
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

struct SummaryChip: View {
    let text: String
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TimerColor.textSecondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}
