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
    
    let presets: [TimerPreset]
    let select: (TimerPreset) -> Void
    
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
        VStack{
            HStack {
                Text("Timers")
                    .font(.fromCSSFont(24, weight: .bold))
                
                Spacer()
                
                Button{
                    logger.d("plus Btn Action")
                    
                    // 기본 제목과 빈 스텝으로 새 항목 생성
                   let title = nextDefaultTitle(from: programs)
                   let obj = RTimerProgram()
                   obj.title = title
                   obj.createdAt = Date()
                   obj.steps = .init() // 비어있는 상태로 생성(나중에 편집)
                   $programs.append(obj)  // ObservedResults가 write 트랜잭션 처리
                }label: {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 22, height: 18)
                }
            }
            .padding(20)
            List {
                ForEach(programs) { p in
                    Button {
                        onPick(p.toModel())
                    } label: {
                        HStack {
                            Text(p.title).font(.headline)
                            Spacer()
                            Text("\(p.steps.filter { $0.kindRaw == "time" }.count) setsㅇ")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: $programs.remove)
            }
        }
    }
}


