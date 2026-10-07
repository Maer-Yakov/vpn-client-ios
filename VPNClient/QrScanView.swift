import AVFoundation
import SwiftUI
import UIKit

struct QrScanView: View {
    @EnvironmentObject private var model: AppModel
    @State private var granted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var asked = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "QR-код", action: "Назад") {
                model.show(.importKey)
            }
            if granted {
                Text("Наведите камеру на QR-код.")
                    .font(.system(size: 14))
                    .foregroundStyle(PanelColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                ZStack {
                    CameraPreview { value in
                        guard KeyImport.looksLikeVPNKey(value) else { return }
                        model.importText(value)
                    }
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(PanelColor.accent, lineWidth: 2)
                        .frame(width: 240, height: 240)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Чтобы считать ключ, разрешите приложению камеру.")
                    .font(.system(size: 14))
                    .foregroundStyle(PanelColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GhostButton(title: "Разрешить камеру") {
                    requestAccess()
                }
                .padding(.top, 12)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onAppear {
            if !granted, !asked {
                asked = true
                requestAccess()
            }
        }
    }

    private func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { allowed in
            DispatchQueue.main.async {
                granted = allowed
            }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    var onCode: (String) -> Void

    func makeUIView(context: Context) -> CameraView {
        let view = CameraView()
        view.onCode = onCode
        view.start()
        return view
    }

    func updateUIView(_ uiView: CameraView, context: Context) {
        uiView.onCode = onCode
    }
}

final class CameraView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var handled = false
    private var preview: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        nil
    }

    func start() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        preview = layer
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        preview?.frame = bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !handled,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue,
              KeyImport.looksLikeVPNKey(value) else { return }
        handled = true
        session.stopRunning()
        onCode?(value)
    }
}
