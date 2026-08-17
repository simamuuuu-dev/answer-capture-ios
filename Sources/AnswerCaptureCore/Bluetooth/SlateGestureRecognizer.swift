import Foundation

public enum SlateGestureRecognizer {
    public static func normalize(_ point: SlatePoint, settings: SlateGestureSettings) -> SlatePoint {
        var x = min(1, max(0, point.x <= 1 ? point.x : point.x / settings.sourceWidth))
        var y = min(1, max(0, point.y <= 1 ? point.y : point.y / settings.sourceHeight))
        switch settings.orientation {
        case .buttonTop:
            break
        case .buttonBottom:
            x = 1 - x
            y = 1 - y
        case .buttonLeft:
            (x, y) = (y, 1 - x)
        case .buttonRight:
            (x, y) = (1 - y, x)
        }
        return SlatePoint(x: x, y: y, tMs: point.tMs, pressure: point.pressure)
    }

    public static func detect(
        _ raw: [SlateStroke],
        settings: SlateGestureSettings = .init()
    ) -> SlateDetection {
        let strokes = raw
            .map {
                SlateStroke(
                    strokeId: $0.strokeId,
                    points: $0.points.map { normalize($0, settings: settings) },
                    startedAtMs: $0.startedAtMs,
                    endedAtMs: $0.endedAtMs
                )
            }
            .filter { !$0.points.isEmpty }
        guard !strokes.isEmpty else {
            return .init(accepted: false, kind: "", reason: "no_strokes", commandStrokeIds: [])
        }
        let last = strokes[strokes.count - 1]
        if one(last, settings) {
            return acceptedIfAnswerExists(
                strokes,
                kind: "one_stroke_l",
                commandStrokeIds: [last.strokeId]
            )
        }
        if strokes.count >= 2 {
            let vertical = strokes[strokes.count - 2]
            if two(vertical, last, settings) {
                return acceptedIfAnswerExists(
                    strokes,
                    kind: "two_stroke_l",
                    commandStrokeIds: [vertical.strokeId, last.strokeId]
                )
            }
        }
        return .init(
            accepted: false,
            kind: "",
            reason: "no_finalize_command",
            commandStrokeIds: []
        )
    }

    private static func acceptedIfAnswerExists(
        _ strokes: [SlateStroke],
        kind: String,
        commandStrokeIds: [String]
    ) -> SlateDetection {
        let command = Set(commandStrokeIds)
        guard strokes.contains(where: { !command.contains($0.strokeId) && !$0.points.isEmpty }) else {
            return .init(
                accepted: false,
                kind: "",
                reason: "empty_answer",
                commandStrokeIds: commandStrokeIds
            )
        }
        return .init(accepted: true, kind: kind, reason: "", commandStrokeIds: commandStrokeIds)
    }

    public static func answerStrokesOnly(
        _ strokes: [SlateStroke],
        detection: SlateDetection
    ) -> [SlateStroke] {
        strokes.filter { !detection.commandStrokeIds.contains($0.strokeId) }
    }

    private static func bounds(
        _ strokes: [SlateStroke]
    ) -> (minX: Double, minY: Double, maxX: Double, maxY: Double)? {
        let points = strokes.flatMap(\.points)
        guard let first = points.first else { return nil }
        return points.dropFirst().reduce((first.x, first.y, first.x, first.y)) {
            (
                min($0.0, $1.x),
                min($0.1, $1.y),
                max($0.2, $1.x),
                max($0.3, $1.y)
            )
        }
    }

    private static func corner(_ strokes: [SlateStroke], _ settings: SlateGestureSettings) -> Bool {
        guard let bounds = bounds(strokes) else { return false }
        let x0 = 1 - 38 / settings.pageWidthMm
        let y0 = 1 - 38 / settings.pageHeightMm
        return bounds.minX >= x0 - 0.015
            && bounds.minY >= y0 - 0.015
            && bounds.maxX >= x0
            && bounds.maxY >= y0
    }

    private static func size(_ strokes: [SlateStroke], _ settings: SlateGestureSettings) -> Bool {
        guard let bounds = bounds(strokes) else { return false }
        let width = (bounds.maxX - bounds.minX) * settings.pageWidthMm
        let height = (bounds.maxY - bounds.minY) * settings.pageHeightMm
        return width >= 3 && width <= 20 && height >= 6 && height <= 28
    }

    private static func one(_ stroke: SlateStroke, _ settings: SlateGestureSettings) -> Bool {
        guard stroke.points.count >= 4,
              corner([stroke], settings),
              size([stroke], settings) else { return false }
        let duration = stroke.endedAtMs >= 0 && stroke.startedAtMs >= 0
            ? stroke.endedAtMs - stroke.startedAtMs
            : -1
        guard duration < 0 || (duration >= 100 && duration <= 2000) else { return false }
        guard let bounds = bounds([stroke]) else { return false }
        let width = max(0.0001, bounds.maxX - bounds.minX)
        let height = max(0.0001, bounds.maxY - bounds.minY)
        let first = stroke.points[0]
        let last = stroke.points.last!
        return stroke.points.dropFirst().dropLast().contains { point in
            let vertical = point.y - first.y >= height * 0.45
                && abs(point.x - first.x) <= width * 0.8
            let horizontalRight = last.x - point.x >= width * 0.45
                && abs(last.y - point.y) <= height * 0.6
                && last.x >= first.x - width * 0.2
            let horizontalLeft = point.x - last.x >= width * 0.45
                && abs(last.y - point.y) <= height * 0.6
                && last.x <= first.x + width * 0.2
            return vertical
                && point.y >= bounds.minY + height * 0.45
                && (horizontalRight || horizontalLeft)
        }
    }

    private static func two(
        _ vertical: SlateStroke,
        _ horizontal: SlateStroke,
        _ settings: SlateGestureSettings
    ) -> Bool {
        guard corner([vertical, horizontal], settings),
              size([vertical, horizontal], settings) else { return false }
        if vertical.endedAtMs >= 0,
           horizontal.startedAtMs >= 0,
           horizontal.startedAtMs - vertical.endedAtMs > 700 {
            return false
        }
        guard let v0 = vertical.points.first,
              let v1 = vertical.points.last,
              let h0 = horizontal.points.first,
              let h1 = horizontal.points.last else {
            return false
        }
        let verticalWidth = abs(v1.x - v0.x) * settings.pageWidthMm
        let verticalHeight = (v1.y - v0.y) * settings.pageHeightMm
        let horizontalWidth = abs(h1.x - h0.x) * settings.pageWidthMm
        let horizontalHeight = (h1.y - h0.y) * settings.pageHeightMm
        let join = hypot(
            (h0.x - v1.x) * settings.pageWidthMm,
            (h0.y - v1.y) * settings.pageHeightMm
        )
        return verticalHeight >= 8
            && verticalHeight >= verticalWidth * 1.2
            && horizontalWidth >= 4
            && horizontalWidth >= horizontalHeight * 1.2
            && join <= 10
    }
}
