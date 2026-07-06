//
//  SudokuModel.swift
//  BeepTimer
//
//  커스텀 영역 스도쿠 — 퍼즐 생성 / 진행 상태 / 저장
//  격자는 81칸 1차원 배열([Int])로 다루고 0은 빈 칸을 뜻한다.
//

import Foundation
import SwiftUI

// MARK: - 난이도

enum SudokuDifficulty: String, CaseIterable, Codable {
    case easy, medium, hard

    var label: String {
        switch self {
        case .easy:   return "쉬움"
        case .medium: return "보통"
        case .hard:   return "어려움"
        }
    }

    /// 시작 시 채워 두는 힌트(clue) 칸 수 — 적을수록 어렵다
    var clues: Int {
        switch self {
        case .easy:   return 42
        case .medium: return 34
        case .hard:   return 28
        }
    }
}

// MARK: - 진행 상태 (저장 단위)

struct SudokuState: Codable, Equatable {
    var given: [Int]        // 처음 주어진 힌트 (0 = 사용자가 채울 칸)
    var solution: [Int]     // 완성된 정답
    var current: [Int]      // 현재 판(힌트 포함, 0 = 빈 칸)
    var difficulty: SudokuDifficulty

    /// 아직 생성 전의 빈 판 (생성이 끝나기 전 잠깐 보여 준다)
    static let empty = SudokuState(given: Array(repeating: 0, count: 81),
                                   solution: Array(repeating: 0, count: 81),
                                   current: Array(repeating: 0, count: 81),
                                   difficulty: .easy)

    static func newGame(_ difficulty: SudokuDifficulty) -> SudokuState {
        let solution = SudokuGenerator.fullSolution()
        let puzzle = SudokuGenerator.removeCells(from: solution, clues: difficulty.clues)
        return SudokuState(given: puzzle, solution: solution, current: puzzle, difficulty: difficulty)
    }

    var isSolved: Bool { current == solution && !current.contains(0) }

    /// index 칸이 같은 줄/칸/3×3 박스에서 숫자가 겹치는지 (틀림 표시용)
    func isConflict(at index: Int) -> Bool {
        let v = current[index]
        guard v != 0 else { return false }
        let row = index / 9, col = index % 9
        for c in 0..<9 where c != col && current[row * 9 + c] == v { return true }
        for r in 0..<9 where r != row && current[r * 9 + col] == v { return true }
        let br = (row / 3) * 3, bc = (col / 3) * 3
        for r in 0..<3 {
            for c in 0..<3 {
                let i = (br + r) * 9 + (bc + c)
                if i != index && current[i] == v { return true }
            }
        }
        return false
    }
}

// MARK: - 퍼즐 생성기 (유일해 보장)

enum SudokuGenerator {
    /// 백트래킹으로 완성된 정답판을 무작위로 하나 만든다
    static func fullSolution() -> [Int] {
        var grid = [Int](repeating: 0, count: 81)
        _ = fill(&grid, 0)
        return grid
    }

    private static func fill(_ grid: inout [Int], _ index: Int) -> Bool {
        if index == 81 { return true }
        if grid[index] != 0 { return fill(&grid, index + 1) }
        for n in Array(1...9).shuffled() where isValid(grid, index, n) {
            grid[index] = n
            if fill(&grid, index + 1) { return true }
            grid[index] = 0
        }
        return false
    }

    /// 정답판에서 칸을 지워 퍼즐을 만든다 — 지워도 정답이 하나뿐일 때만 지운다
    static func removeCells(from solution: [Int], clues: Int) -> [Int] {
        var puzzle = solution
        var count = 81
        for idx in Array(0..<81).shuffled() {
            if count <= clues { break }
            let backup = puzzle[idx]
            puzzle[idx] = 0
            if countSolutions(puzzle, limit: 2) == 1 {
                count -= 1
            } else {
                puzzle[idx] = backup   // 지우면 정답이 여러 개 → 되돌린다
            }
        }
        return puzzle
    }

    static func isValid(_ grid: [Int], _ index: Int, _ n: Int) -> Bool {
        let row = index / 9, col = index % 9
        for c in 0..<9 where grid[row * 9 + c] == n { return false }
        for r in 0..<9 where grid[r * 9 + col] == n { return false }
        let br = (row / 3) * 3, bc = (col / 3) * 3
        for r in 0..<3 {
            for c in 0..<3 where grid[(br + r) * 9 + (bc + c)] == n { return false }
        }
        return true
    }

    /// 정답 개수를 limit까지만 센다 (유일해 판정은 limit 2면 충분)
    static func countSolutions(_ grid: [Int], limit: Int) -> Int {
        var g = grid
        var count = 0

        func solve(_ start: Int) -> Bool {   // true = limit 도달, 중단
            var index = start
            while index < 81 && g[index] != 0 { index += 1 }
            if index == 81 {
                count += 1
                return count >= limit
            }
            for n in 1...9 where isValid(g, index, n) {
                g[index] = n
                if solve(index + 1) { g[index] = 0; return true }
                g[index] = 0
            }
            return false
        }

        _ = solve(0)
        return count
    }
}

// MARK: - 저장 (Realm의 RCustomArea.sudokuState에 JSON으로)

enum SudokuStore {
    static func load(key: String) -> SudokuState? {
        let json = PhotoSlideStore.loadSudoku(key: key)
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(SudokuState.self, from: data)
        else { return nil }
        return state
    }

    static func save(key: String, state: SudokuState) {
        guard let data = try? JSONEncoder().encode(state),
              let json = String(data: data, encoding: .utf8)
        else { return }
        PhotoSlideStore.saveSudoku(key: key, json: json)
    }
}

// MARK: - 게임 진행 (뷰가 관찰)

@MainActor
final class SudokuGame: ObservableObject {
    let memoKey: String
    @Published var state: SudokuState
    @Published var selected: Int? = nil
    @Published var isGenerating = false

    init(memoKey: String) {
        self.memoKey = memoKey
        if let saved = SudokuStore.load(key: memoKey) {
            state = saved
        } else {
            state = .empty
            newGame(.easy)   // 처음 열면 쉬움 난이도로 시작
        }
    }

    /// 힌트가 아닌 칸을 고른다 (같은 칸 다시 누르면 선택 해제)
    func select(_ index: Int) {
        selected = (selected == index) ? nil : index
    }

    func enter(_ n: Int) {
        guard let i = selected, state.given[i] == 0 else { return }
        state.current[i] = (state.current[i] == n) ? 0 : n   // 같은 숫자 다시 누르면 지움
        persist()
    }

    func erase() {
        guard let i = selected, state.given[i] == 0 else { return }
        state.current[i] = 0
        persist()
    }

    func newGame(_ difficulty: SudokuDifficulty) {
        isGenerating = true
        selected = nil
        let key = memoKey
        Task {
            // 유일해 검증이 무거우므로 배경에서 생성하고 결과만 메인으로 가져온다
            let fresh = await Task.detached(priority: .userInitiated) {
                SudokuState.newGame(difficulty)
            }.value
            self.state = fresh
            self.selected = nil
            self.isGenerating = false
            SudokuStore.save(key: key, state: fresh)
        }
    }

    private func persist() {
        SudokuStore.save(key: memoKey, state: state)
    }
}
