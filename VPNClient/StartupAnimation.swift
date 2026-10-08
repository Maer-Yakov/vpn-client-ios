import SwiftUI

struct MvpnStartupAnimation: View {
    var onFinished: () -> Void

    @State private var progress: [CGFloat] = [0, 0, 0, 0]
    @State private var visible = true
    private let letters = ["M", "v", "p", "n"]
    private let starts: [(CGFloat, CGFloat)] = [(-132, 0), (0, -110), (0, 110), (132, 0)]

    var body: some View {
        ZStack {
            if visible {
                ZStack {
                    PanelColor.bg.ignoresSafeArea()
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 236, height: 236)
                        .clipShape(RoundedRectangle(cornerRadius: 44))
                        .opacity(0.3)
                    HStack(spacing: 0) {
                        ForEach(0..<letters.count, id: \.self) { index in
                            Text(letters[index])
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(index % 2 == 0 ? PanelColor.text : PanelColor.accent)
                                .offset(
                                    x: starts[index].0 * (1 - progress[index]),
                                    y: starts[index].1 * (1 - progress[index])
                                )
                                .opacity(progress[index])
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            for index in 0..<4 {
                try? await Task.sleep(nanoseconds: UInt64(index) * 115_000_000)
                withAnimation(.easeInOut(duration: 0.65)) {
                    progress[index] = 1
                }
            }
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            withAnimation(.easeOut(duration: 0.28)) {
                visible = false
            }
            try? await Task.sleep(nanoseconds: 280_000_000)
            onFinished()
        }
    }
}
