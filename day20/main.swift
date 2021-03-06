import Foundation

let input = loadData(day: 20)
let scanner = Scanner(string: input)


struct Tile {
    var id: Int
    var imageData: [Bool]
    var size: Int

    subscript (_ x: Int, _ y: Int) -> Bool {
        get { imageData[x + y * size] }
        set { imageData[x + y * size] = newValue }
    }
}


extension Scanner {
    func tile() -> Tile? {
        guard string("Tile"),
              let id = scanInt(),
              string(":"),
              let (image, size) = imageData()
        else { return nil }
        return Tile(id: id, imageData: image, size: size)
    }

    func imageData() -> ([Bool], Int)? {
        var result: [Bool] = []
        let set = CharacterSet(charactersIn: "#.")
        var width: Int? = nil
        while let line = scanCharacters(from: set) {
            assert(width == nil || line.count == width)
            width = line.count
            result.append(contentsOf: line.map { $0 == "#" })
        }

        guard let w = width else { return nil }

        return (result, w)
    }

    func tileSet() -> [Int: Tile]? {
        var result: [Int: Tile] = [:]
        while !isAtEnd {
            guard let tile = self.tile() else { return nil }
            result[tile.id] = tile
        }
        return result
    }
}

let tilesById = scanner.tileSet()!

struct TileReference: Hashable {
    enum Rotation: CaseIterable {
        case rotate0, rotate90, rotate180, rotate270
    }

    var id: Int
    var flipped: Bool
    var rotation: Rotation

    subscript (x: Int, y: Int) -> Bool {
        get {
            let tile = tilesById[id]!

            var coord = flipped ? (x: tile.size - 1 - x, y: y) : (x: x, y: y)
            coord = rotation.get(x: coord.x, y: coord.y, size: tile.size)

            return tile[coord.x, coord.y]
        }
    }

    var end: Int { tilesById[id]!.size - 1 }
}

extension TileReference.Rotation {
    func get(x: Int, y: Int, size: Int) -> (x: Int, y: Int) {
        let e = size - 1
        switch self {
        case .rotate0: return (x, y)
        case .rotate90: return (y, e - x)
        case .rotate180: return (x, e - y)
        case .rotate270: return (e - y, x)
        }
    }
}

struct Board {
    struct Cell {
        var possible: Array<TileReference>
    }

    var size: Int
    var cells: [Cell]

    init<T>(tiles: T) where T: Sequence, T.Element == Int {
        let orientations = [true, false].flatMap { flipped in TileReference.Rotation.allCases.map { (flipped, $0) } }
        let allOptions = tiles.flatMap { id in orientations.map { TileReference(id: id, flipped: $0.0, rotation: $0.1 ) } }
        size = Int(sqrt(Double(tilesById.count)))
        cells = Array(repeating: Cell(possible: allOptions), count: size*size)
        assert(size * size == tilesById.count)
    }

    subscript(x: Int, y: Int) -> Cell {
        get { cells[x + y * size] }
        set { cells[x + y * size] = newValue }
    }

    func coordinate(_ cell: Int) -> (x: Int, y: Int) {
        let (y, x) = cell.quotientAndRemainder(dividingBy: size)
        return (x, y)
    }

    func solve(startingAt: Int = 0) -> Board? {
        if startingAt >= cells.count { return self }

        let coord = coordinate(startingAt)
        let left = coord.x > 0 ? self[coord.x - 1, coord.y].chosen! : nil
        let above = coord.y > 0 ? self[coord.x, coord.y - 1].chosen! : nil

        func matchLeft(_ ref: TileReference) -> Bool {
            guard let left = left else { return true }
            return (0...ref.end).allSatisfy { left[left.end, $0] == ref[0, $0] }
        }

        func matchAbove(_ ref: TileReference) -> Bool {
            guard let above = above else { return true }
            return (0...ref.end).allSatisfy { above[$0, above.end] == ref[$0, 0] }
        }

        for option in cells[startingAt].possible.lazy.filter({ matchLeft($0) && matchAbove($0) }) {
            var result = self
            result.cells[startingAt].possible = [option]

            let next = startingAt + 1

            for cell in next..<cells.count {
                result.cells[cell].possible = result.cells[cell].possible.filter {
                    return $0.id != option.id
                }

                if result.cells[cell].possible.isEmpty {
                    return nil
                }
            }

            if let solution = result.solve(startingAt: next) {
                return solution
            }
        }

        return nil
    }
}


extension Board.Cell {
    var chosen: TileReference? {
        guard let result = possible.first, possible.count == 1 else {
            return nil
        }

        return result
    }
}
let start = Date()
guard let solution = Board(tiles: tilesById.keys).solve() else { fatalError() }
let end = Date()

print("Took", end.timeIntervalSince(start))

let e = solution.size - 1

print(solution[0,0].chosen!.id)

print(
    solution[0,0].chosen!.id *
    solution[e,0].chosen!.id *
    solution[0,e].chosen!.id *
    solution[e,e].chosen!.id
)

extension Board {
    struct CompleteImage {
        let board: Board
        var flipped = false
        var rotation = TileReference.Rotation.rotate0
    }

    var completeImage: CompleteImage {
        CompleteImage(board: self)
    }

    func completeImage(flipped: Bool, rotation: TileReference.Rotation) -> CompleteImage {
        CompleteImage(board: self, flipped: flipped, rotation: rotation)
    }
}


extension Board.CompleteImage {
    var size: Int {
        board.size * (board.cells[0].chosen!.end - 1)
    }

    subscript(x: Int, y: Int) -> Bool {
        get {
            var coord = flipped ? (x: size - 1 - x, y: y) : (x: x, y: y)
            coord = rotation.get(x: coord.x, y: coord.y, size: size)

            let tileSize = board.cells[0].chosen!.end - 1
            let (tileX, offsetX) = coord.x.quotientAndRemainder(dividingBy: tileSize)
            let (tileY, offsetY) = coord.y.quotientAndRemainder(dividingBy: tileSize)
            let tile = board[tileX, tileY].chosen!
            return tile[offsetX + 1, offsetY + 1]
        }
    }
}

for y in 0..<solution.completeImage.size {
    for x in 0..<solution.completeImage.size {
        print(solution.completeImage[x, y] ? "#" : ".", terminator: "")
    }
    print()
}


extension Board.CompleteImage {
    func seaMonster(x: Int, y: Int) -> Bool {
        return self[x + 18, y] &&
            self[x + 0, y + 1] && self[x + 5, y + 1] && self[x + 6, y + 1] && self[x + 11, y + 1] && self[x + 12, y + 1] && self[x + 17, y + 1] && self[x + 18, y + 1] && self[x + 19, y + 1]  &&
            self[x + 1, y + 2] && self[x + 4, y + 2] && self[x + 7, y + 2] && self[x + 10, y + 2] && self[x + 13, y + 2] && self[x + 16, y + 2]
    }

    func countMonsters() -> Int {
        var count = 0
        for y in 0..<size - 2 {
            for x in 0..<size - 19 {
                if seaMonster(x: x, y: y) {
                    count += 1
                }
            }
        }
        return count
    }

    func countOnes() -> Int {
        var count = 0
        for y in 0..<size {
            for x in 0..<size {
                count += self[x, y] ? 1 : 0
            }
        }
        return count
    }
}

let ones = solution.completeImage.countOnes()
outer: for flipped in [true, false] {
    for rotation in TileReference.Rotation.allCases {
        let monsters = solution.completeImage(flipped: flipped, rotation: rotation).countMonsters()
        if monsters > 0 {
            let monsterTiles = monsters * 15
            let result = ones - monsterTiles
            print(result)
            break outer
        }
    }
}

