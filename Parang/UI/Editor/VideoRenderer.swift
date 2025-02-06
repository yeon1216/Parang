import MetalKit
import AVFoundation

/// Metal을 사용하여 비디오 프레임을 렌더링하는 클래스
/// AVPlayer로부터 받은 CVPixelBuffer를 Metal 텍스처로 변환하고 화면에 그리는 역할을 담당
class VideoRenderer: NSObject {
    // MARK: - Properties
    
    /// Metal 디바이스 (GPU) 인스턴스
    private let metalDevice: MTLDevice
    
    /// Metal 명령어 대기열
    /// 렌더링 명령을 순차적으로 GPU에 전달
    private let metalCommandQueue: MTLCommandQueue
    
    /// CVPixelBuffer를 Metal 텍스처로 변환하기 위한 캐시
    /// 비디오 프레임을 효율적으로 GPU 메모리에 업로드하는데 사용
    private let textureCache: CVMetalTextureCache
    
    /// 렌더링 파이프라인 상태 객체
    /// 버텍스 및 프래그먼트 셰이더 설정을 포함
    private var renderPipelineState: MTLRenderPipelineState?
    
    /// 화면에 표시될 사각형 메시의 버텍스 버퍼
    private var vertexBuffer: MTLBuffer?
    
    // MARK: - Vertex Structure
    
    /// 각 정점의 데이터를 정의하는 구조체
    private struct Vertex {
        /// 3D 공간의 위치 좌표 (x, y, z, w)
        let position: SIMD4<Float>
        /// 텍스처 매핑 좌표 (u, v)
        let textureCoordinate: SIMD2<Float>
    }
    
    // MARK: - Initialization
    
    override init() {
        // Metal 디바이스와 커맨드 큐 생성
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported")
        }
        
        self.metalDevice = device
        self.metalCommandQueue = commandQueue
        
        // 텍스처 캐시 생성
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
        guard let cache = textureCache else {
            fatalError("Unable to create texture cache")
        }
        self.textureCache = cache
        
        super.init()
        setupRenderPipeline()
        setupVertexBuffer()
    }
    
    /// Metal 렌더링 파이프라인 설정
    /// Shaders.metal 파일의 셰이더 함수들을 로드하고 파이프라인 상태를 구성
    private func setupRenderPipeline() {
        guard let library = metalDevice.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }
        
        // 버텍스와 프래그먼트 셰이더 함수 로드
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        // 렌더링 파이프라인 디스크립터 설정
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 버텍스 디스크립터 설정
        let vertexDescriptor = MTLVertexDescriptor()
        
        // position 속성 설정 (float4)
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // texCoord 속성 설정 (float2)
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // 버텍스 레이아웃 설정
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // 렌더링 파이프라인 상태 생성
        do {
            renderPipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }
    
    /// 화면에 표시될 사각형 메시의 버텍스 버퍼 설정
    private func setupVertexBuffer() {
        // 기본적으로 -1 ~ 1 범위의 정규화된 좌표계를 사용
        var vertices = [
            // 좌하단
            Vertex(position: SIMD4<Float>(-1, -1, 0, 1), textureCoordinate: SIMD2<Float>(0, 1)),
            // 좌상단
            Vertex(position: SIMD4<Float>(-1,  1, 0, 1), textureCoordinate: SIMD2<Float>(0, 0)),
            // 우하단
            Vertex(position: SIMD4<Float>( 1, -1, 0, 1), textureCoordinate: SIMD2<Float>(1, 1)),
            // 우상단
            Vertex(position: SIMD4<Float>( 1,  1, 0, 1), textureCoordinate: SIMD2<Float>(1, 0))
        ]
        
        // 버텍스 데이터를 GPU 메모리에 업로드
        vertexBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )
    }
    
    /// 비디오 프레임을 화면에 렌더링
    /// - Parameters:
    ///   - pixelBuffer: AVPlayer로부터 받은 비디오 프레임
    ///   - view: 렌더링될 Metal 뷰
    func render(pixelBuffer: CVPixelBuffer, in view: MTKView) {
        // 필요한 Metal 객체들이 모두 유효한지 확인
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = metalCommandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = renderPipelineState,
              let vertexBuffer = vertexBuffer else {
            return
        }
        
        // 비디오 프레임의 크기 가져오기
        let videoWidth = Float(CVPixelBufferGetWidth(pixelBuffer))
        let videoHeight = Float(CVPixelBufferGetHeight(pixelBuffer))
        let videoAspect = videoWidth / videoHeight
        
        // 뷰의 크기 가져오기
        let viewWidth = Float(view.drawableSize.width)
        let viewHeight = Float(view.drawableSize.height)
        let viewAspect = viewWidth / viewHeight
        
        // 비디오를 화면에 맞추기 위한 스케일 계산
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        
        if videoAspect > viewAspect {
            // 비디오가 더 와이드한 경우
            scaleY = viewAspect / videoAspect
        } else {
            // 화면이 더 와이드한 경우
            scaleX = videoAspect / viewAspect
        }
        
        // 조정된 버텍스 위치 계산
        let vertices = [
            // 좌하단
            Vertex(position: SIMD4<Float>(-scaleX, -scaleY, 0, 1), textureCoordinate: SIMD2<Float>(0, 1)),
            // 좌상단
            Vertex(position: SIMD4<Float>(-scaleX,  scaleY, 0, 1), textureCoordinate: SIMD2<Float>(0, 0)),
            // 우하단
            Vertex(position: SIMD4<Float>( scaleX, -scaleY, 0, 1), textureCoordinate: SIMD2<Float>(1, 1)),
            // 우상단
            Vertex(position: SIMD4<Float>( scaleX,  scaleY, 0, 1), textureCoordinate: SIMD2<Float>(1, 0))
        ]
        
        // 새로운 버텍스 버퍼 생성
        let newVertexBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )
        
        // CVPixelBuffer를 Metal 텍스처로 변환
        var cvTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        
        // Metal 텍스처 생성 확인
        guard let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to create texture from pixel buffer")
            return
        }
        
        // 렌더링 명령 인코딩
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(newVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // 렌더링 명령을 커밋하고 결과를 화면에 표시
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    /// 비디오 프레임을 화면에 렌더링
    /// - Parameters:
    ///   - pixelBuffer: AVPlayer로부터 받은 비디오 프레임
    ///   - view: 렌더링될 Metal 뷰
    func render(pixelBuffer: CVPixelBuffer, in view: MTKView, orientation: UIInterfaceOrientation) {
        // 필요한 Metal 객체들이 모두 유효한지 확인
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = metalCommandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = renderPipelineState,
              let vertexBuffer = vertexBuffer else {
            return
        }
        
        // 비디오 프레임의 크기 가져오기
        let videoWidth = Float(CVPixelBufferGetWidth(pixelBuffer))
        let videoHeight = Float(CVPixelBufferGetHeight(pixelBuffer))
        let videoAspect = videoWidth / videoHeight
        
        // 뷰의 크기 가져오기
        let viewWidth = Float(view.drawableSize.width)
        let viewHeight = Float(view.drawableSize.height)
        let viewAspect = viewWidth / viewHeight
        
        // 1. orientation에 따른 회전 각도 설정
        let angle: Float = {
            switch orientation {
            case .portrait:
                return 0
            case .portraitUpsideDown:
                return Float.pi
            case .landscapeLeft:
                return Float.pi / 2
            case .landscapeRight:
                return -Float.pi / 2
            default:
                return 0
            }
        }()
        
        // 2. 회전 90°(또는 -90°)인 경우 영상의 가로세로 비율은 역수가 되어야 함
        let effectiveVideoAspect: Float = (abs(angle) == Float.pi/2) ? (1 / videoAspect) : videoAspect
        
        // 3. 뷰에 맞추기 위한 스케일 계산 (letterbox 방식)
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        if effectiveVideoAspect > viewAspect {
            // 영상이 뷰보다 더 와이드한 경우 : 세로 스케일 조정
            scaleY = viewAspect / effectiveVideoAspect
        } else {
            // 뷰가 더 와이드한 경우 : 가로 스케일 조정
            scaleX = effectiveVideoAspect / viewAspect
        }
        
        // 4. 회전 전 원본 버텍스 좌표 계산 (중심이 (0,0)인 정규화 좌표계)
        let rawPositions: [SIMD4<Float>] = [
            SIMD4<Float>(-scaleX, -scaleY, 0, 1), // 좌하단
            SIMD4<Float>(-scaleX,  scaleY, 0, 1), // 좌상단
            SIMD4<Float>( scaleX, -scaleY, 0, 1), // 우하단
            SIMD4<Float>( scaleX,  scaleY, 0, 1)  // 우상단
        ]
        
        // 기존 텍스처 좌표 순서
        let textureCoords: [SIMD2<Float>] = [
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0, 0),
            SIMD2<Float>(1, 1),
            SIMD2<Float>(1, 0)
        ]
        
        // 5. 회전 행렬을 계산하여 각 버텍스 좌표에 적용
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        let rotatedVertices: [Vertex] = zip(rawPositions, textureCoords).map { (pos, tex) in
            let rotatedX = pos.x * cosAngle - pos.y * sinAngle
            let rotatedY = pos.x * sinAngle + pos.y * cosAngle
            return Vertex(position: SIMD4<Float>(rotatedX, rotatedY, pos.z, pos.w), textureCoordinate: tex)
        }
        
        // 6. 새로운 버텍스 버퍼 생성 (회전된 좌표 사용)
        let newVertexBuffer = metalDevice.makeBuffer(
            bytes: rotatedVertices,
            length: rotatedVertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )
        
        // CVPixelBuffer를 Metal 텍스처로 변환
        var cvTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        
        // Metal 텍스처 생성 확인
        guard let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to create texture from pixel buffer")
            return
        }
        
        // 렌더링 명령 인코딩
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(newVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // 렌더링 명령을 커밋하고 결과를 화면에 표시
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
