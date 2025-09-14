//
//  TiemrLibraryView.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/14/25.
//

import SwiftUI

struct TimerPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let time: Int
    let rest: Int
    let sets: Int
}

struct TimerLibraryView: View {
    let presets: [TimerPreset]
    let select: (TimerPreset) -> Void

    var body: some View {
        List(presets) { p in
            Button {
                select(p)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.name).font(.headline)
                        Text("\(p.time)s • Rest \(p.rest)s • \(p.sets) sets")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.title3)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Timers")
    }
}


