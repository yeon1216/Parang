import SwiftUI
import MetalKit
import AVFoundation

/// Metal을 사용하여 비디오를 표시하는 SwiftUI 뷰
/// AVPlayer의 출력을 Metal을 통해 렌더링하여 커스텀 비디오 표시 기능을 제공
struct MetalVideoView: UIViewRepresentable {
    /// 비디오 재생을 담당하는 AVPlayer 인스턴스
    let player: AVPlayer
    
    /// UIViewRepresentable 프로토콜 요구사항
    /// 뷰의 조정과 이벤트 처리를 담당하는 Coordinator 인스턴스 생성
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// UIViewRepresentable 프로토콜 요구사항
    /// Metal 뷰 인스턴스를 생성하고 초기 설정을 수행
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly = false  // 텍스처에서 읽기 작업 허용
        mtkView.colorPixelFormat = .bgra8Unorm  // 표준 BGRA 8비트 포맷
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)  // 배경색 검정
        mtkView.isPaused = true  // 수동으로 디스플레이 갱신 제어
        mtkView.enableSetNeedsDisplay = true  // setNeedsDisplay() 호출 허용
        
        context.coordinator.view = mtkView
        context.coordinator.setupPlayerOutput(player)
        return mtkView
    }
    
    /// UIViewRepresentable 프로토콜 요구사항
    /// 뷰의 업데이트가 필요할 때 호출
    func updateUIView(_ uiView: MTKView, context: Context) {}
    
    /// Metal 뷰의 델리게이트와 비디오 출력을 관리하는 코디네이터 클래스
    class Coordinator: NSObject, MTKViewDelegate {
        /// 부모 MetalVideoView에 대한 참조
        let parent: MetalVideoView
        /// Metal 렌더링을 수행하는 렌더러
        let renderer: VideoRenderer
        /// 화면 주사율에 맞춰 프레임 업데이트를 동기화하는 디스플레이 링크
        var displayLink: CADisplayLink?
        /// 현재 처리 중인 비디오 프레임 버퍼
        var currentPixelBuffer: CVPixelBuffer?
        /// AVPlayer로부터 비디오 프레임을 받아오는 출력 객체
        var videoOutput: AVPlayerItemVideoOutput?
        /// Metal 뷰 참조 (약한 참조로 순환 참조 방지)
        weak var view: MTKView?
        
        /// 코디네이터 초기화
        init(_ parent: MetalVideoView) {
            self.parent = parent
            self.renderer = VideoRenderer()
            super.init()
        }
        
        /// 리소스 정리
        deinit {
            cleanup()
        }
        
        /// 비디오 출력과 디스플레이 링크 정리
        func cleanup() {
            displayLink?.invalidate()
            displayLink = nil
            if let videoOutput = videoOutput {
                parent.player.currentItem?.remove(videoOutput)
            }
            videoOutput = nil
        }
        
        /// AVPlayer 출력 설정
        /// - Parameter player: 비디오 프레임을 제공할 AVPlayer 인스턴스
        func setupPlayerOutput(_ player: AVPlayer) {
            cleanup()
            
            // BGRA 포맷으로 픽셀 버퍼 요청 설정
            let pixelBufferAttributes = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            let output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
            player.currentItem?.add(output)
            self.videoOutput = output
            
            // 화면 주사율에 맞춰 프레임 업데이트 설정
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        /// 디스플레이 링크 콜백 - 새로운 비디오 프레임이 필요할 때 호출
        @objc func displayLinkDidFire() {
            guard let videoOutput = videoOutput,
                  let currentItem = parent.player.currentItem else { return }
            
            // 다음 수직 동기화 시점 계산
            let nextVSync = displayLink?.timestamp ?? CACurrentMediaTime()
            let itemTime = videoOutput.itemTime(forHostTime: nextVSync)
            
            // 재생 준비 상태와 새 프레임 여부 확인
            guard currentItem.status == .readyToPlay,
                  videoOutput.hasNewPixelBuffer(forItemTime: itemTime) else {
                return
            }
            
            // 새 프레임을 가져와서 렌더링 요청
            if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                self.currentPixelBuffer = pixelBuffer
                view?.setNeedsDisplay()
            }
        }
        
        // MARK: - MTKViewDelegate
        
        /// 뷰 크기 변경 시 호출되는 메서드
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // 뷰 크기가 변경될 때 필요한 처리를 여기에 추가
        }
        
        /// Metal 뷰가 새로운 프레임을 그려야 할 때 호출되는 메서드
        func draw(in view: MTKView) {
            guard let pixelBuffer = currentPixelBuffer else { return }
            
            let orientation: UIInterfaceOrientation
            if #available(iOS 15.0, *) {
                orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
            } else {
                orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
            }
            
            renderer.render(pixelBuffer: pixelBuffer, in: view, orientation: orientation)
        }
    }
}