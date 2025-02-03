import MetalKit
import AVFoundation

class VideoRenderer: NSObject {
    private let metalDevice: MTLDevice
    private let metalCommandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache
    private var renderPipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    
    private struct Vertex {
        let position: SIMD4<Float>
        let textureCoordinate: SIMD2<Float>
    }
    
    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported")
        }
        
        self.metalDevice = device
        self.metalCommandQueue = commandQueue
        
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
    
    private func setupRenderPipeline() {
        guard let library = metalDevice.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }
        
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let vertexDescriptor = MTLVertexDescriptor()
        
        // position
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // texCoord
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }
    
    private func setupVertexBuffer() {
        let vertices = [
            Vertex(position: SIMD4<Float>(-1, -1, 0, 1), textureCoordinate: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD4<Float>(-1,  1, 0, 1), textureCoordinate: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD4<Float>( 1, -1, 0, 1), textureCoordinate: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD4<Float>( 1,  1, 0, 1), textureCoordinate: SIMD2<Float>(1, 0))
        ]
        
        vertexBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )
    }
    
    func render(pixelBuffer: CVPixelBuffer, in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = metalCommandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = renderPipelineState,
              let vertexBuffer = vertexBuffer else {
            return
        }
        
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
        
        guard let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to create texture from pixel buffer")
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
} 