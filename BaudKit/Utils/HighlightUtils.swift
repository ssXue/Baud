import SwiftUI

public func highlightedText(_ fullText: String, search: String, baseFont: Font = .system(.caption, design: .monospaced)) -> Text {
    guard !search.isEmpty else {
        return Text(fullText).font(baseFont)
    }
    let caseInsensitive = search.lowercased()
    let lowerText = fullText.lowercased()
    var result = Text("")
    var currentIndex = lowerText.startIndex

    while currentIndex < lowerText.endIndex {
        if let range = lowerText.range(of: caseInsensitive, range: currentIndex..<lowerText.endIndex) {
            if currentIndex < range.lowerBound {
                let before = String(fullText[currentIndex..<range.lowerBound])
                result = result + Text(before).font(baseFont)
            }
            let match = String(fullText[range])
            result = result + Text(match).font(baseFont).bold().foregroundColor(.yellow)
            currentIndex = range.upperBound
        } else {
            let remaining = String(fullText[currentIndex..<lowerText.endIndex])
            result = result + Text(remaining).font(baseFont)
            break
        }
    }
    return result
}
