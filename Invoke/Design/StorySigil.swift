import SwiftUI

/// Nine original geometric marks, sharing a ring, axis, and fine engraved stroke.
struct StorySigil: View {
    let shape: String
    @Environment(\.invokeTheme) private var theme
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 40
            context.scaleBy(x: scale, y: scale)
            var path = Path()
            func line(_ points: [CGPoint]) {
                guard let first = points.first else { return }
                path.move(to: first); points.dropFirst().forEach { path.addLine(to: $0) }
            }
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
            path.addEllipse(in: CGRect(x: 7, y: 7, width: 26, height: 26))
            switch StoryCatalog.shapes.firstIndex(of: shape) ?? 1 {
            case 0: line([p(20,3),p(20,37)]); line([p(12,12),p(28,28)]); line([p(28,12),p(12,28)])
            case 1: line([p(20,2),p(23,17),p(38,20),p(23,23),p(20,38),p(17,23),p(2,20),p(17,17),p(20,2)])
            case 2: line([p(4,25),p(17,25),p(17,12),p(28,12),p(28,26),p(36,26)]); line([p(31,21),p(36,26),p(31,31)])
            case 3: line([p(20,37),p(20,3)]); line([p(9,15),p(20,3),p(31,15)]); line([p(12,27),p(28,27)])
            case 4: line([p(20,3),p(20,37)]); line([p(9,25),p(20,37),p(31,25)]); line([p(12,13),p(28,13)])
            case 5: path.addEllipse(in: CGRect(x:14,y:14,width:12,height:12)); line([p(20,0),p(20,9)]); line([p(0,20),p(9,20)]); line([p(31,20),p(40,20)]); line([p(20,31),p(20,40)])
            case 6: path.addEllipse(in: CGRect(x:2,y:10,width:22,height:22)); path.addEllipse(in: CGRect(x:16,y:10,width:22,height:22)); line([p(20,4),p(20,36)])
            case 7: line([p(4,6),p(17,19),p(4,32)]); line([p(36,6),p(23,19),p(36,32)]); line([p(20,33),p(20,39)])
            default: path.move(to:p(2,20)); path.addQuadCurve(to:p(38,20),control:p(20,-2)); path.addQuadCurve(to:p(2,20),control:p(20,42)); path.addEllipse(in:CGRect(x:16,y:16,width:8,height:8))
            }
            context.stroke(path, with: .color(theme.accent), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }.accessibilityHidden(true)
    }
}
