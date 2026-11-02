/// A grid of cells bound to actions. Row 0 is the top row.
public struct Layout: Equatable, Sendable {
    public struct Cell: Equatable, Sendable {
        public let action: KeyAction
        public let row: Int
        public let column: Int
        public let rowSpan: Int
        public let columnSpan: Int

        init(action: KeyAction, row: Int, column: Int, rowSpan: Int = 1, columnSpan: Int = 1) {
            self.action = action
            self.row = row
            self.column = column
            self.rowSpan = rowSpan
            self.columnSpan = columnSpan
        }
    }

    public static let numpad = Layout(
        rows: 4,
        columns: 3,
        cells: [
            Cell(action: .digit(7), row: 0, column: 0),
            Cell(action: .digit(8), row: 0, column: 1),
            Cell(action: .digit(9), row: 0, column: 2),
            Cell(action: .digit(4), row: 1, column: 0),
            Cell(action: .digit(5), row: 1, column: 1),
            Cell(action: .digit(6), row: 1, column: 2),
            Cell(action: .digit(1), row: 2, column: 0),
            Cell(action: .digit(2), row: 2, column: 1),
            Cell(action: .digit(3), row: 2, column: 2),
            Cell(action: .digit(0), row: 3, column: 0),
            Cell(action: .decimalSeparator, row: 3, column: 1),
            Cell(action: .backspace, row: 3, column: 2),
        ]
    )

    public let rows: Int
    public let columns: Int
    public let cells: [Cell]

    /// Hit-tests a point that the active area has already mapped. Points on the outer edges belong to the last slot.
    public func cell(at point: TrackpadPoint) -> Cell? {
        let row = min(rows - 1, Int((1 - point.y) * Double(rows)))
        let column = min(columns - 1, Int(point.x * Double(columns)))
        return cells.first { cell in
            (cell.row..<cell.row + cell.rowSpan).contains(row)
                && (cell.column..<cell.column + cell.columnSpan).contains(column)
        }
    }
}
