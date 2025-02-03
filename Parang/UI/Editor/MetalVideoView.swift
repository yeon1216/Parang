import SwiftUI
import MetalKit
import AVFoundation

struct MetalVideoView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
        
        context.coordinator.view = mtkView
        context.coordinator.setupPlayerOutput(player)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
    
    class Coordinator: NSObject, MTKViewDelegate {
        let parent: MetalVideoView
        let renderer: VideoRenderer
        var displayLink: CADisplayLink?
        var currentPixelBuffer: CVPixelBuffer?
        var videoOutput: AVPlayerItemVideoOutput?
        weak var view: MTKView?
        
        init(_ parent: MetalVideoView) {
            self.parent = parent
            self.renderer = VideoRenderer()
            super.init()
        }
        
        deinit {
            cleanup()
        }
        
        func cleanup() {
            displayLink?.invalidate()
            displayLink = nil
            if let videoOutput = videoOutput {
                parent.player.currentItem?.remove(videoOutput)
            }
            videoOutput = nil
        }
        
        func setupPlayerOutput(_ player: AVPlayer) {
            cleanup()
            
            let pixelBufferAttributes = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            let output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
            player.currentItem?.add(output)
            self.videoOutput = output
            
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        @objc func displayLinkDidFire() {
            guard let videoOutput = videoOutput,
                  let currentItem = parent.player.currentItem else { return }
            
            let nextVSync = displayLink?.timestamp ?? CACurrentMediaTime()
            let itemTime = videoOutput.itemTime(forHostTime: nextVSync)
            
            guard currentItem.status == .readyToPlay,
                  videoOutput.hasNewPixelBuffer(forItemTime: itemTime) else {
                return
            }
            
            if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                self.currentPixelBuffer = pixelBuffer
                view?.setNeedsDisplay()
            }
        }
        
        // MARK: - MTKViewDelegate
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // 뷰 크기가 변경될 때 필요한 처리를 여기에 추가
        }
        
        func draw(in view: MTKView) {
            guard let pixelBuffer = currentPixelBuffer else { return }
            renderer.render(pixelBuffer: pixelBuffer, in: view)
        }
    }
} 