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

    var body: some View {
        List {
            ForEach(programs) { p in
                Button {
                    onPick(p.toModel())
                } label: {
                    HStack {
                        Text(p.title).font(.headline)
                        Spacer()
                        Text("\(p.steps.filter { $0.kindRaw == "time" }.count) sets")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: $programs.remove)
        }
        .navigationTitle("Timers")
    }
}


