import SwiftUI
import RealityKit
import RealityKitViewRenderer
import ARKit
import Lottie
import Combine

struct ContentView : View {
  @State var showAnim: Bool = false
  var body: some View {
    ZStack(alignment: .bottom) {
      ARViewContainer(showAnim: $showAnim)
      Button("Add Animation") {
        print("show anim")
        showAnim = true
      }
      .buttonStyle(BorderedProminentButtonStyle())
      .padding(.bottom, 30)
    }
      .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
  class Coordinator: NSObject, ARSessionDelegate {
    var cancellables = Set<AnyCancellable>()
    let lottieView = AnimationView(name: "plant")
    let parent: ARViewContainer
    lazy var drawableTextureManager: DrawableTextureManager = DrawableTextureManager(placeholder: UIColor.red.image())

    init(_ parent: ARViewContainer) {
      self.parent = parent
      lottieView.frame = CGRect(origin: .zero, size: .init(width: 800, height: 800))

      super.init()
      parent.arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
        guard let self = self else { return }
        let totalDuration = self.lottieView.animation!.duration
        let delta = event.deltaTime / totalDuration
        let newTime = self.lottieView.currentProgress + delta

        self.lottieView.currentProgress = newTime < 1 ? newTime : 0
        self.drawableTextureManager.update(with: self.lottieView)
      }
      .store(in: &cancellables)
    }

    func showAnim() {
      let anchor = AnchorEntity(world: [0, 0, -0.5])
      let plane = ModelEntity(mesh: .generatePlane(width: 0.5, height: 0.5), materials: [drawableTextureManager.customMaterial])
      anchor.addChild(plane)
      parent.arView.scene.addAnchor(anchor)
    }
  }

  @Binding var showAnim: Bool
  let arView = ARView()
  func makeUIView(context: Context) -> ARView {
    let configuration = ARWorldTrackingConfiguration()
    arView.session.delegate = context.coordinator
    arView.debugOptions.insert(.showStatistics)
    arView.session.run(configuration)
    return arView
  }

  func updateUIView(_ uiView: ARView, context: Context) {
    if showAnim {
      context.coordinator.showAnim()
    }
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(self)
  }
}

extension UIColor {
    func image(_ size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
