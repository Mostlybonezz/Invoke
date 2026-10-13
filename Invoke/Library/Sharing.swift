import SwiftUI
import UIKit
import CoreText

struct RelicShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

enum RelicCardError: LocalizedError {
    case unreadableImage, renderingFailed, layoutFailed
    var errorDescription: String? {
        switch self {
        case .unreadableImage: "The photograph could not be read. Try a different image."
        case .renderingFailed: "The card artwork could not be rendered. Your relic is still saved."
        case .layoutFailed: "The card text could not be laid out. Your relic is still saved."
        }
    }
}

/// A local, themed PDF. Long writing continues onto additional pages without truncation.
@MainActor enum RelicCardExporter {
    static func create(relic: Relic, theme: InvokeTheme, imageURL: URL?) throws -> URL {
        let photo = imageURL.flatMap { UIImage(contentsOfFile: $0.path) }
        let imageRenderer = ImageRenderer(content: RelicCardArtwork(image: photo, theme: theme).frame(width: 499, height: 238))
        imageRenderer.scale = 2
        guard let artwork = imageRenderer.uiImage else { throw RelicCardError.renderingFailed }

        let text = NSMutableAttributedString(string: "")
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 5
        bodyStyle.paragraphSpacing = 16
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.paragraphSpacing = 20
        let textColor = UIColor(theme.text)
        let secondaryColor = UIColor(theme.secondary)
        func append(_ string: String, font: UIFont, color: UIColor, style: NSParagraphStyle? = nil) {
            text.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style ?? bodyStyle]))
        }
        append(relic.name + "\n", font: UIFont(name: "Georgia", size: 29) ?? .systemFont(ofSize: 29), color: textColor, style: titleStyle)
        if !relic.objectType.isEmpty { append(relic.objectType + " · " + relic.status + "\n", font: .systemFont(ofSize: 11), color: secondaryColor) }
        append("MEANING\n", font: .systemFont(ofSize: 10, weight: .semibold), color: secondaryColor)
        append((relic.meaning.isEmpty ? "An object waiting for its story." : relic.meaning) + "\n", font: UIFont(name: "Georgia", size: 14) ?? .systemFont(ofSize: 14), color: textColor)
        if !relic.intention.isEmpty {
            append("INTENTION\n", font: .systemFont(ofSize: 10, weight: .semibold), color: secondaryColor)
            append(relic.intention + "\n", font: UIFont(name: "Georgia", size: 14) ?? .systemFont(ofSize: 14), color: textColor)
        }
        append("DEDICATION\n", font: .systemFont(ofSize: 10, weight: .semibold), color: secondaryColor)
        append(relic.dedication.isEmpty ? "A little meaning, made tangible." : relic.dedication, font: UIFont(name: "Georgia-Italic", size: 14) ?? .italicSystemFont(ofSize: 14), color: textColor)

        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        var failed = false
        let pdf = renderer.pdfData { context in
            var location = 0
            var pageNumber = 0
            while location < text.length {
                context.beginPage()
                pageNumber += 1
                let cg = context.cgContext
                UIColor(theme.background).setFill()
                cg.fill(pageRect)
                UIColor(theme.border).setStroke()
                cg.setLineWidth(0.6)
                cg.stroke(CGRect(x: 25, y: 25, width: 545, height: 792))
                ("Invoke" as NSString).draw(at: CGPoint(x: 48, y: 42), withAttributes: [.font: UIFont(name: "Georgia", size: 22) ?? .systemFont(ofSize: 22), .foregroundColor: textColor])
                ("PERSONAL COLLECTION" as NSString).draw(at: CGPoint(x: 335, y: 48), withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: secondaryColor, .kern: 1.4])
                var top: CGFloat = 98
                if pageNumber == 1 {
                    artwork.draw(in: CGRect(x: 48, y: 91, width: 499, height: 238))
                    top = 354
                }
                let textRect = CGRect(x: 48, y: top, width: 499, height: 775 - top)
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: pageRect.height)
                cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: CGRect(x: textRect.minX, y: pageRect.height - textRect.maxY, width: textRect.width, height: textRect.height), transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
                CTFrameDraw(frame, cg)
                cg.restoreGState()
                let visible = CTFrameGetVisibleStringRange(frame)
                guard visible.length > 0 else { failed = true; break }
                location += visible.length
                ("\(theme.name)  ·  \(pageNumber)" as NSString).draw(at: CGPoint(x: 48, y: 795), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: secondaryColor])
            }
        }
        guard !failed else { throw RelicCardError.layoutFailed }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InvokeSharedCards", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Invoke-Relic-\(UUID().uuidString).pdf")
        try pdf.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return url
    }
}

private struct RelicCardArtwork: View {
    let image: UIImage?
    let theme: InvokeTheme
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                theme.surface
                if let image {
                    if theme.id == "velvet" {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 232, height: 218).clipShape(Ellipse())
                            .overlay(Ellipse().stroke(theme.border, lineWidth: 1).padding(4))
                    } else {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    }
                } else {
                    Image(systemName: "sparkle").font(.system(size: 70, weight: .ultraLight)).foregroundStyle(theme.accent)
                    Circle().stroke(theme.border, lineWidth: 0.6).padding(34)
                }
                Rectangle().stroke(theme.border, lineWidth: 0.8).padding(theme.id == "astral" ? 10 : 1)
            }
        }.clipped()
    }
}

struct NativeShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
