import RealityKit
import MetalKit

public class DrawableTextureManager {

  lazy var mtlDevice: MTLDevice = {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError()
    }
    return device
  }()

  lazy var library: MTLLibrary = try! mtlDevice.makeDefaultLibrary(bundle: .module)


  public lazy var customMaterial: CustomMaterial = {
    let surfaceShader = CustomMaterial.SurfaceShader(
      named: "customMaterialSurfaceModifier",
      in: library
    )

    do {
      var customMaterial = try CustomMaterial(
        surfaceShader: surfaceShader,
        geometryModifier: nil,
        lightingModel: .unlit
      )
      customMaterial.custom.texture = .init(textureResource)
      customMaterial.faceCulling = .none

      return customMaterial
    } catch {
      fatalError("CustomMaterial could not be created: \(error)")
    }
  }()


  public let textureResource: TextureResource

  public lazy var drawableQueue: TextureResource.DrawableQueue = {
    let descriptor = TextureResource.DrawableQueue.Descriptor(
      pixelFormat: .rgba8Unorm,
      width: 800,
      height: 800,
      usage: [.shaderRead, .shaderWrite, .renderTarget],
      mipmapsMode: .none
    )

    do {
      let queue = try TextureResource.DrawableQueue(descriptor)
      queue.allowsNextDrawableTimeout = true
      return queue
    } catch {
      fatalError("Could not create DrawableQueue: \(error)")
    }
  }()

  private lazy var commandQueue: MTLCommandQueue? = {
    return mtlDevice.makeCommandQueue()
  }()

  private var renderPipelineState: MTLRenderPipelineState?
  private var imagePlaneVertexBuffer: MTLBuffer?
  private lazy var textureLoader = MTKTextureLoader(device: mtlDevice)

  private func initializeRenderPipelineState() {
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm

    let imagePlaneVertexDescriptor = MTLVertexDescriptor()
    imagePlaneVertexDescriptor.attributes[0].format = .float2
    imagePlaneVertexDescriptor.attributes[0].offset = 0
    imagePlaneVertexDescriptor.attributes[0].bufferIndex = 0
    imagePlaneVertexDescriptor.attributes[1].format = .float2
    imagePlaneVertexDescriptor.attributes[1].offset = 8
    imagePlaneVertexDescriptor.attributes[1].bufferIndex = 0
    imagePlaneVertexDescriptor.layouts[0].stride = 16
    imagePlaneVertexDescriptor.layouts[0].stepRate = 1
    imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex

    /**
     *  Vertex function to map the texture to the view controller's view
     */
    //pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
    pipelineDescriptor.vertexFunction = library.makeFunction(
      name: "drawableQueueVertexShader"
    )

    /**
     *  Fragment function to display texture's pixels in the area bounded by vertices of `mapTexture` shader
     */
    pipelineDescriptor.fragmentFunction = library.makeFunction(
      name: "drawableQueueFragmentShader"
    )

    pipelineDescriptor.vertexDescriptor = imagePlaneVertexDescriptor

    do {
      try renderPipelineState = mtlDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    catch {
      assertionFailure("Failed creating a render state pipeline. Can't render the texture without one. Error: \(error)")
      return
    }
  }

  private let planeVertexData: [Float] = [
    -1, -1,  0,  1,
     1, -1,  1,  1,
     -1,  1,  0,  0,
     1,  1,  1,  0
  ]

  public init(placeholder: UIImage) {
    guard let cgImage = placeholder.cgImage,
    let textureResource = try? TextureResource.generate(from: cgImage, withName: nil, options: .init(semantic: .color))
    else {
      fatalError("DrawableTextureManager could not be instantiated")
    }
    self.textureResource = textureResource
    commonInit()
  }


  private func commonInit() {
    textureResource.replace(withDrawables: self.drawableQueue)

    let imagePlaneVertexDataCount = planeVertexData.count * MemoryLayout<Float>.size

    imagePlaneVertexBuffer = mtlDevice.makeBuffer(
      bytes: planeVertexData,
      length: imagePlaneVertexDataCount,
      options: []
    )

    initializeRenderPipelineState()
  }
}

public extension DrawableTextureManager {
  func update(with view: UIView) {

    guard
      let drawable = try? drawableQueue.nextDrawable(),
      let commandBuffer = commandQueue?.makeCommandBuffer(),
      let renderPipelineState = renderPipelineState
    else {
      return
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .load
    renderPassDescriptor.colorAttachments[0].storeAction = .store
    renderPassDescriptor.renderTargetHeight = textureResource.height
    renderPassDescriptor.renderTargetWidth = textureResource.width

  guard let texture = view.takeTextureSnapshot(device: mtlDevice) else { return }
  guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
    // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
    renderEncoder.pushDebugGroup("DrawCapturedImage")
    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
    renderEncoder.setFragmentTexture(texture, index: 0)
    renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    renderEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    drawable.present()
  }
}

extension UIView {
   func takeTextureSnapshot(device: MTLDevice) -> MTLTexture? {
      let width = Int(bounds.width)
      let height = Int(bounds.height)
      if let context = CGContext(data: nil,
                                 width: width,
                                 height: height,
                                 bitsPerComponent: 8,
                                 bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceRGB() ,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue  | CGBitmapInfo.byteOrder32Big.rawValue),
        let data = context.data {

        layer.render(in: context)

        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                            width: width,
                                                            height: height,
                                                            mipmapped: false)
        if let texture = device.makeTexture(descriptor: desc) {
          texture.replace(region: MTLRegionMake2D(0, 0, width, height),
                          mipmapLevel: 0,
                          withBytes: data,
                          bytesPerRow: context.bytesPerRow)
          return texture
        }
      }
      return nil
    }
}
