import KeypadCore
import SwiftUI

public struct NoticeView: View {
    private let notice: Notice

    public init(notice: Notice) {
        self.notice = notice
    }

    public var body: some View {
        message
            .font(.callout)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(in: .capsule)
    }

    @ViewBuilder
    private var message: some View {
        switch notice {
        case .secureInput:
            Text("notice.secureInput", bundle: .keypadUI)
        case .permissionGranted:
            Text("notice.permissionGranted", bundle: .keypadUI)
        }
    }
}
