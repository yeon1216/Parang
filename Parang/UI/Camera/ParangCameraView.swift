import SwiftUI
import ComposableArchitecture
import AVFoundation

@Reducer
struct ParangCamera {
    struct State: Equatable {
        var isRecording = false
        var cameraPermissionGranted = false
        var currentMode: CameraMode = .photo
        var flashMode: AVCaptureDevice.FlashMode = .off
        
        enum CameraMode {
            case photo
            case video
        }
    }
    
    enum Action {
        case onAppear
        case tapBack
        case requestCameraPermission
        case cameraPermissionResponse(Bool)
        case toggleRecording
        case capturePhoto
        case switchMode
        case toggleFlash
        case recordingFinished
    }
    
    @Dependency(\.continuousClock) var clock
    
    private enum CameraPermissionKey: DependencyKey {
        static let liveValue: () async -> Bool = { 
            await AVCaptureDevice.requestAccess(for: .video)
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                if status == .authorized {
                    state.cameraPermissionGranted = true
                    return .none
                } else {
                    return .send(.requestCameraPermission)
                }
            case .requestCameraPermission:
                return .run { send in
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    await send(.cameraPermissionResponse(granted))
                }
                
            case let .cameraPermissionResponse(granted):
                state.cameraPermissionGranted = granted
                return .none
                
            case .tapBack:
                return .none
                
            case .toggleRecording:
                state.isRecording.toggle()
                if !state.isRecording {
                    return .send(.recordingFinished)
                }
                return .none
                
            case .capturePhoto:
                // Implement photo capture logic
                return .none
                
            case .switchMode:
                state.currentMode = state.currentMode == .photo ? .video : .photo
                return .none
                
            case .toggleFlash:
                state.flashMode = switch state.flashMode {
                case .off: .on
                case .on: .auto
                case .auto: .off
                @unknown default: .off
                }
                return .none
                
            case .recordingFinished:
                state.isRecording = false
                return .none
            }
        }
    }
}

struct ParangCameraView: View {
    let store: StoreOf<ParangCamera>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewStore.cameraPermissionGranted {
                    CameraPreviewView()
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        HStack {
                            Button(action: { viewStore.send(.tapBack) }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                                    .padding()
                            }
                            
                            Spacer()
                            
                            Button(action: { viewStore.send(.toggleFlash) }) {
                                Image(systemName: flashIcon(for: viewStore.flashMode))
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        HStack(spacing: 60) {
                            Button(action: { viewStore.send(.switchMode) }) {
                                Text(viewStore.currentMode == .photo ? "Photo" : "Video")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            
                            Button(action: {
                                if viewStore.currentMode == .photo {
                                    viewStore.send(.capturePhoto)
                                } else {
                                    viewStore.send(.toggleRecording)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 3)
                                        .frame(width: 70, height: 70)
                                    
                                    if viewStore.currentMode == .video && viewStore.isRecording {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.red)
                                            .frame(width: 30, height: 30)
                                    } else {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 30)
                    }
                } else {
                    VStack {
                        Text("Camera Access Required")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Please grant camera access in Settings to use this feature")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding()
                        
                        Button("Grant Access") {
                            viewStore.send(.requestCameraPermission)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .onAppear { viewStore.send(.onAppear) }
            .navigationBarBackButtonHidden(true)
        }
    }
    
    private func flashIcon(for mode: AVCaptureDevice.FlashMode) -> String {
        switch mode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        @unknown default: return "bolt.slash"
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    private let session = AVCaptureSession()
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
//        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        
        // Configure camera session
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Setup camera input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            return view
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("Failed to create camera input: \(error.localizedDescription)")
            return view
        }
        
        session.commitConfiguration()
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
//        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
//            previewLayer.frame = uiView.bounds
//        }
//        DispatchQueue.main.async {
//            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
//                previewLayer.frame = uiView.bounds
//            }
//        }
        Task {
            await MainActor.run {
                if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                    previewLayer.frame = uiView.bounds
                }
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer,
           let session = previewLayer.session {
            session.stopRunning()
        }
    }
}

#Preview {
    ParangCameraView(
        store: Store(initialState: ParangCamera.State())
        {
            ParangCamera()
        }
    )
} 
