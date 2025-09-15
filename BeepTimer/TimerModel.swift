//
//  TimerModel.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/15/25.
//

import SwiftUI

struct TimerModel: Codable, Identifiable, Equatable {
    var id = UUID()
    let title: String
    let steps: [Step]
    
    struct Step: Codable, Equatable {
        enum Kind: String, Codable { case time, rest }
        let kind: Kind
        let seconds: Int
    }
}
