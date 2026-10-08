import SwiftUI

struct MvpnStartupAnimation: View {
    var onFinished: () -> Void

    @State private var p0: CGFloat = 0
    @State private var p1: CGFloat = 0
    @State private var p2: CGFloat = 0
    @State private var p3: CGFloat = 0
    @State private var finished = false

    private let letters = ["M", "v", "p", "n"]
    private let starts: [(CGFloat, CGFloat)] = [(-132, 0), (0, -110), (0, 110), (132, 0)]

    var body: some View {
        ZStack {
            PanelColor.bg.ignoresSafeArea()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 236, height: 236)
                .clipShape(RoundedRectangle(cornerRadius: 44))
                .opacity(0.3)
            HStack(spacing: 0) {
                letterView(0, progress: p0)
                letterView(1, progress: p1)
                letterView(2, progress: p2)
                letterView(3, progress: p3)
            }
        }
        .task {
            await runAnimation()
        }
    }

    @ViewBuilder
    private func letterView(_ index: Int, progress: CGFloat) -> some View {
        Text(letters[index])
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(index % 2 == 0 ? PanelColor.text : PanelColor.accent)
            .offset(
                x: starts[index].0 * (1 - progress),
                y: starts[index].1 * (1 - progress)
            )
            .opacity(Double(progress))
    }

    @MainActor
    private func runAnimation() async {
        let setters: [(CGFloat) -> Void] = [
            { p0 = $0 }, { p1 = $0 }, { p2 = $0 }, { p3 = $0 },
        ]
        for index in 0..<4 {
            if Task.isCancelled {
                complete()
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(index) * 115_000_000)
            withAnimation(.easeInOut(duration: 0.65)) {
                setters[index](1)
            }
        }
        try? await Task.sleep(nanoseconds: 900_000_000)
        complete()
    }

    @MainActor
    private func complete() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}
