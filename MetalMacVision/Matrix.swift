import SwiftUI

struct Matrix: View {
    var value: simd_float4x4

    private var rows: [[Float]] {
        (0..<4).map { row in
            (0..<4).map { column in
                value[column][row]
            }
        }
    }

    var body: some View {
        Grid {
            ForEach(0..<4, id: \.self) { row in
                GridRow {
                    ForEach(0..<4, id: \.self) { column in
                        Text(String(format: "%.3f", rows[row][column]))
                    }
                }
            }
        }
        .monospacedDigit()
        .fixedSize()
    }
}
