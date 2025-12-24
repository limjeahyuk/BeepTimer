//
//  TiemrLibraryView.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/14/25.
//

import SwiftUI
import RealmSwift

struct TimerPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let time: Int
    let rest: Int
    let sets: Int
}

struct TimerLibraryView: View {
    @ObservedResults(RTimerProgram.self,
                     sortDescriptor: SortDescriptor(keyPath: "createdAt", ascending: false))
    var programs

    let onPick: (TimerModel) -> Void
    
    /// 현재 목록에서 "TimerN"의 최댓값을 찾아 "Timer\(N+1)" 반환
    private func nextDefaultTitle(from programs: Results<RTimerProgram>) -> String {
        let pattern = #"^\s*Timer\s*(\d+)\s*$"#
        let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        var maxN = 0
        for t in programs.map(\.title) {
            guard let re, let m = re.firstMatch(in: t, options: [], range: NSRange(location: 0, length: (t as NSString).length)),
                  m.numberOfRanges >= 2 else { continue }
            let numRange = m.range(at: 1)
            if numRange.location != NSNotFound {
                let n = Int((t as NSString).substring(with: numRange)) ?? 0
                maxN = max(maxN, n)
            }
        }
        return "Timer\(maxN + 1)"
    }

    var body: some View {
        ZStack {
            TimerColor.bg.ignoresSafeArea()
            
            VStack(spacing: 0){
                HStack {
                    Text("Timers")
                        .font(.fromCSSFont(24, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button{
                        // 기본 제목과 빈 스텝으로 새 항목 생성
                        let title = nextDefaultTitle(from: programs)
                        let obj = RTimerProgram()
                        obj.title = title
                        obj.createdAt = Date()
                        
                        let steps = List<RStep>()
                        let t = RStep(); t.kindRaw = "time"; t.seconds = 30   // 기본 Time
                        let r = RStep(); r.kindRaw = "rest"; r.seconds = 15   // 기본 Rest
                        steps.append(objectsIn: [t, r])
                        obj.steps = steps
                        
                        $programs.append(obj)  // ObservedResults가 write 트랜잭션 처리
                    } label: {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 22, height: 22)
                    }
                    .accessibilityLabel("새 타이머 추가")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                if programs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "timer.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.white.opacity(0.5))
                        
                        Text("타이머가 없습니다.")
                            .foregroundStyle(TimerColor.textPrimary)
                            .font(.fromCSSFont(18, weight: .semibold))
                        
                        Text("오른쪽 위 + 버튼으로 추가하세요.")
                            .foregroundStyle(TimerColor.textSecondary)
                            .font(.subheadline)
                    }
                    .padding(.top, 60)
                } else {
                    let activeId = ActiveProgramStore.activeId()
                    let sorted = Array(programs).sorted { a, b in
                        let aActive = ActiveProgramStore.isActive(a, activeId: activeId)
                        let bActive = ActiveProgramStore.isActive(b, activeId: activeId)
                        if aActive != bActive { return aActive && !bActive }           // 활성 먼저
                        return a.createdAt > b.createdAt                               // 최신순
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sorted, id: \._id) { p in
                                ProgramRowCard(program: p,
                                               onStart: {
                                                    hideKeyboard()
                                                    ActiveProgramStore.setActive(p)
                                                    onPick(p.toModel())
                                                },
                                               onDelete: {
                                                    ActiveProgramStore.clearIfMatches(p)
                                                    $programs.remove(p)
                                                },
                                               onDuplicate: {clone in
                                                    $programs.append(clone)
                                                },
                                               isActive: ActiveProgramStore.isActive(p, activeId: activeId)
                                )
                                .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
            
    }
}


