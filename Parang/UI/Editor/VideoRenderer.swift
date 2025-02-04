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
        // 전체 화면을 덮는 사각형 메시 정의
        let vertices = [
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
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // 렌더링 명령을 커밋하고 결과를 화면에 표시
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
} 