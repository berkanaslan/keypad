import SwiftUI

/// Never truncates (RFC-0000 §8.2): full size on one line, then 60 % on one line, then 60 % wrapped.
struct NumberDisplay: View {
    let text: String

    private static let fullSize: CGFloat = 56
    private static let reducedSize = fullSize * 0.6

    var body: some View {
        ZStack {
            digits("0", size: Self.fullSize).hidden()
            ViewThatFits(in: .horizontal) {
                digits(text, size: Self.fullSize).lineLimit(1)
                digits(text, size: Self.reducedSize).lineLimit(1)
                digits(text, size: Self.reducedSize).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func digits(_ text: String, size: CGFloat) -> some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.center)
    }
}
