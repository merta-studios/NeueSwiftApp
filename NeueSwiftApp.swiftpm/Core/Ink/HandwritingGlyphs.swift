import Foundation

/// Single-stroke handwriting templates derived from public-domain Hershey data.
/// See HERSHEY-LICENSE.txt. Coordinates use page-like axes (y grows downwards).
enum HandwritingGlyphs {
    struct Glyph {
        var advance: Double
        var strokes: [[Vec2]]
    }

    private static let table: [Character: Glyph] = [
        "!": Glyph(
            advance: 6,
            strokes: [
                [Vec2(8, 1), Vec2(7, 2), Vec2(5, 14)],
                [Vec2(8, 2), Vec2(5, 14)],
                [Vec2(8, 1), Vec2(9, 2), Vec2(5, 14)],
                [Vec2(3, 20), Vec2(2, 21), Vec2(3, 22), Vec2(4, 21), Vec2(3, 20)],
            ]
        ),
        "\"": Glyph(
            advance: 9,
            strokes: [
                [Vec2(7, 1), Vec2(5, 8)],
                [Vec2(8, 1), Vec2(5, 8)],
                [Vec2(16, 1), Vec2(14, 8)],
                [Vec2(17, 1), Vec2(14, 8)],
            ]
        ),
        "#": Glyph(
            advance: 11,
            strokes: [
                [Vec2(11, -3), Vec2(4, 29)],
                [Vec2(17, -3), Vec2(10, 29)],
                [Vec2(4, 10), Vec2(18, 10)],
                [Vec2(3, 16), Vec2(17, 16)],
            ]
        ),
        "$": Glyph(
            advance: 11,
            strokes: [
                [Vec2(12, -3), Vec2(4, 26)],
                [Vec2(17, -3), Vec2(9, 26)],
                [
                    Vec2(18, 5), Vec2(17, 6), Vec2(18, 7), Vec2(19, 6), Vec2(19, 5), Vec2(18, 3),
                    Vec2(17, 2), Vec2(14, 1), Vec2(10, 1), Vec2(7, 2), Vec2(5, 4), Vec2(5, 6),
                    Vec2(6, 8), Vec2(7, 9), Vec2(14, 13), Vec2(16, 15),
                ],
                [
                    Vec2(5, 6), Vec2(7, 8), Vec2(14, 12), Vec2(15, 13), Vec2(16, 15), Vec2(16, 18),
                    Vec2(15, 20), Vec2(14, 21), Vec2(11, 22), Vec2(7, 22), Vec2(4, 21), Vec2(3, 20),
                    Vec2(2, 18), Vec2(2, 17), Vec2(3, 16), Vec2(4, 17), Vec2(3, 18),
                ],
            ]
        ),
        "%": Glyph(
            advance: 12,
            strokes: [
                [Vec2(21, 1), Vec2(3, 22)],
                [
                    Vec2(8, 1), Vec2(10, 3), Vec2(10, 5), Vec2(9, 7), Vec2(7, 8), Vec2(5, 8),
                    Vec2(3, 6), Vec2(3, 4), Vec2(4, 2), Vec2(6, 1), Vec2(8, 1), Vec2(10, 2),
                    Vec2(13, 3), Vec2(16, 3), Vec2(19, 2), Vec2(21, 1),
                ],
                [
                    Vec2(17, 15), Vec2(15, 16), Vec2(14, 18), Vec2(14, 20), Vec2(16, 22),
                    Vec2(18, 22), Vec2(20, 21), Vec2(21, 19), Vec2(21, 17), Vec2(19, 15),
                    Vec2(17, 15),
                ],
            ]
        ),
        "&": Glyph(
            advance: 13,
            strokes: [
                [
                    Vec2(23, 9), Vec2(22, 10), Vec2(23, 11), Vec2(24, 10), Vec2(24, 9), Vec2(23, 8),
                    Vec2(22, 8), Vec2(20, 9), Vec2(18, 11), Vec2(13, 19), Vec2(11, 21), Vec2(9, 22),
                    Vec2(6, 22), Vec2(3, 21), Vec2(2, 19), Vec2(2, 17), Vec2(3, 15), Vec2(4, 14),
                    Vec2(6, 13), Vec2(11, 11), Vec2(13, 10), Vec2(15, 8), Vec2(16, 6), Vec2(16, 4),
                    Vec2(15, 2), Vec2(13, 1), Vec2(11, 2), Vec2(10, 4), Vec2(10, 7), Vec2(11, 13),
                    Vec2(12, 16), Vec2(14, 19), Vec2(16, 21), Vec2(18, 22), Vec2(20, 22),
                    Vec2(21, 20), Vec2(21, 19),
                ],
                [
                    Vec2(6, 22), Vec2(4, 21), Vec2(3, 19), Vec2(3, 17), Vec2(4, 15), Vec2(5, 14),
                    Vec2(11, 11),
                ],
                [
                    Vec2(10, 7), Vec2(11, 12), Vec2(12, 15), Vec2(14, 18), Vec2(16, 20),
                    Vec2(18, 21), Vec2(20, 21), Vec2(21, 20),
                ],
            ]
        ),
        "'": Glyph(
            advance: 6,
            strokes: [
                [
                    Vec2(8, 3), Vec2(7, 2), Vec2(8, 1), Vec2(9, 2), Vec2(9, 3), Vec2(8, 5),
                    Vec2(6, 7),
                ]
            ]
        ),
        "(": Glyph(
            advance: 8,
            strokes: [
                [
                    Vec2(15, -3), Vec2(11, 0), Vec2(8, 3), Vec2(6, 6), Vec2(4, 10), Vec2(3, 15),
                    Vec2(3, 19), Vec2(4, 24), Vec2(5, 27), Vec2(6, 29),
                ],
                [
                    Vec2(11, 0), Vec2(8, 4), Vec2(6, 8), Vec2(5, 11), Vec2(4, 16), Vec2(4, 21),
                    Vec2(5, 26), Vec2(6, 29),
                ],
            ]
        ),
        ")": Glyph(
            advance: 7,
            strokes: [
                [
                    Vec2(9, -3), Vec2(10, -1), Vec2(11, 2), Vec2(12, 7), Vec2(12, 11), Vec2(11, 16),
                    Vec2(9, 20), Vec2(7, 23), Vec2(4, 26), Vec2(0, 29),
                ],
                [
                    Vec2(9, -3), Vec2(10, 0), Vec2(11, 5), Vec2(11, 10), Vec2(10, 15), Vec2(9, 18),
                    Vec2(7, 22), Vec2(4, 26),
                ],
            ]
        ),
        "*": Glyph(
            advance: 9,
            strokes: [
                [Vec2(10, 1), Vec2(10, 13)],
                [Vec2(5, 4), Vec2(15, 10)],
                [Vec2(15, 4), Vec2(5, 10)],
            ]
        ),
        "+": Glyph(
            advance: 13,
            strokes: [
                [Vec2(13, 4), Vec2(13, 22)],
                [Vec2(4, 13), Vec2(22, 13)],
            ]
        ),
        ",": Glyph(
            advance: 6,
            strokes: [
                [
                    Vec2(3, 22), Vec2(2, 21), Vec2(3, 20), Vec2(4, 21), Vec2(4, 22), Vec2(3, 24),
                    Vec2(1, 26),
                ]
            ]
        ),
        "-": Glyph(
            advance: 13,
            strokes: [
                [Vec2(4, 13), Vec2(22, 13)]
            ]
        ),
        ".": Glyph(
            advance: 5,
            strokes: [
                [Vec2(5, 20), Vec2(4, 21), Vec2(5, 22), Vec2(6, 21), Vec2(5, 20)]
            ]
        ),
        "/": Glyph(
            advance: 11,
            strokes: [
                [Vec2(24, -3), Vec2(-2, 29)]
            ]
        ),
        "0": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(12, 1), Vec2(9, 2), Vec2(7, 4), Vec2(5, 7), Vec2(4, 10), Vec2(3, 14),
                    Vec2(3, 17), Vec2(4, 20), Vec2(5, 21), Vec2(7, 22), Vec2(9, 22), Vec2(12, 21),
                    Vec2(14, 19), Vec2(16, 16), Vec2(17, 13), Vec2(18, 9), Vec2(18, 6), Vec2(17, 3),
                    Vec2(16, 2), Vec2(14, 1), Vec2(12, 1),
                ],
                [
                    Vec2(12, 1), Vec2(10, 2), Vec2(8, 4), Vec2(6, 7), Vec2(5, 10), Vec2(4, 14),
                    Vec2(4, 17), Vec2(5, 20), Vec2(7, 22),
                ],
                [
                    Vec2(9, 22), Vec2(11, 21), Vec2(13, 19), Vec2(15, 16), Vec2(16, 13),
                    Vec2(17, 9), Vec2(17, 6), Vec2(16, 3), Vec2(14, 1),
                ],
            ]
        ),
        "1": Glyph(
            advance: 11,
            strokes: [
                [Vec2(12, 5), Vec2(7, 22)],
                [Vec2(14, 1), Vec2(8, 22)],
                [Vec2(14, 1), Vec2(11, 4), Vec2(8, 6), Vec2(6, 7)],
                [Vec2(13, 4), Vec2(9, 6), Vec2(6, 7)],
            ]
        ),
        "2": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(7, 5), Vec2(8, 6), Vec2(7, 7), Vec2(6, 6), Vec2(6, 5), Vec2(7, 3),
                    Vec2(8, 2), Vec2(11, 1), Vec2(14, 1), Vec2(17, 2), Vec2(18, 4), Vec2(18, 6),
                    Vec2(17, 8), Vec2(15, 10), Vec2(12, 12), Vec2(8, 14), Vec2(5, 16), Vec2(3, 18),
                    Vec2(1, 22),
                ],
                [
                    Vec2(14, 1), Vec2(16, 2), Vec2(17, 4), Vec2(17, 6), Vec2(16, 8), Vec2(14, 10),
                    Vec2(8, 14),
                ],
                [
                    Vec2(2, 20), Vec2(3, 19), Vec2(5, 19), Vec2(10, 21), Vec2(13, 21), Vec2(15, 20),
                    Vec2(16, 18),
                ],
                [Vec2(5, 19), Vec2(10, 22), Vec2(13, 22), Vec2(15, 21), Vec2(16, 18)],
            ]
        ),
        "3": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(7, 5), Vec2(8, 6), Vec2(7, 7), Vec2(6, 6), Vec2(6, 5), Vec2(7, 3),
                    Vec2(8, 2), Vec2(11, 1), Vec2(14, 1), Vec2(17, 2), Vec2(18, 4), Vec2(18, 6),
                    Vec2(17, 8), Vec2(14, 10), Vec2(11, 11),
                ],
                [Vec2(14, 1), Vec2(16, 2), Vec2(17, 4), Vec2(17, 6), Vec2(16, 8), Vec2(14, 10)],
                [
                    Vec2(9, 11), Vec2(11, 11), Vec2(14, 12), Vec2(15, 13), Vec2(16, 15),
                    Vec2(16, 18), Vec2(15, 20), Vec2(14, 21), Vec2(11, 22), Vec2(7, 22),
                    Vec2(4, 21), Vec2(3, 20), Vec2(2, 18), Vec2(2, 17), Vec2(3, 16), Vec2(4, 17),
                    Vec2(3, 18),
                ],
                [
                    Vec2(11, 11), Vec2(13, 12), Vec2(14, 13), Vec2(15, 15), Vec2(15, 18),
                    Vec2(14, 20), Vec2(13, 21), Vec2(11, 22),
                ],
            ]
        ),
        "4": Glyph(
            advance: 11,
            strokes: [
                [Vec2(16, 2), Vec2(10, 22)],
                [Vec2(17, 1), Vec2(11, 22)],
                [Vec2(17, 1), Vec2(2, 16), Vec2(18, 16)],
            ]
        ),
        "5": Glyph(
            advance: 11,
            strokes: [
                [Vec2(9, 1), Vec2(4, 11)],
                [Vec2(9, 1), Vec2(19, 1)],
                [Vec2(9, 2), Vec2(14, 2), Vec2(19, 1)],
                [
                    Vec2(4, 11), Vec2(5, 10), Vec2(8, 9), Vec2(11, 9), Vec2(14, 10), Vec2(15, 11),
                    Vec2(16, 13), Vec2(16, 16), Vec2(15, 19), Vec2(13, 21), Vec2(10, 22),
                    Vec2(7, 22), Vec2(4, 21), Vec2(3, 20), Vec2(2, 18), Vec2(2, 17), Vec2(3, 16),
                    Vec2(4, 17), Vec2(3, 18),
                ],
                [
                    Vec2(11, 9), Vec2(13, 10), Vec2(14, 11), Vec2(15, 13), Vec2(15, 16),
                    Vec2(14, 19), Vec2(12, 21), Vec2(10, 22),
                ],
            ]
        ),
        "6": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(17, 4), Vec2(16, 5), Vec2(17, 6), Vec2(18, 5), Vec2(18, 4), Vec2(17, 2),
                    Vec2(15, 1), Vec2(12, 1), Vec2(9, 2), Vec2(7, 4), Vec2(5, 7), Vec2(4, 10),
                    Vec2(3, 14), Vec2(3, 18), Vec2(4, 20), Vec2(5, 21), Vec2(7, 22), Vec2(10, 22),
                    Vec2(13, 21), Vec2(15, 19), Vec2(16, 17), Vec2(16, 14), Vec2(15, 12),
                    Vec2(14, 11), Vec2(12, 10), Vec2(9, 10), Vec2(7, 11), Vec2(5, 13), Vec2(4, 15),
                ],
                [
                    Vec2(12, 1), Vec2(10, 2), Vec2(8, 4), Vec2(6, 7), Vec2(5, 10), Vec2(4, 14),
                    Vec2(4, 19), Vec2(5, 21),
                ],
                [
                    Vec2(10, 22), Vec2(12, 21), Vec2(14, 19), Vec2(15, 17), Vec2(15, 13),
                    Vec2(14, 11),
                ],
            ]
        ),
        "7": Glyph(
            advance: 11,
            strokes: [
                [Vec2(6, 1), Vec2(4, 7)],
                [
                    Vec2(19, 1), Vec2(18, 4), Vec2(16, 7), Vec2(11, 13), Vec2(9, 16), Vec2(8, 18),
                    Vec2(7, 22),
                ],
                [Vec2(16, 7), Vec2(10, 13), Vec2(8, 16), Vec2(7, 18), Vec2(6, 22)],
                [Vec2(5, 4), Vec2(8, 1), Vec2(10, 1), Vec2(15, 4)],
                [
                    Vec2(6, 3), Vec2(8, 2), Vec2(10, 2), Vec2(15, 4), Vec2(17, 4), Vec2(18, 3),
                    Vec2(19, 1),
                ],
            ]
        ),
        "8": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(11, 1), Vec2(8, 2), Vec2(7, 3), Vec2(6, 5), Vec2(6, 8), Vec2(7, 10),
                    Vec2(9, 11), Vec2(12, 11), Vec2(16, 10), Vec2(17, 9), Vec2(18, 7), Vec2(18, 4),
                    Vec2(17, 2), Vec2(14, 1), Vec2(11, 1),
                ],
                [
                    Vec2(11, 1), Vec2(9, 2), Vec2(8, 3), Vec2(7, 5), Vec2(7, 8), Vec2(8, 10),
                    Vec2(9, 11),
                ],
                [
                    Vec2(12, 11), Vec2(15, 10), Vec2(16, 9), Vec2(17, 7), Vec2(17, 4), Vec2(16, 2),
                    Vec2(14, 1),
                ],
                [
                    Vec2(9, 11), Vec2(5, 12), Vec2(3, 14), Vec2(2, 16), Vec2(2, 19), Vec2(3, 21),
                    Vec2(6, 22), Vec2(10, 22), Vec2(14, 21), Vec2(15, 20), Vec2(16, 18),
                    Vec2(16, 15), Vec2(15, 13), Vec2(14, 12), Vec2(12, 11),
                ],
                [
                    Vec2(9, 11), Vec2(6, 12), Vec2(4, 14), Vec2(3, 16), Vec2(3, 19), Vec2(4, 21),
                    Vec2(6, 22),
                ],
                [
                    Vec2(10, 22), Vec2(13, 21), Vec2(14, 20), Vec2(15, 18), Vec2(15, 14),
                    Vec2(14, 12),
                ],
            ]
        ),
        "9": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(17, 8), Vec2(16, 10), Vec2(14, 12), Vec2(12, 13), Vec2(9, 13), Vec2(7, 12),
                    Vec2(6, 11), Vec2(5, 9), Vec2(5, 6), Vec2(6, 4), Vec2(8, 2), Vec2(11, 1),
                    Vec2(14, 1), Vec2(16, 2), Vec2(17, 3), Vec2(18, 5), Vec2(18, 9), Vec2(17, 13),
                    Vec2(16, 16), Vec2(14, 19), Vec2(12, 21), Vec2(9, 22), Vec2(6, 22), Vec2(4, 21),
                    Vec2(3, 19), Vec2(3, 18), Vec2(4, 17), Vec2(5, 18), Vec2(4, 19),
                ],
                [Vec2(7, 12), Vec2(6, 10), Vec2(6, 6), Vec2(7, 4), Vec2(9, 2), Vec2(11, 1)],
                [
                    Vec2(16, 2), Vec2(17, 4), Vec2(17, 9), Vec2(16, 13), Vec2(15, 16), Vec2(13, 19),
                    Vec2(11, 21), Vec2(9, 22),
                ],
            ]
        ),
        ":": Glyph(
            advance: 6,
            strokes: [
                [Vec2(6, 8), Vec2(5, 9), Vec2(6, 10), Vec2(7, 9), Vec2(6, 8)],
                [Vec2(3, 20), Vec2(2, 21), Vec2(3, 22), Vec2(4, 21)],
            ]
        ),
        ";": Glyph(
            advance: 6,
            strokes: [
                [Vec2(6, 8), Vec2(5, 9), Vec2(6, 10), Vec2(7, 9), Vec2(6, 8)],
                [
                    Vec2(3, 22), Vec2(2, 21), Vec2(3, 20), Vec2(4, 21), Vec2(4, 22), Vec2(3, 24),
                    Vec2(1, 26),
                ],
            ]
        ),
        "<": Glyph(
            advance: 12,
            strokes: [
                [Vec2(20, 4), Vec2(4, 13), Vec2(20, 22)]
            ]
        ),
        "=": Glyph(
            advance: 13,
            strokes: [
                [Vec2(4, 10), Vec2(22, 10)],
                [Vec2(4, 16), Vec2(22, 16)],
            ]
        ),
        ">": Glyph(
            advance: 12,
            strokes: [
                [Vec2(4, 4), Vec2(20, 13), Vec2(4, 22)]
            ]
        ),
        "?": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(7, 5), Vec2(8, 6), Vec2(7, 7), Vec2(6, 6), Vec2(6, 5), Vec2(7, 3),
                    Vec2(8, 2), Vec2(11, 1), Vec2(15, 1), Vec2(18, 2), Vec2(19, 4), Vec2(19, 6),
                    Vec2(18, 8), Vec2(17, 9), Vec2(11, 11), Vec2(9, 12), Vec2(9, 14), Vec2(10, 15),
                    Vec2(12, 15),
                ],
                [
                    Vec2(15, 1), Vec2(17, 2), Vec2(18, 4), Vec2(18, 6), Vec2(17, 8), Vec2(16, 9),
                    Vec2(14, 10),
                ],
                [Vec2(8, 20), Vec2(7, 21), Vec2(8, 22), Vec2(9, 21), Vec2(8, 20)],
            ]
        ),
        "@": Glyph(
            advance: 14,
            strokes: [
                [
                    Vec2(18, 9), Vec2(17, 7), Vec2(15, 6), Vec2(12, 6), Vec2(10, 7), Vec2(9, 8),
                    Vec2(8, 11), Vec2(8, 14), Vec2(9, 16), Vec2(11, 17), Vec2(14, 17), Vec2(16, 16),
                    Vec2(17, 14),
                ],
                [Vec2(12, 6), Vec2(10, 8), Vec2(9, 11), Vec2(9, 14), Vec2(10, 16), Vec2(11, 17)],
                [
                    Vec2(18, 6), Vec2(17, 14), Vec2(17, 16), Vec2(19, 17), Vec2(21, 17),
                    Vec2(23, 15), Vec2(24, 12), Vec2(24, 10), Vec2(23, 7), Vec2(22, 5), Vec2(20, 3),
                    Vec2(18, 2), Vec2(15, 1), Vec2(12, 1), Vec2(9, 2), Vec2(7, 3), Vec2(5, 5),
                    Vec2(4, 7), Vec2(3, 10), Vec2(3, 13), Vec2(4, 16), Vec2(5, 18), Vec2(7, 20),
                    Vec2(9, 21), Vec2(12, 22), Vec2(15, 22), Vec2(18, 21), Vec2(20, 20),
                    Vec2(21, 19),
                ],
                [Vec2(19, 6), Vec2(18, 14), Vec2(18, 16), Vec2(19, 17)],
            ]
        ),
        "A": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(0, 22), Vec2(2, 21), Vec2(5, 18), Vec2(8, 14), Vec2(12, 7), Vec2(15, 1),
                    Vec2(15, 22), Vec2(14, 19), Vec2(12, 16), Vec2(10, 14), Vec2(7, 12),
                    Vec2(5, 12), Vec2(4, 13), Vec2(4, 15), Vec2(5, 17), Vec2(7, 19), Vec2(10, 21),
                    Vec2(13, 22), Vec2(18, 22),
                ]
            ]
        ),
        "B": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(13, 3), Vec2(14, 4), Vec2(14, 7), Vec2(13, 11), Vec2(12, 14), Vec2(11, 16),
                    Vec2(9, 19), Vec2(7, 21), Vec2(5, 22), Vec2(4, 22), Vec2(3, 21), Vec2(3, 18),
                    Vec2(4, 13), Vec2(5, 10), Vec2(6, 8), Vec2(8, 5), Vec2(10, 3), Vec2(12, 2),
                    Vec2(15, 1), Vec2(18, 1), Vec2(20, 2), Vec2(21, 4), Vec2(21, 6), Vec2(20, 8),
                    Vec2(19, 9), Vec2(17, 10), Vec2(14, 11),
                ],
                [
                    Vec2(13, 11), Vec2(14, 11), Vec2(17, 12), Vec2(18, 13), Vec2(19, 15),
                    Vec2(19, 18), Vec2(18, 20), Vec2(17, 21), Vec2(15, 22), Vec2(12, 22),
                    Vec2(10, 21), Vec2(9, 19),
                ],
            ]
        ),
        "C": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(12, 7), Vec2(12, 8), Vec2(13, 9), Vec2(15, 9), Vec2(17, 8), Vec2(18, 6),
                    Vec2(18, 4), Vec2(17, 2), Vec2(15, 1), Vec2(12, 1), Vec2(9, 2), Vec2(7, 4),
                    Vec2(5, 7), Vec2(4, 9), Vec2(3, 13), Vec2(3, 17), Vec2(4, 20), Vec2(5, 21),
                    Vec2(7, 22), Vec2(9, 22), Vec2(12, 21), Vec2(14, 19), Vec2(15, 17),
                ]
            ]
        ),
        "D": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(13, 1), Vec2(11, 2), Vec2(10, 4), Vec2(9, 8), Vec2(8, 14), Vec2(7, 17),
                    Vec2(6, 19), Vec2(4, 21), Vec2(2, 22), Vec2(0, 22), Vec2(-1, 21), Vec2(-1, 19),
                    Vec2(0, 18), Vec2(2, 18), Vec2(4, 19), Vec2(6, 21), Vec2(9, 22), Vec2(12, 22),
                    Vec2(15, 21), Vec2(17, 19), Vec2(19, 15), Vec2(20, 10), Vec2(20, 6),
                    Vec2(19, 3), Vec2(18, 2), Vec2(16, 1), Vec2(13, 1), Vec2(11, 3), Vec2(11, 5),
                    Vec2(12, 8), Vec2(14, 11), Vec2(16, 13), Vec2(19, 15), Vec2(21, 16),
                ]
            ]
        ),
        "E": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(14, 5), Vec2(14, 6), Vec2(15, 7), Vec2(17, 7), Vec2(18, 6), Vec2(18, 4),
                    Vec2(17, 2), Vec2(14, 1), Vec2(10, 1), Vec2(7, 2), Vec2(6, 4), Vec2(6, 7),
                    Vec2(7, 9), Vec2(8, 10), Vec2(11, 11), Vec2(8, 11), Vec2(5, 12), Vec2(4, 13),
                    Vec2(3, 15), Vec2(3, 18), Vec2(4, 20), Vec2(5, 21), Vec2(8, 22), Vec2(11, 22),
                    Vec2(14, 21), Vec2(16, 19), Vec2(17, 17),
                ]
            ]
        ),
        "F": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(10, 7), Vec2(8, 7), Vec2(6, 6), Vec2(5, 4), Vec2(6, 2), Vec2(9, 1),
                    Vec2(12, 1), Vec2(16, 2), Vec2(19, 2), Vec2(21, 1),
                ],
                [
                    Vec2(16, 2), Vec2(14, 9), Vec2(12, 15), Vec2(10, 19), Vec2(8, 21), Vec2(6, 22),
                    Vec2(4, 22), Vec2(2, 21), Vec2(1, 19), Vec2(1, 17), Vec2(2, 16), Vec2(4, 16),
                    Vec2(6, 17),
                ],
                [Vec2(9, 11), Vec2(18, 11)],
            ]
        ),
        "G": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(0, 22), Vec2(2, 21), Vec2(6, 17), Vec2(9, 12), Vec2(10, 9), Vec2(11, 5),
                    Vec2(11, 2), Vec2(10, 1), Vec2(9, 1), Vec2(8, 2), Vec2(7, 4), Vec2(7, 7),
                    Vec2(8, 9), Vec2(10, 10), Vec2(14, 10), Vec2(17, 9), Vec2(18, 8), Vec2(19, 6),
                    Vec2(19, 12), Vec2(18, 17), Vec2(17, 19), Vec2(15, 21), Vec2(12, 22),
                    Vec2(8, 22), Vec2(5, 21), Vec2(3, 19), Vec2(2, 17), Vec2(2, 15),
                ]
            ]
        ),
        "H": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(7, 8), Vec2(5, 7), Vec2(4, 5), Vec2(4, 4), Vec2(5, 2), Vec2(7, 1),
                    Vec2(8, 1), Vec2(10, 2), Vec2(11, 4), Vec2(11, 6), Vec2(10, 10), Vec2(8, 16),
                    Vec2(6, 20), Vec2(4, 22), Vec2(2, 22), Vec2(1, 21), Vec2(1, 19),
                ],
                [
                    Vec2(7, 13), Vec2(16, 10), Vec2(18, 9), Vec2(21, 7), Vec2(23, 5), Vec2(24, 3),
                    Vec2(24, 2), Vec2(23, 1), Vec2(22, 1), Vec2(20, 3), Vec2(18, 7), Vec2(16, 13),
                    Vec2(15, 18), Vec2(15, 21), Vec2(16, 22), Vec2(17, 22), Vec2(19, 21),
                    Vec2(20, 20), Vec2(22, 17),
                ],
            ]
        ),
        "I": Glyph(
            advance: 8,
            strokes: [
                [
                    Vec2(14, 17), Vec2(12, 15), Vec2(10, 12), Vec2(9, 10), Vec2(8, 7), Vec2(8, 4),
                    Vec2(9, 2), Vec2(10, 1), Vec2(12, 1), Vec2(13, 2), Vec2(14, 4), Vec2(14, 7),
                    Vec2(13, 12), Vec2(11, 17), Vec2(10, 19), Vec2(8, 21), Vec2(6, 22), Vec2(4, 22),
                    Vec2(2, 21), Vec2(1, 19), Vec2(1, 17), Vec2(2, 16), Vec2(4, 16), Vec2(6, 17),
                ]
            ]
        ),
        "J": Glyph(
            advance: 7,
            strokes: [
                [
                    Vec2(10, 25), Vec2(8, 22), Vec2(6, 17), Vec2(5, 11), Vec2(5, 5), Vec2(6, 2),
                    Vec2(8, 1), Vec2(10, 1), Vec2(11, 2), Vec2(12, 5), Vec2(12, 8), Vec2(11, 13),
                    Vec2(8, 22), Vec2(6, 28), Vec2(5, 31), Vec2(4, 33), Vec2(2, 34), Vec2(1, 33),
                    Vec2(1, 31), Vec2(2, 28), Vec2(4, 25), Vec2(6, 23), Vec2(9, 21), Vec2(13, 19),
                ]
            ]
        ),
        "K": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(7, 8), Vec2(5, 7), Vec2(4, 5), Vec2(4, 4), Vec2(5, 2), Vec2(7, 1),
                    Vec2(8, 1), Vec2(10, 2), Vec2(11, 4), Vec2(11, 6), Vec2(10, 10), Vec2(8, 16),
                    Vec2(6, 20), Vec2(4, 22), Vec2(2, 22), Vec2(1, 21), Vec2(1, 19),
                ],
                [
                    Vec2(24, 4), Vec2(24, 2), Vec2(23, 1), Vec2(22, 1), Vec2(20, 2), Vec2(18, 4),
                    Vec2(16, 7), Vec2(14, 9), Vec2(12, 10), Vec2(10, 10),
                ],
                [
                    Vec2(12, 10), Vec2(13, 12), Vec2(13, 19), Vec2(14, 21), Vec2(15, 22),
                    Vec2(16, 22), Vec2(18, 21), Vec2(19, 20), Vec2(21, 17),
                ],
            ]
        ),
        "L": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(4, 13), Vec2(6, 13), Vec2(10, 12), Vec2(13, 10), Vec2(15, 8), Vec2(16, 6),
                    Vec2(16, 3), Vec2(15, 1), Vec2(13, 1), Vec2(12, 2), Vec2(11, 4), Vec2(10, 9),
                    Vec2(9, 14), Vec2(8, 17), Vec2(7, 19), Vec2(5, 21), Vec2(3, 22), Vec2(1, 22),
                    Vec2(0, 21), Vec2(0, 19), Vec2(1, 18), Vec2(3, 18), Vec2(5, 19), Vec2(8, 21),
                    Vec2(11, 22), Vec2(13, 22), Vec2(16, 21), Vec2(18, 19),
                ]
            ]
        ),
        "M": Glyph(
            advance: 15,
            strokes: [
                [
                    Vec2(5, 8), Vec2(3, 7), Vec2(2, 5), Vec2(2, 4), Vec2(3, 2), Vec2(5, 1),
                    Vec2(6, 1), Vec2(8, 2), Vec2(9, 4), Vec2(9, 6), Vec2(8, 11), Vec2(7, 15),
                    Vec2(5, 22),
                ],
                [
                    Vec2(7, 15), Vec2(10, 7), Vec2(12, 3), Vec2(13, 2), Vec2(15, 1), Vec2(16, 1),
                    Vec2(18, 2), Vec2(19, 4), Vec2(19, 6), Vec2(18, 11), Vec2(17, 15), Vec2(15, 22),
                ],
                [
                    Vec2(17, 15), Vec2(20, 7), Vec2(22, 3), Vec2(23, 2), Vec2(25, 1), Vec2(26, 1),
                    Vec2(28, 2), Vec2(29, 4), Vec2(29, 6), Vec2(28, 11), Vec2(26, 18), Vec2(26, 21),
                    Vec2(27, 22), Vec2(28, 22), Vec2(30, 21), Vec2(31, 20), Vec2(33, 17),
                ],
            ]
        ),
        "N": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(5, 8), Vec2(3, 7), Vec2(2, 5), Vec2(2, 4), Vec2(3, 2), Vec2(5, 1),
                    Vec2(6, 1), Vec2(8, 2), Vec2(9, 4), Vec2(9, 6), Vec2(8, 11), Vec2(7, 15),
                    Vec2(5, 22),
                ],
                [
                    Vec2(7, 15), Vec2(10, 7), Vec2(12, 3), Vec2(13, 2), Vec2(15, 1), Vec2(17, 1),
                    Vec2(19, 2), Vec2(20, 4), Vec2(20, 6), Vec2(19, 11), Vec2(17, 18), Vec2(17, 21),
                    Vec2(18, 22), Vec2(19, 22), Vec2(21, 21), Vec2(22, 20), Vec2(24, 17),
                ],
            ]
        ),
        "O": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(12, 1), Vec2(9, 2), Vec2(7, 4), Vec2(5, 7), Vec2(4, 9), Vec2(3, 13),
                    Vec2(3, 17), Vec2(4, 20), Vec2(5, 21), Vec2(7, 22), Vec2(9, 22), Vec2(12, 21),
                    Vec2(14, 19), Vec2(16, 16), Vec2(17, 14), Vec2(18, 10), Vec2(18, 6),
                    Vec2(17, 3), Vec2(16, 2), Vec2(14, 1), Vec2(12, 1), Vec2(10, 3), Vec2(10, 6),
                    Vec2(11, 9), Vec2(13, 12), Vec2(15, 14), Vec2(18, 16), Vec2(20, 17),
                ]
            ]
        ),
        "P": Glyph(
            advance: 13,
            strokes: [
                [
                    Vec2(13, 3), Vec2(14, 4), Vec2(14, 7), Vec2(13, 11), Vec2(12, 14), Vec2(11, 16),
                    Vec2(9, 19), Vec2(7, 21), Vec2(5, 22), Vec2(4, 22), Vec2(3, 21), Vec2(3, 18),
                    Vec2(4, 13), Vec2(5, 10), Vec2(6, 8), Vec2(8, 5), Vec2(10, 3), Vec2(12, 2),
                    Vec2(15, 1), Vec2(20, 1), Vec2(22, 2), Vec2(23, 3), Vec2(24, 5), Vec2(24, 8),
                    Vec2(23, 10), Vec2(22, 11), Vec2(20, 12), Vec2(17, 12), Vec2(15, 11),
                    Vec2(14, 10),
                ]
            ]
        ),
        "Q": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(13, 7), Vec2(12, 9), Vec2(11, 10), Vec2(9, 11), Vec2(7, 11), Vec2(6, 9),
                    Vec2(6, 7), Vec2(7, 4), Vec2(9, 2), Vec2(12, 1), Vec2(15, 1), Vec2(17, 2),
                    Vec2(18, 4), Vec2(18, 8), Vec2(17, 11), Vec2(15, 14), Vec2(11, 18), Vec2(8, 20),
                    Vec2(6, 21), Vec2(3, 22), Vec2(1, 22), Vec2(0, 21), Vec2(0, 19), Vec2(1, 18),
                    Vec2(3, 18), Vec2(5, 19), Vec2(8, 21), Vec2(11, 22), Vec2(14, 22), Vec2(17, 21),
                    Vec2(19, 19),
                ]
            ]
        ),
        "R": Glyph(
            advance: 13,
            strokes: [
                [
                    Vec2(13, 3), Vec2(14, 4), Vec2(14, 7), Vec2(13, 11), Vec2(12, 14), Vec2(11, 16),
                    Vec2(9, 19), Vec2(7, 21), Vec2(5, 22), Vec2(4, 22), Vec2(3, 21), Vec2(3, 18),
                    Vec2(4, 13), Vec2(5, 10), Vec2(6, 8), Vec2(8, 5), Vec2(10, 3), Vec2(12, 2),
                    Vec2(15, 1), Vec2(19, 1), Vec2(21, 2), Vec2(22, 3), Vec2(23, 5), Vec2(23, 8),
                    Vec2(22, 10), Vec2(21, 11), Vec2(19, 12), Vec2(16, 12), Vec2(13, 11),
                    Vec2(14, 12), Vec2(15, 14), Vec2(15, 19), Vec2(16, 21), Vec2(18, 22),
                    Vec2(20, 21), Vec2(21, 20), Vec2(23, 17),
                ]
            ]
        ),
        "S": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(0, 22), Vec2(2, 21), Vec2(4, 19), Vec2(7, 15), Vec2(9, 12), Vec2(11, 8),
                    Vec2(12, 5), Vec2(12, 2), Vec2(11, 1), Vec2(10, 1), Vec2(9, 2), Vec2(8, 4),
                    Vec2(8, 6), Vec2(9, 8), Vec2(11, 10), Vec2(14, 12), Vec2(16, 14), Vec2(17, 16),
                    Vec2(17, 18), Vec2(16, 20), Vec2(15, 21), Vec2(12, 22), Vec2(8, 22),
                    Vec2(5, 21), Vec2(3, 19), Vec2(2, 17), Vec2(2, 15),
                ]
            ]
        ),
        "T": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(10, 7), Vec2(8, 7), Vec2(6, 6), Vec2(5, 4), Vec2(6, 2), Vec2(9, 1),
                    Vec2(12, 1), Vec2(16, 2), Vec2(19, 2), Vec2(21, 1),
                ],
                [
                    Vec2(16, 2), Vec2(14, 9), Vec2(12, 15), Vec2(10, 19), Vec2(8, 21), Vec2(6, 22),
                    Vec2(4, 22), Vec2(2, 21), Vec2(1, 19), Vec2(1, 17), Vec2(2, 16), Vec2(4, 16),
                    Vec2(6, 17),
                ],
            ]
        ),
        "U": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(5, 8), Vec2(3, 7), Vec2(2, 5), Vec2(2, 4), Vec2(3, 2), Vec2(5, 1),
                    Vec2(6, 1), Vec2(8, 2), Vec2(9, 4), Vec2(9, 6), Vec2(8, 10), Vec2(7, 13),
                    Vec2(6, 17), Vec2(6, 19), Vec2(7, 21), Vec2(9, 22), Vec2(11, 22), Vec2(13, 21),
                    Vec2(14, 20), Vec2(16, 16), Vec2(19, 8), Vec2(21, 1),
                ],
                [
                    Vec2(19, 8), Vec2(18, 12), Vec2(17, 18), Vec2(17, 21), Vec2(18, 22),
                    Vec2(19, 22), Vec2(21, 21), Vec2(22, 20), Vec2(24, 17),
                ],
            ]
        ),
        "V": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(5, 8), Vec2(3, 7), Vec2(2, 5), Vec2(2, 4), Vec2(3, 2), Vec2(5, 1),
                    Vec2(6, 1), Vec2(8, 2), Vec2(9, 4), Vec2(9, 6), Vec2(8, 10), Vec2(7, 13),
                    Vec2(6, 17), Vec2(6, 20), Vec2(7, 22), Vec2(9, 22), Vec2(11, 21), Vec2(14, 18),
                    Vec2(16, 15), Vec2(18, 11), Vec2(19, 8), Vec2(20, 4), Vec2(20, 2), Vec2(19, 1),
                    Vec2(18, 1), Vec2(17, 2), Vec2(16, 4), Vec2(16, 6), Vec2(17, 9), Vec2(19, 11),
                    Vec2(21, 12),
                ]
            ]
        ),
        "W": Glyph(
            advance: 13,
            strokes: [
                [
                    Vec2(5, 8), Vec2(3, 7), Vec2(2, 5), Vec2(2, 4), Vec2(3, 2), Vec2(5, 1),
                    Vec2(6, 1), Vec2(8, 2), Vec2(9, 4), Vec2(9, 7), Vec2(8, 22),
                ],
                [Vec2(18, 1), Vec2(8, 22)],
                [Vec2(18, 1), Vec2(16, 22)],
                [Vec2(30, 1), Vec2(28, 2), Vec2(25, 5), Vec2(22, 9), Vec2(19, 15), Vec2(16, 22)],
            ]
        ),
        "X": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(8, 7), Vec2(6, 7), Vec2(5, 6), Vec2(5, 4), Vec2(6, 2), Vec2(8, 1),
                    Vec2(10, 1), Vec2(12, 2), Vec2(13, 4), Vec2(13, 7), Vec2(11, 16), Vec2(11, 19),
                    Vec2(12, 21), Vec2(14, 22), Vec2(16, 22), Vec2(18, 21), Vec2(19, 19),
                    Vec2(19, 17), Vec2(18, 16), Vec2(16, 16),
                ],
                [
                    Vec2(23, 4), Vec2(23, 2), Vec2(22, 1), Vec2(20, 1), Vec2(18, 2), Vec2(16, 4),
                    Vec2(14, 7), Vec2(10, 16), Vec2(8, 19), Vec2(6, 21), Vec2(4, 22), Vec2(2, 22),
                    Vec2(1, 21), Vec2(1, 19),
                ],
            ]
        ),
        "Y": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(5, 8), Vec2(3, 7), Vec2(2, 5), Vec2(2, 4), Vec2(3, 2), Vec2(5, 1),
                    Vec2(6, 1), Vec2(8, 2), Vec2(9, 4), Vec2(9, 6), Vec2(8, 10), Vec2(7, 13),
                    Vec2(6, 17), Vec2(6, 19), Vec2(7, 21), Vec2(8, 22), Vec2(10, 22), Vec2(12, 21),
                    Vec2(14, 19), Vec2(16, 16), Vec2(17, 14), Vec2(19, 8),
                ],
                [
                    Vec2(21, 1), Vec2(19, 8), Vec2(16, 18), Vec2(14, 24), Vec2(12, 29),
                    Vec2(10, 33), Vec2(8, 34), Vec2(7, 33), Vec2(7, 31), Vec2(8, 28), Vec2(10, 25),
                    Vec2(13, 22), Vec2(16, 20), Vec2(21, 17),
                ],
            ]
        ),
        "Z": Glyph(
            advance: 11,
            strokes: [
                [
                    Vec2(13, 7), Vec2(12, 9), Vec2(11, 10), Vec2(9, 11), Vec2(7, 11), Vec2(6, 9),
                    Vec2(6, 7), Vec2(7, 4), Vec2(9, 2), Vec2(12, 1), Vec2(15, 1), Vec2(17, 2),
                    Vec2(18, 4), Vec2(18, 8), Vec2(17, 11), Vec2(15, 15), Vec2(12, 18), Vec2(8, 21),
                    Vec2(6, 22), Vec2(3, 22), Vec2(2, 21), Vec2(2, 19), Vec2(3, 18), Vec2(6, 18),
                    Vec2(8, 19), Vec2(9, 20), Vec2(10, 22), Vec2(10, 25), Vec2(9, 28), Vec2(8, 30),
                    Vec2(6, 33), Vec2(4, 34), Vec2(3, 33), Vec2(3, 31), Vec2(4, 28), Vec2(6, 25),
                    Vec2(9, 22), Vec2(12, 20), Vec2(18, 17),
                ]
            ]
        ),
        "[": Glyph(
            advance: 7,
            strokes: [
                [Vec2(4, -3), Vec2(4, 29)],
                [Vec2(5, -3), Vec2(5, 29)],
                [Vec2(4, -3), Vec2(11, -3)],
                [Vec2(4, 29), Vec2(11, 29)],
            ]
        ),
        "\\": Glyph(
            advance: 7,
            strokes: [
                [Vec2(0, 1), Vec2(14, 25)]
            ]
        ),
        "]": Glyph(
            advance: 7,
            strokes: [
                [Vec2(9, -3), Vec2(9, 29)],
                [Vec2(10, -3), Vec2(10, 29)],
                [Vec2(3, -3), Vec2(10, -3)],
                [Vec2(3, 29), Vec2(10, 29)],
            ]
        ),
        "^": Glyph(
            advance: 8,
            strokes: [
                [Vec2(6, 7), Vec2(8, 4), Vec2(10, 7)],
                [Vec2(3, 10), Vec2(8, 5), Vec2(13, 10)],
                [Vec2(8, 5), Vec2(8, 22)],
            ]
        ),
        "_": Glyph(
            advance: 8,
            strokes: [
                [Vec2(0, 24), Vec2(16, 24)]
            ]
        ),
        "`": Glyph(
            advance: 6,
            strokes: [
                [
                    Vec2(9, 1), Vec2(7, 3), Vec2(6, 5), Vec2(6, 6), Vec2(7, 7), Vec2(8, 6),
                    Vec2(7, 5),
                ]
            ]
        ),
        "a": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(9, 16), Vec2(8, 14), Vec2(6, 13), Vec2(4, 13), Vec2(2, 14), Vec2(1, 15),
                    Vec2(0, 17), Vec2(0, 19), Vec2(1, 21), Vec2(3, 22), Vec2(5, 22), Vec2(7, 21),
                    Vec2(8, 19), Vec2(10, 13), Vec2(9, 18), Vec2(9, 21), Vec2(10, 22), Vec2(11, 22),
                    Vec2(13, 21), Vec2(14, 20), Vec2(16, 17),
                ]
            ]
        ),
        "b": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(5, 9), Vec2(6, 7), Vec2(7, 4), Vec2(7, 2),
                    Vec2(6, 1), Vec2(4, 2), Vec2(3, 4), Vec2(2, 8), Vec2(1, 15), Vec2(1, 21),
                    Vec2(2, 22), Vec2(3, 22), Vec2(5, 21), Vec2(7, 19), Vec2(8, 16), Vec2(8, 13),
                    Vec2(9, 17), Vec2(10, 18), Vec2(12, 18), Vec2(14, 17),
                ]
            ]
        ),
        "c": Glyph(
            advance: 6,
            strokes: [
                [
                    Vec2(7, 15), Vec2(7, 14), Vec2(6, 13), Vec2(4, 13), Vec2(2, 14), Vec2(1, 15),
                    Vec2(0, 17), Vec2(0, 19), Vec2(1, 21), Vec2(3, 22), Vec2(6, 22), Vec2(9, 20),
                    Vec2(11, 17),
                ]
            ]
        ),
        "d": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(9, 16), Vec2(8, 14), Vec2(6, 13), Vec2(4, 13), Vec2(2, 14), Vec2(1, 15),
                    Vec2(0, 17), Vec2(0, 19), Vec2(1, 21), Vec2(3, 22), Vec2(5, 22), Vec2(7, 21),
                    Vec2(8, 19), Vec2(14, 1),
                ],
                [
                    Vec2(10, 13), Vec2(9, 18), Vec2(9, 21), Vec2(10, 22), Vec2(11, 22),
                    Vec2(13, 21), Vec2(14, 20), Vec2(16, 17),
                ],
            ]
        ),
        "e": Glyph(
            advance: 6,
            strokes: [
                [
                    Vec2(1, 20), Vec2(3, 19), Vec2(4, 18), Vec2(5, 16), Vec2(5, 14), Vec2(4, 13),
                    Vec2(3, 13), Vec2(1, 14), Vec2(0, 16), Vec2(0, 19), Vec2(1, 21), Vec2(3, 22),
                    Vec2(5, 22), Vec2(7, 21), Vec2(8, 20), Vec2(10, 17),
                ]
            ]
        ),
        "f": Glyph(
            advance: 5,
            strokes: [
                [
                    Vec2(0, 17), Vec2(4, 12), Vec2(6, 9), Vec2(7, 7), Vec2(8, 4), Vec2(8, 2),
                    Vec2(7, 1), Vec2(5, 2), Vec2(4, 4), Vec2(2, 12), Vec2(-1, 21), Vec2(-4, 28),
                    Vec2(-5, 31), Vec2(-5, 33), Vec2(-4, 34), Vec2(-2, 33), Vec2(-1, 30),
                    Vec2(0, 21), Vec2(1, 22), Vec2(3, 22), Vec2(5, 21), Vec2(6, 20), Vec2(8, 17),
                ]
            ]
        ),
        "g": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(9, 16), Vec2(8, 14), Vec2(6, 13), Vec2(4, 13), Vec2(2, 14), Vec2(1, 15),
                    Vec2(0, 17), Vec2(0, 19), Vec2(1, 21), Vec2(3, 22), Vec2(5, 22), Vec2(7, 21),
                    Vec2(8, 20),
                ],
                [
                    Vec2(10, 13), Vec2(8, 20), Vec2(4, 31), Vec2(3, 33), Vec2(1, 34), Vec2(0, 33),
                    Vec2(0, 31), Vec2(1, 28), Vec2(4, 25), Vec2(7, 23), Vec2(9, 22), Vec2(12, 20),
                    Vec2(15, 17),
                ],
            ]
        ),
        "h": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(5, 9), Vec2(6, 7), Vec2(7, 4), Vec2(7, 2),
                    Vec2(6, 1), Vec2(4, 2), Vec2(3, 4), Vec2(2, 8), Vec2(1, 14), Vec2(0, 22),
                ],
                [
                    Vec2(0, 22), Vec2(1, 19), Vec2(2, 17), Vec2(4, 14), Vec2(6, 13), Vec2(8, 13),
                    Vec2(9, 14), Vec2(9, 16), Vec2(8, 19), Vec2(8, 21), Vec2(9, 22), Vec2(10, 22),
                    Vec2(12, 21), Vec2(13, 20), Vec2(15, 17),
                ],
            ]
        ),
        "i": Glyph(
            advance: 5,
            strokes: [
                [Vec2(3, 8), Vec2(3, 9), Vec2(4, 9), Vec2(4, 8), Vec2(3, 8)],
                [
                    Vec2(0, 17), Vec2(2, 13), Vec2(0, 19), Vec2(0, 21), Vec2(1, 22), Vec2(2, 22),
                    Vec2(4, 21), Vec2(5, 20), Vec2(7, 17),
                ],
            ]
        ),
        "j": Glyph(
            advance: 5,
            strokes: [
                [Vec2(3, 8), Vec2(3, 9), Vec2(4, 9), Vec2(4, 8), Vec2(3, 8)],
                [
                    Vec2(0, 17), Vec2(2, 13), Vec2(-4, 31), Vec2(-5, 33), Vec2(-7, 34),
                    Vec2(-8, 33), Vec2(-8, 31), Vec2(-7, 28), Vec2(-4, 25), Vec2(-1, 23),
                    Vec2(1, 22), Vec2(4, 20), Vec2(7, 17),
                ],
            ]
        ),
        "k": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(5, 9), Vec2(6, 7), Vec2(7, 4), Vec2(7, 2),
                    Vec2(6, 1), Vec2(4, 2), Vec2(3, 4), Vec2(2, 8), Vec2(1, 14), Vec2(0, 22),
                ],
                [
                    Vec2(0, 22), Vec2(1, 19), Vec2(2, 17), Vec2(4, 14), Vec2(6, 13), Vec2(8, 13),
                    Vec2(9, 14), Vec2(9, 16), Vec2(7, 17), Vec2(4, 17),
                ],
                [
                    Vec2(4, 17), Vec2(6, 18), Vec2(7, 21), Vec2(8, 22), Vec2(9, 22), Vec2(11, 21),
                    Vec2(12, 20), Vec2(14, 17),
                ],
            ]
        ),
        "l": Glyph(
            advance: 5,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(5, 9), Vec2(6, 7), Vec2(7, 4), Vec2(7, 2),
                    Vec2(6, 1), Vec2(4, 2), Vec2(3, 4), Vec2(2, 8), Vec2(1, 15), Vec2(1, 21),
                    Vec2(2, 22), Vec2(3, 22), Vec2(5, 21), Vec2(6, 20), Vec2(8, 17),
                ]
            ]
        ),
        "m": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(4, 13), Vec2(5, 14), Vec2(5, 15), Vec2(4, 19),
                    Vec2(3, 22),
                ],
                [
                    Vec2(4, 19), Vec2(5, 17), Vec2(7, 14), Vec2(9, 13), Vec2(11, 13), Vec2(12, 14),
                    Vec2(12, 15), Vec2(11, 19), Vec2(10, 22),
                ],
                [
                    Vec2(11, 19), Vec2(12, 17), Vec2(14, 14), Vec2(16, 13), Vec2(18, 13),
                    Vec2(19, 14), Vec2(19, 16), Vec2(18, 19), Vec2(18, 21), Vec2(19, 22),
                    Vec2(20, 22), Vec2(22, 21), Vec2(23, 20), Vec2(25, 17),
                ],
            ]
        ),
        "n": Glyph(
            advance: 10,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(4, 13), Vec2(5, 14), Vec2(5, 15), Vec2(4, 19),
                    Vec2(3, 22),
                ],
                [
                    Vec2(4, 19), Vec2(5, 17), Vec2(7, 14), Vec2(9, 13), Vec2(11, 13), Vec2(12, 14),
                    Vec2(12, 16), Vec2(11, 19), Vec2(11, 21), Vec2(12, 22), Vec2(13, 22),
                    Vec2(15, 21), Vec2(16, 20), Vec2(18, 17),
                ],
            ]
        ),
        "o": Glyph(
            advance: 8,
            strokes: [
                [
                    Vec2(6, 13), Vec2(4, 13), Vec2(2, 14), Vec2(1, 15), Vec2(0, 17), Vec2(0, 19),
                    Vec2(1, 21), Vec2(3, 22), Vec2(5, 22), Vec2(7, 21), Vec2(8, 20), Vec2(9, 18),
                    Vec2(9, 16), Vec2(8, 14), Vec2(6, 13), Vec2(5, 14), Vec2(5, 16), Vec2(6, 18),
                    Vec2(8, 19), Vec2(11, 19), Vec2(13, 18), Vec2(14, 17),
                ]
            ]
        ),
        "p": Glyph(
            advance: 8,
            strokes: [
                [Vec2(0, 17), Vec2(2, 14), Vec2(3, 12), Vec2(2, 16), Vec2(-4, 34)],
                [
                    Vec2(2, 16), Vec2(3, 14), Vec2(5, 13), Vec2(7, 13), Vec2(9, 14), Vec2(10, 16),
                    Vec2(10, 18), Vec2(9, 20), Vec2(8, 21), Vec2(6, 22),
                ],
                [Vec2(2, 21), Vec2(4, 22), Vec2(7, 22), Vec2(10, 21), Vec2(12, 20), Vec2(15, 17)],
            ]
        ),
        "q": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(9, 16), Vec2(8, 14), Vec2(6, 13), Vec2(4, 13), Vec2(2, 14), Vec2(1, 15),
                    Vec2(0, 17), Vec2(0, 19), Vec2(1, 21), Vec2(3, 22), Vec2(5, 22), Vec2(7, 21),
                ],
                [
                    Vec2(10, 13), Vec2(9, 16), Vec2(7, 21), Vec2(4, 28), Vec2(3, 31), Vec2(3, 33),
                    Vec2(4, 34), Vec2(6, 33), Vec2(7, 30), Vec2(7, 23), Vec2(9, 22), Vec2(12, 20),
                    Vec2(15, 17),
                ],
            ]
        ),
        "r": Glyph(
            advance: 8,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(3, 12), Vec2(3, 14), Vec2(6, 14), Vec2(7, 15),
                    Vec2(7, 17), Vec2(6, 20), Vec2(6, 21), Vec2(7, 22), Vec2(8, 22), Vec2(10, 21),
                    Vec2(11, 20), Vec2(13, 17),
                ]
            ]
        ),
        "s": Glyph(
            advance: 7,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(3, 12), Vec2(3, 14), Vec2(5, 17), Vec2(6, 19),
                    Vec2(6, 21), Vec2(4, 22),
                ],
                [Vec2(0, 21), Vec2(2, 22), Vec2(6, 22), Vec2(8, 21), Vec2(9, 20), Vec2(11, 17)],
            ]
        ),
        "t": Glyph(
            advance: 6,
            strokes: [
                [Vec2(0, 17), Vec2(2, 14), Vec2(4, 10)],
                [
                    Vec2(7, 1), Vec2(1, 19), Vec2(1, 21), Vec2(2, 22), Vec2(4, 22), Vec2(6, 21),
                    Vec2(7, 20), Vec2(9, 17),
                ],
                [Vec2(1, 9), Vec2(8, 9)],
            ]
        ),
        "u": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 13), Vec2(0, 19), Vec2(0, 21), Vec2(1, 22), Vec2(3, 22),
                    Vec2(5, 21), Vec2(7, 19), Vec2(9, 16),
                ],
                [
                    Vec2(10, 13), Vec2(8, 19), Vec2(8, 21), Vec2(9, 22), Vec2(10, 22), Vec2(12, 21),
                    Vec2(13, 20), Vec2(15, 17),
                ],
            ]
        ),
        "v": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 13), Vec2(1, 18), Vec2(1, 21), Vec2(2, 22), Vec2(3, 22),
                    Vec2(6, 21), Vec2(8, 19), Vec2(9, 16), Vec2(9, 13),
                ],
                [Vec2(9, 13), Vec2(10, 17), Vec2(11, 18), Vec2(13, 18), Vec2(15, 17)],
            ]
        ),
        "w": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(3, 13), Vec2(1, 15), Vec2(0, 18), Vec2(0, 20), Vec2(1, 22), Vec2(3, 22),
                    Vec2(5, 21), Vec2(7, 19),
                ],
                [
                    Vec2(9, 13), Vec2(7, 19), Vec2(7, 21), Vec2(8, 22), Vec2(10, 22), Vec2(12, 21),
                    Vec2(14, 19), Vec2(15, 16), Vec2(15, 13),
                ],
                [Vec2(15, 13), Vec2(16, 17), Vec2(17, 18), Vec2(19, 18), Vec2(21, 17)],
            ]
        ),
        "x": Glyph(
            advance: 8,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(4, 13), Vec2(6, 13), Vec2(7, 14), Vec2(7, 21),
                    Vec2(8, 22), Vec2(11, 22), Vec2(14, 20), Vec2(16, 17),
                ],
                [
                    Vec2(13, 14), Vec2(12, 13), Vec2(10, 13), Vec2(9, 14), Vec2(5, 21), Vec2(4, 22),
                    Vec2(2, 22), Vec2(1, 21),
                ],
            ]
        ),
        "y": Glyph(
            advance: 9,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 13), Vec2(0, 19), Vec2(0, 21), Vec2(1, 22), Vec2(3, 22),
                    Vec2(5, 21), Vec2(7, 19), Vec2(9, 16),
                ],
                [
                    Vec2(10, 13), Vec2(4, 31), Vec2(3, 33), Vec2(1, 34), Vec2(0, 33), Vec2(0, 31),
                    Vec2(1, 28), Vec2(4, 25), Vec2(7, 23), Vec2(9, 22), Vec2(12, 20), Vec2(15, 17),
                ],
            ]
        ),
        "z": Glyph(
            advance: 8,
            strokes: [
                [
                    Vec2(0, 17), Vec2(2, 14), Vec2(4, 13), Vec2(6, 13), Vec2(8, 15), Vec2(8, 17),
                    Vec2(7, 19), Vec2(5, 21), Vec2(2, 22), Vec2(4, 23), Vec2(5, 25), Vec2(5, 28),
                    Vec2(4, 31), Vec2(3, 33), Vec2(1, 34), Vec2(0, 33), Vec2(0, 31), Vec2(1, 28),
                    Vec2(4, 25), Vec2(7, 23), Vec2(11, 20), Vec2(14, 17),
                ]
            ]
        ),
        "{": Glyph(
            advance: 7,
            strokes: [
                [
                    Vec2(9, -3), Vec2(7, -2), Vec2(6, -1), Vec2(5, 1), Vec2(5, 3), Vec2(6, 5),
                    Vec2(7, 6), Vec2(8, 8), Vec2(8, 10), Vec2(6, 12),
                ],
                [
                    Vec2(7, -2), Vec2(6, 0), Vec2(6, 2), Vec2(7, 4), Vec2(8, 5), Vec2(9, 7),
                    Vec2(9, 9), Vec2(8, 11), Vec2(4, 13), Vec2(8, 15), Vec2(9, 17), Vec2(9, 19),
                    Vec2(8, 21), Vec2(7, 22), Vec2(6, 24), Vec2(6, 26), Vec2(7, 28),
                ],
                [
                    Vec2(6, 14), Vec2(8, 16), Vec2(8, 18), Vec2(7, 20), Vec2(6, 21), Vec2(5, 23),
                    Vec2(5, 25), Vec2(6, 27), Vec2(7, 28), Vec2(9, 29),
                ],
            ]
        ),
        "|": Glyph(
            advance: 4,
            strokes: [
                [Vec2(4, -3), Vec2(4, 29)]
            ]
        ),
        "}": Glyph(
            advance: 7,
            strokes: [
                [
                    Vec2(5, -3), Vec2(7, -2), Vec2(8, -1), Vec2(9, 1), Vec2(9, 3), Vec2(8, 5),
                    Vec2(7, 6), Vec2(6, 8), Vec2(6, 10), Vec2(8, 12),
                ],
                [
                    Vec2(7, -2), Vec2(8, 0), Vec2(8, 2), Vec2(7, 4), Vec2(6, 5), Vec2(5, 7),
                    Vec2(5, 9), Vec2(6, 11), Vec2(10, 13), Vec2(6, 15), Vec2(5, 17), Vec2(5, 19),
                    Vec2(6, 21), Vec2(7, 22), Vec2(8, 24), Vec2(8, 26), Vec2(7, 28),
                ],
                [
                    Vec2(8, 14), Vec2(6, 16), Vec2(6, 18), Vec2(7, 20), Vec2(8, 21), Vec2(9, 23),
                    Vec2(9, 25), Vec2(8, 27), Vec2(7, 28), Vec2(5, 29),
                ],
            ]
        ),
        "~": Glyph(
            advance: 12,
            strokes: [
                [
                    Vec2(3, 16), Vec2(3, 14), Vec2(4, 11), Vec2(6, 10), Vec2(8, 10), Vec2(10, 11),
                    Vec2(14, 14), Vec2(16, 15), Vec2(18, 15), Vec2(20, 14), Vec2(21, 12),
                ],
                [
                    Vec2(3, 14), Vec2(4, 12), Vec2(6, 11), Vec2(8, 11), Vec2(10, 12), Vec2(14, 15),
                    Vec2(16, 16), Vec2(18, 16), Vec2(20, 15), Vec2(21, 12), Vec2(21, 10),
                ],
            ]
        ),
    ]

    static func glyph(for character: Character) -> Glyph? {
        if let direct = table[character] { return direct }
        let base: Character
        switch character {
        case "ä": base = "a"
        case "ö": base = "o"
        case "ü": base = "u"
        case "Ä": base = "A"
        case "Ö": base = "O"
        case "Ü": base = "U"
        case "ß":
            return Glyph(
                advance: 18,
                strokes: [
                    [
                        Vec2(2, 20), Vec2(5, 4), Vec2(8, 0), Vec2(12, 0), Vec2(14, 3),
                        Vec2(13, 7), Vec2(9, 11), Vec2(13, 14), Vec2(14, 18), Vec2(11, 21),
                        Vec2(7, 20),
                    ]
                ]
            )
        default: return nil
        }
        guard var result = table[base] else { return nil }
        let lift = base.isUppercase ? -5.0 : -4.0
        result.strokes.append([Vec2(5, lift), Vec2(5.1, lift + 0.1)])
        result.strokes.append([Vec2(10, lift), Vec2(10.1, lift + 0.1)])
        return result
    }
}
