import Foundation

/// Winzige lineare Algebra für die Kurvenanpassung.
///
/// Bewusst ohne Fremdbibliothek: gebraucht werden nur kleine dichte Systeme
/// (3×3 für Kreis-/Ebenenfit, 7×7 für den gelernten Glättungskern). Ein
/// Gauß-Verfahren mit Spaltenpivotisierung reicht dafür vollkommen aus und ist
/// leicht nachvollziehbar.
enum LinearAlgebra {
    /// Löst `matrix * x = rhs`. `nil`, wenn das System singulär ist.
    static func solve(_ matrix: [[Double]], _ rhs: [Double]) -> [Double]? {
        let n = rhs.count
        guard n > 0, matrix.count == n else { return nil }

        var a = matrix
        var b = rhs

        for column in 0..<n {
            guard a[column].count == n else { return nil }

            var pivot = column
            var best = abs(a[column][column])
            if column + 1 < n {
                for row in (column + 1)..<n where abs(a[row][column]) > best {
                    pivot = row
                    best = abs(a[row][column])
                }
            }
            guard best > 1e-12 else { return nil }

            if pivot != column {
                a.swapAt(pivot, column)
                b.swapAt(pivot, column)
            }

            let diagonal = a[column][column]
            if column + 1 < n {
                for row in (column + 1)..<n {
                    let factor = a[row][column] / diagonal
                    if factor == 0 { continue }
                    for k in column..<n {
                        a[row][k] -= factor * a[column][k]
                    }
                    b[row] -= factor * b[column]
                }
            }
        }

        var solution = [Double](repeating: 0, count: n)
        for column in stride(from: n - 1, through: 0, by: -1) {
            var accumulator = b[column]
            if column + 1 < n {
                for k in (column + 1)..<n {
                    accumulator -= a[column][k] * solution[k]
                }
            }
            let diagonal = a[column][column]
            guard abs(diagonal) > 1e-12 else { return nil }
            solution[column] = accumulator / diagonal
        }

        for value in solution where !value.isFinite { return nil }
        return solution
    }

    /// Kleinste Quadrate mit Ridge-Term: löst `(AᵀA + ridge·I) x = Aᵀb`.
    ///
    /// `rows` ist die Designmatrix, `targets` der Zielvektor. Der Ridge-Term
    /// hält das System auch bei fast kollinearen Merkmalen stabil.
    static func leastSquares(rows: [[Double]], targets: [Double], ridge: Double) -> [Double]? {
        guard !rows.isEmpty, rows.count == targets.count else { return nil }
        let n = rows[0].count
        guard n > 0 else { return nil }

        var normal = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        var rhs = [Double](repeating: 0, count: n)

        for (index, row) in rows.enumerated() {
            guard row.count == n else { return nil }
            let target = targets[index]
            for i in 0..<n {
                rhs[i] += row[i] * target
                for j in i..<n {
                    normal[i][j] += row[i] * row[j]
                }
            }
        }

        for i in 0..<n {
            for j in 0..<i {
                normal[i][j] = normal[j][i]
            }
            normal[i][i] += ridge
        }

        return solve(normal, rhs)
    }
}
