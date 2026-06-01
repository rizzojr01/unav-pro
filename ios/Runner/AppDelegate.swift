import ARKit
import AVFoundation
import CoreMotion
import Flutter
import UIKit

private enum ArChannelContract {
  static let methodChannel = "unav/tracking/ar_method"
  static let eventChannel = "unav/tracking/ar_pose_stream"
  static let previewViewType = "unav/tracking/ar_preview_view"
  static let startSessionMethod = "startSession"
  static let stopSessionMethod = "stopSession"
  static let getCapabilitiesMethod = "getCapabilities"
  static let captureCurrentFrameMethod = "captureCurrentFrame"
  static let captureCurrentFrameWithPoseMethod = "captureCurrentFrameWithPose"
  static let updateOverlayMethod = "updateOverlay"
  static let clearOverlayMethod = "clearOverlay"
  static let previewModeKey = "mode"
  static let backendKey = "backend"
  static let isSupportedKey = "isSupported"
  static let xKey = "x"
  static let yKey = "y"
  static let zKey = "z"
  static let headingKey = "heading"
  static let confidenceKey = "confidence"
  static let timestampKey = "timestampMillis"
  static let worldXKey = "worldX"
  static let worldYKey = "worldY"
  static let worldZKey = "worldZ"
  static let gravityXKey = "gravityX"
  static let gravityYKey = "gravityY"
  static let gravityZKey = "gravityZ"
  static let interfaceRotationDegKey = "interfaceRotationDeg"
  static let pathPointsKey = "pathPoints"
  static let activePathPointsKey = "activePathPoints"
  static let futurePathPointsKey = "futurePathPoints"
  static let nextWaypointKey = "nextWaypoint"
  static let destinationKey = "destination"
  static let waypointPulsePeriodSecKey = "waypointPulsePeriodSec"
  static let waypointPulseActiveKey = "waypointPulseActive"
  static let jpegBytesKey = "jpegBytes"
  static let capturePreviewMode = "capture"
  static let navigationPreviewMode = "navigation"
}

private enum SpatialAudioChannelContract {
  static let methodChannel = "unav/audio/spatial_method"
  static let getCapabilitiesMethod = "getCapabilities"
  static let playCueMethod = "playCue"
  static let playStereoAssetMethod = "playStereoAsset"
  static let primeOffRouteLoopMethod = "primeOffRouteLoop"
  static let updateOffRouteAlertMethod = "updateOffRouteAlert"
  static let stopOffRouteAlertMethod = "stopOffRouteAlert"
  static let supportsSpatialKey = "supportsSpatial"
  static let supportsStereoPanKey = "supportsStereoPan"
  static let isMonoAudioEnabledKey = "isMonoAudioEnabled"
  static let hasHeadphonesConnectedKey = "hasHeadphonesConnected"
  static let cueTypeKey = "cueType"
  static let assetPathKey = "assetPath"
  static let sideKey = "side"
  static let severityKey = "severity"
  static let headingErrorDegKey = "headingErrorDeg"
  static let relativeAngleDegKey = "relativeAngleDeg"
  static let sourceDistanceMetersKey = "sourceDistanceMeters"
  static let distanceToWaypointMetersKey = "distanceToWaypointMeters"
  static let volumeKey = "volume"
  static let rateKey = "rate"
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let arTrackingBridge = IOSArTrackingBridge()
  private let spatialAudioBridge = IOSSpatialAudioBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    arTrackingBridge.register(with: self.registrar(forPlugin: "UNavArPreview")!)
    spatialAudioBridge.register(with: self.registrar(forPlugin: "UNavSpatialAudio")!)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class IOSArTrackingBridge: NSObject, FlutterStreamHandler, ARSessionDelegate {
  let session = ARSession()

  private let ciContext = CIContext()
  private var eventSink: FlutterEventSink?
  private var isSessionRunning = false
  private var latestFrame: ARFrame?
  private let previewViews = NSHashTable<ARSCNView>.weakObjects()
  private let overlayRootNodeName = "unav_overlay_root"

  override init() {
    super.init()
    session.delegate = self
  }

  func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let methodChannel = FlutterMethodChannel(
      name: ArChannelContract.methodChannel,
      binaryMessenger: messenger
    )
    let eventChannel = FlutterEventChannel(
      name: ArChannelContract.eventChannel,
      binaryMessenger: messenger
    )

    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "bridge_unavailable", message: nil, details: nil))
        return
      }

      switch call.method {
      case ArChannelContract.getCapabilitiesMethod:
        result([
          ArChannelContract.backendKey: "iosArKit",
          ArChannelContract.isSupportedKey: ARWorldTrackingConfiguration.isSupported,
        ])
      case ArChannelContract.startSessionMethod:
        self.startSession(result: result)
      case ArChannelContract.stopSessionMethod:
        self.stopSession()
        result(nil)
      case ArChannelContract.captureCurrentFrameMethod:
        self.captureCurrentFrame(result: result)
      case ArChannelContract.captureCurrentFrameWithPoseMethod:
        self.captureCurrentFrameWithPose(result: result)
      case ArChannelContract.updateOverlayMethod:
        self.updateOverlay(arguments: call.arguments)
        result(nil)
      case ArChannelContract.clearOverlayMethod:
        self.clearOverlay()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    eventChannel.setStreamHandler(self)
    registrar.register(IOSArPreviewFactory(bridge: self), withId: ArChannelContract.previewViewType)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    latestFrame = frame
    guard let eventSink else { return }

    let transform = frame.camera.transform
    let translation = transform.columns.3
    let x = Double(translation.x)
    let y = Double(-translation.z)
    let z = Double(translation.y)
    let heading = yawDegrees(from: transform)
    let gravity = frame.camera.transform.columns.1
    let interfaceRotationDeg = currentInterfaceRotationDegrees()

    eventSink([
      ArChannelContract.xKey: x,
      ArChannelContract.yKey: y,
      ArChannelContract.zKey: z,
      ArChannelContract.headingKey: heading,
      ArChannelContract.confidenceKey: confidenceValue(for: frame.camera.trackingState),
      ArChannelContract.timestampKey: Int(Date().timeIntervalSince1970 * 1000.0),
      ArChannelContract.worldXKey: Double(translation.x),
      ArChannelContract.worldYKey: Double(translation.y),
      ArChannelContract.worldZKey: Double(translation.z),
      ArChannelContract.gravityXKey: Double(gravity.x),
      ArChannelContract.gravityYKey: Double(gravity.y),
      ArChannelContract.gravityZKey: Double(gravity.z),
      ArChannelContract.interfaceRotationDegKey: interfaceRotationDeg,
    ])
  }

  private func startSession(result: FlutterResult) {
    guard ARWorldTrackingConfiguration.isSupported else {
      result(
        FlutterError(
          code: "arkit_unsupported",
          message: "ARKit world tracking is unavailable on this device.",
          details: nil
        )
      )
      return
    }

    let configuration = ARWorldTrackingConfiguration()
    // Use .gravity (not .gravityAndHeading) so the AR world frame is
    // session-relative, matching ar_temp. The Flutter transformer bridges
    // the session frame to floorplan space using
    // sumHeadingDeg = reference.heading + captureHeading, which works for
    // any floorplan orientation and avoids compass/magnetometer interference.
    configuration.worldAlignment = .gravity
    session.run(configuration, options: isSessionRunning ? [] : [.resetTracking, .removeExistingAnchors])
    isSessionRunning = true
    resumePreviewViews()
    result(nil)
  }

  private func stopSession() {
    guard isSessionRunning else { return }
    clearOverlay()
    session.pause()
    isSessionRunning = false
  }

  private func captureCurrentFrame(result: FlutterResult) {
    guard let frame = latestFrame else {
      result(
        FlutterError(
          code: "frame_unavailable",
          message: "No AR frame available for relocalization.",
          details: nil
        )
      )
      return
    }

    let image = CIImage(cvPixelBuffer: frame.capturedImage)
    guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
      result(
        FlutterError(
          code: "frame_conversion_failed",
          message: "Unable to convert AR frame to image.",
          details: nil
        )
      )
      return
    }

    let orientation = uiImageOrientation(for: currentInterfaceOrientation())
    let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    guard let jpegData = uiImage.jpegData(compressionQuality: 0.95) else {
      result(
        FlutterError(
          code: "frame_encoding_failed",
          message: "Unable to encode AR frame as JPEG.",
          details: nil
        )
      )
      return
    }

    result(FlutterStandardTypedData(bytes: jpegData))
  }

  private func captureCurrentFrameWithPose(result: FlutterResult) {
    // Extract JPEG bytes AND the pose from the same ARFrame so the
    // capture moment's pose is guaranteed contemporaneous with the image.
    guard let frame = latestFrame else {
      result(
        FlutterError(
          code: "frame_unavailable",
          message: "No AR frame available.",
          details: nil
        )
      )
      return
    }

    let image = CIImage(cvPixelBuffer: frame.capturedImage)
    guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
      result(
        FlutterError(
          code: "frame_conversion_failed",
          message: "Unable to convert AR frame to image.",
          details: nil
        )
      )
      return
    }

    let orientation = uiImageOrientation(for: currentInterfaceOrientation())
    let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    guard let jpegData = uiImage.jpegData(compressionQuality: 0.95) else {
      result(
        FlutterError(
          code: "frame_encoding_failed",
          message: "Unable to encode AR frame as JPEG.",
          details: nil
        )
      )
      return
    }

    let transform = frame.camera.transform
    let translation = transform.columns.3
    let x = Double(translation.x)
    let y = Double(-translation.z)
    let z = Double(translation.y)
    let heading = yawDegrees(from: transform)
    let confidence = confidenceValue(for: frame.camera.trackingState)

    let response: [String: Any] = [
      ArChannelContract.jpegBytesKey: FlutterStandardTypedData(bytes: jpegData),
      ArChannelContract.xKey: x,
      ArChannelContract.yKey: y,
      ArChannelContract.zKey: z,
      ArChannelContract.headingKey: heading,
      ArChannelContract.confidenceKey: confidence,
      ArChannelContract.timestampKey: Int(Date().timeIntervalSince1970 * 1000.0),
      ArChannelContract.worldXKey: Double(translation.x),
      ArChannelContract.worldYKey: Double(translation.y),
      ArChannelContract.worldZKey: Double(translation.z),
    ]
    result(response)
  }

  private func yawDegrees(from transform: simd_float4x4) -> Double {
    let cameraForward = SIMD3<Float>(
      -transform.columns.2.x,
      -transform.columns.2.y,
      -transform.columns.2.z
    )
    let planarX = Double(cameraForward.x)
    let planarY = Double(-cameraForward.z)
    let heading = atan2(planarY, planarX) * 180.0 / .pi
    return normalizedDegrees(heading)
  }

  private func normalizedDegrees(_ value: Double) -> Double {
    var normalized = value.truncatingRemainder(dividingBy: 360.0)
    if normalized < 0 {
      normalized += 360.0
    }
    return normalized
  }

  private func confidenceValue(for trackingState: ARCamera.TrackingState) -> Double {
    switch trackingState {
    case .normal:
      return 1.0
    case .limited:
      return 0.5
    case .notAvailable:
      return 0.0
    }
  }

  private func currentInterfaceRotationDegrees() -> Double {
    switch currentInterfaceOrientation() {
    case .portrait:
      return 0
    case .landscapeLeft:
      return 90
    case .landscapeRight:
      return -90
    case .portraitUpsideDown:
      return 180
    default:
      return 0
    }
  }

  private func currentInterfaceOrientation() -> UIInterfaceOrientation {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?
        .interfaceOrientation ?? .portrait
    }
    return UIApplication.shared.statusBarOrientation
  }

  private func uiImageOrientation(for orientation: UIInterfaceOrientation) -> UIImage.Orientation {
    switch orientation {
    case .portrait:
      return .right
    case .landscapeLeft:
      return .up
    case .landscapeRight:
      return .down
    case .portraitUpsideDown:
      return .left
    default:
      return .right
    }
  }

  func attachPreviewView(_ sceneView: ARSCNView, mode: String) {
    detachOtherPreviewViews(keeping: sceneView)
    previewViews.add(sceneView)
    sceneView.session = session
    sceneView.rendersContinuously = true
    sceneView.isPlaying = true
    _ = overlayRoot(in: sceneView)

    if mode == ArChannelContract.capturePreviewMode {
      clearOverlay(in: sceneView)
    }
  }

  func detachPreviewView(_ sceneView: ARSCNView) {
    clearOverlay(in: sceneView)
    sceneView.isPlaying = false
    sceneView.session = ARSession()
    previewViews.remove(sceneView)
  }

  private func detachOtherPreviewViews(keeping activeSceneView: ARSCNView) {
    previewViews.allObjects
      .filter { $0 !== activeSceneView }
      .forEach { detachPreviewView($0) }
  }

  private func resumePreviewViews() {
    previewViews.allObjects.forEach { sceneView in
      sceneView.session = session
      sceneView.rendersContinuously = true
      sceneView.isPlaying = true
    }
  }

  private func clearOverlay() {
    previewViews.allObjects.forEach { clearOverlay(in: $0) }
  }

  private func clearOverlay(in sceneView: ARSCNView) {
    let overlayRoots = sceneView.scene.rootNode.childNodes.filter { $0.name == overlayRootNodeName }
    for (index, overlayRoot) in overlayRoots.enumerated() {
      if index == 0 {
        overlayRoot.childNodes.forEach { $0.removeFromParentNode() }
      } else {
        overlayRoot.removeFromParentNode()
      }
    }
  }

  private func overlayRoot(in sceneView: ARSCNView) -> SCNNode {
    let overlayRoots = sceneView.scene.rootNode.childNodes.filter { $0.name == overlayRootNodeName }
    let overlayRoot = overlayRoots.first ?? SCNNode()
    overlayRoot.name = overlayRootNodeName

    if overlayRoot.parent == nil {
      sceneView.scene.rootNode.addChildNode(overlayRoot)
    }

    overlayRoots.dropFirst().forEach { $0.removeFromParentNode() }
    return overlayRoot
  }

  private func updateOverlay(arguments: Any?) {
    guard
      let args = arguments as? [String: Any]
    else {
      clearOverlay()
      return
    }

    let activePathPoints =
      (args[ArChannelContract.activePathPointsKey] as? [[Double]] ?? [])
      .compactMap { point(from: $0) }
    let futurePathPoints =
      (args[ArChannelContract.futurePathPointsKey] as? [[Double]] ?? [])
      .compactMap { point(from: $0) }
    let pulsePeriod =
      (args[ArChannelContract.waypointPulsePeriodSecKey] as? NSNumber)?.doubleValue ?? 1.0
    let pulseActive = args[ArChannelContract.waypointPulseActiveKey] as? Bool ?? false
    let nextWaypointPoint = (args[ArChannelContract.nextWaypointKey] as? [Double]).flatMap {
      point(from: $0)
    }
    let destinationPoint = (args[ArChannelContract.destinationKey] as? [Double]).flatMap {
      point(from: $0)
    }

    previewViews.allObjects.forEach { sceneView in
      let overlayRootNode = overlayRoot(in: sceneView)
      overlayRootNode.childNodes.forEach { $0.removeFromParentNode() }

      if futurePathPoints.count >= 2 {
        for index in 0..<(futurePathPoints.count - 1) {
          let segment = buildPathSegmentNode(
            from: futurePathPoints[index],
            to: futurePathPoints[index + 1],
            radius: 0.026,
            color: UIColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 1.0),
            opacity: 0.74
          )
          overlayRootNode.addChildNode(segment)
        }
      }

      if activePathPoints.count >= 2 {
        for index in 0..<(activePathPoints.count - 1) {
          let segment = buildPathSegmentNode(
            from: activePathPoints[index],
            to: activePathPoints[index + 1],
            radius: 0.04,
            color: UIColor.systemTeal,
            opacity: 1.0
          )
          overlayRootNode.addChildNode(segment)
        }
        overlayRootNode.addChildNode(
          buildFlowBeamNode(
            from: activePathPoints[0],
            to: activePathPoints[1],
            color: UIColor.systemTeal
          )
        )
      }

      if let nextWaypointPoint {
        overlayRootNode.addChildNode(
          buildMarkerNode(
            at: nextWaypointPoint,
            radius: 0.08,
            color: UIColor.systemTeal,
            pulsePeriod: pulsePeriod,
            pulseActive: pulseActive
          )
        )
      }

      if let destinationPoint {
        overlayRootNode.addChildNode(
          buildWaypointRingNode(
            at: destinationPoint,
            radius: 0.28,
            color: UIColor.systemOrange
          )
        )
        overlayRootNode.addChildNode(
          buildMarkerNode(
            at: destinationPoint,
            radius: 0.11,
            color: UIColor.systemOrange
          )
        )
      }
    }
  }

  private func point(from array: [Double]) -> SCNVector3? {
    guard array.count >= 3 else { return nil }
    return SCNVector3(Float(array[0]), Float(array[1]), Float(array[2]))
  }

  private func buildMarkerNode(
    at point: SCNVector3,
    radius: CGFloat,
    color: UIColor,
    pulsePeriod: TimeInterval? = nil,
    pulseActive: Bool = false
  ) -> SCNNode {
    let sphere = SCNSphere(radius: radius)
    sphere.firstMaterial?.diffuse.contents = color
    sphere.firstMaterial?.emission.contents = color.withAlphaComponent(0.35)

    let node = SCNNode(geometry: sphere)
    node.position = SCNVector3(point.x, point.y + Float(radius), point.z)
    if pulseActive, let pulsePeriod {
      applyHeartbeatAppearance(
        to: node,
        color: color,
        period: pulsePeriod
      )
    }
    return node
  }

  private func applyHeartbeatAppearance(
    to node: SCNNode,
    color: UIColor,
    period: TimeInterval
  ) {
    let clampedPeriod = max(0.28, min(2.2, period))
    let time = CACurrentMediaTime().truncatingRemainder(dividingBy: clampedPeriod)
    let phase = time / clampedPeriod

    let pulse: Double
    if phase < 0.18 {
      pulse = phase / 0.18
    } else if phase < 0.5 {
      let local = (phase - 0.18) / 0.32
      pulse = 1.0 - (local * 0.85)
    } else {
      let local = (phase - 0.5) / 0.5
      pulse = 0.15 * (1.0 - local)
    }

    let scale = Float(1.0 + (0.32 * pulse))
    node.scale = SCNVector3(scale, scale, scale)
    node.opacity = CGFloat(0.82 + (0.18 * pulse))

    if let material = node.geometry?.firstMaterial {
      material.emission.contents = color.withAlphaComponent(CGFloat(0.22 + (0.68 * pulse)))
      material.diffuse.contents = color.withAlphaComponent(CGFloat(0.84 + (0.16 * pulse)))
    }
  }

  private func buildWaypointRingNode(
    at point: SCNVector3,
    radius: CGFloat,
    color: UIColor
  ) -> SCNNode {
    let ring = SCNTorus(ringRadius: radius, pipeRadius: max(0.012, radius * 0.12))
    ring.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.9)
    ring.firstMaterial?.emission.contents = color.withAlphaComponent(0.28)

    let node = SCNNode(geometry: ring)
    node.position = SCNVector3(point.x, point.y + 0.015, point.z)
    node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
    return node
  }

  private func buildFlowBeamNode(
    from start: SCNVector3,
    to end: SCNVector3,
    color: UIColor
  ) -> SCNNode {
    let container = SCNNode()
    let arrowCount = 3

    for index in 0..<arrowCount {
      let cone = SCNCone(topRadius: 0.0, bottomRadius: 0.045, height: 0.11)
      cone.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.95)
      cone.firstMaterial?.emission.contents = color.withAlphaComponent(0.45)

      let arrow = SCNNode(geometry: cone)
      arrow.opacity = 0.0
      arrow.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
      container.addChildNode(arrow)

      let delay = Double(index) * 0.28
      let action = arrowFlowAction(
        from: start,
        to: end,
        delay: delay
      )
      arrow.runAction(action)
    }

    return container
  }

  private func arrowFlowAction(
    from start: SCNVector3,
    to end: SCNVector3,
    delay: TimeInterval
  ) -> SCNAction {
    let liftedStart = SCNVector3(start.x, start.y + 0.09, start.z)
    let liftedEnd = SCNVector3(end.x, end.y + 0.09, end.z)
    let mid = SCNVector3(
      (liftedStart.x + liftedEnd.x) / 2.0,
      (liftedStart.y + liftedEnd.y) / 2.0,
      (liftedStart.z + liftedEnd.z) / 2.0
    )

    let orient = SCNAction.run { node in
      node.position = liftedStart
      node.look(at: liftedEnd)
      node.eulerAngles.x += Float.pi / 2
    }
    let fadeIn = SCNAction.fadeOpacity(to: 0.95, duration: 0.12)
    let moveToMid = SCNAction.move(to: mid, duration: 0.42)
    let moveToEnd = SCNAction.move(to: liftedEnd, duration: 0.42)
    let fadeOut = SCNAction.fadeOut(duration: 0.16)
    let reset = SCNAction.run { node in
      node.opacity = 0.0
      node.position = liftedStart
    }
    let sequence = SCNAction.sequence([
      .wait(duration: delay),
      orient,
      .group([fadeIn, moveToMid]),
      .group([moveToEnd, fadeOut]),
      .wait(duration: 0.12),
      reset,
    ])

    return .repeatForever(sequence)
  }

  private func buildPathSegmentNode(
    from start: SCNVector3,
    to end: SCNVector3,
    radius: CGFloat,
    color: UIColor,
    opacity: CGFloat
  ) -> SCNNode {
    let liftedStart = SCNVector3(start.x, start.y + 0.03, start.z)
    let liftedEnd = SCNVector3(end.x, end.y + 0.03, end.z)
    let dx = liftedEnd.x - liftedStart.x
    let dy = liftedEnd.y - liftedStart.y
    let dz = liftedEnd.z - liftedStart.z
    let length = sqrt((dx * dx) + (dy * dy) + (dz * dz))
    let cylinder = SCNCylinder(radius: radius, height: CGFloat(length))
    cylinder.firstMaterial?.lightingModel = .constant
    cylinder.firstMaterial?.isDoubleSided = true
    cylinder.firstMaterial?.diffuse.contents = color.withAlphaComponent(opacity)
    cylinder.firstMaterial?.emission.contents = color.withAlphaComponent(min(1.0, opacity * 0.55))

    let node = SCNNode(geometry: cylinder)
    node.position = SCNVector3(
      (liftedStart.x + liftedEnd.x) / 2.0,
      (liftedStart.y + liftedEnd.y) / 2.0,
      (liftedStart.z + liftedEnd.z) / 2.0
    )
    node.eulerAngles = eulerAnglesForCylinder(from: liftedStart, to: liftedEnd)
    return node
  }

  private func eulerAnglesForCylinder(from start: SCNVector3, to end: SCNVector3) -> SCNVector3 {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let dz = end.z - start.z
    let horizontal = sqrt((dx * dx) + (dz * dz))
    let pitch = Float.pi / 2 - atan2(dy, horizontal)
    let yaw = atan2(dx, dz)
    return SCNVector3(pitch, yaw, 0)
  }
}

private final class IOSArPreviewFactory: NSObject, FlutterPlatformViewFactory {
  private let bridge: IOSArTrackingBridge

  init(bridge: IOSArTrackingBridge) {
    self.bridge = bridge
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any]
    let mode = params?[ArChannelContract.previewModeKey] as? String
      ?? ArChannelContract.navigationPreviewMode
    return IOSArPreviewPlatformView(frame: frame, bridge: bridge, mode: mode)
  }
}

private final class IOSArPreviewPlatformView: NSObject, FlutterPlatformView {
  private let sceneView: ARSCNView
  private weak var bridge: IOSArTrackingBridge?

  init(frame: CGRect, bridge: IOSArTrackingBridge, mode: String) {
    self.bridge = bridge
    sceneView = ARSCNView(frame: frame)
    super.init()

    sceneView.automaticallyUpdatesLighting = false
    sceneView.rendersContinuously = true
    sceneView.backgroundColor = .black
    sceneView.scene = SCNScene()
    sceneView.session = bridge.session
    bridge.attachPreviewView(sceneView, mode: mode)
  }

  deinit {
    bridge?.detachPreviewView(sceneView)
  }

  func view() -> UIView {
    sceneView
  }
}

private final class IOSSpatialAudioBridge: NSObject {
  private let engine = AVAudioEngine()
  private let environmentNode = AVAudioEnvironmentNode()
  private let eventPlayer = AVAudioPlayerNode()
  private let offRoutePlayer = AVAudioPlayerNode()
  private var spatialInputFormat: AVAudioFormat?
  private var stereoPlayer: AVAudioPlayer?
  private var lookupAssetKey: ((String) -> String)?
  private var offRouteSide = "center"
  private var offRouteSeverity = 0.0
  private var offRouteHeadingErrorDeg = 180.0
  private var relativeAngleDeg = 0.0
  private var sourceDistanceMeters = 2.0
  private var distanceToWaypointMeters = 6.0
  private var offRoutePulseTimer: Timer?
  private var isInitialized = false

  func register(with registrar: FlutterPluginRegistrar) {
    lookupAssetKey = { asset in
      registrar.lookupKey(forAsset: asset)
    }

    let methodChannel = FlutterMethodChannel(
      name: SpatialAudioChannelContract.methodChannel,
      binaryMessenger: registrar.messenger()
    )

    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "spatial_bridge_unavailable", message: nil, details: nil))
        return
      }

      switch call.method {
      case SpatialAudioChannelContract.getCapabilitiesMethod:
        result([
          SpatialAudioChannelContract.supportsSpatialKey: canUseSpatialAudio(),
          SpatialAudioChannelContract.supportsStereoPanKey: true,
          SpatialAudioChannelContract.isMonoAudioEnabledKey: UIAccessibility.isMonoAudioEnabled,
          SpatialAudioChannelContract.hasHeadphonesConnectedKey: hasHeadphonesConnected(),
        ])
      case SpatialAudioChannelContract.playCueMethod:
        let args = call.arguments as? [String: Any]
        let cueType = args?[SpatialAudioChannelContract.cueTypeKey] as? String ?? ""
        self.playCue(type: cueType)
        result(nil)
      case SpatialAudioChannelContract.playStereoAssetMethod:
        let args = call.arguments as? [String: Any] ?? [:]
        let assetPath = args[SpatialAudioChannelContract.assetPathKey] as? String ?? ""
        let volume = (args[SpatialAudioChannelContract.volumeKey] as? NSNumber)?.floatValue ?? 0.25
        let rate = (args[SpatialAudioChannelContract.rateKey] as? NSNumber)?.floatValue ?? 1.0
        self.playStereoAsset(assetPath, volume: volume, rate: rate)
        result(nil)
      case SpatialAudioChannelContract.updateOffRouteAlertMethod:
        let args = call.arguments as? [String: Any] ?? [:]
        let side = args[SpatialAudioChannelContract.sideKey] as? String ?? "center"
        let severity = (args[SpatialAudioChannelContract.severityKey] as? NSNumber)?.doubleValue ?? 0
        let headingErrorDeg =
          (args[SpatialAudioChannelContract.headingErrorDegKey] as? NSNumber)?.doubleValue ?? 180
        let relativeAngleDeg =
          (args[SpatialAudioChannelContract.relativeAngleDegKey] as? NSNumber)?.doubleValue ?? 0
        let sourceDistanceMeters =
          (args[SpatialAudioChannelContract.sourceDistanceMetersKey] as? NSNumber)?.doubleValue ?? 2
        let distanceToWaypointMeters =
          (args[SpatialAudioChannelContract.distanceToWaypointMetersKey] as? NSNumber)?.doubleValue ?? 6
        self.updateOffRouteAlert(
          side: side,
          severity: severity,
          headingErrorDeg: headingErrorDeg,
          relativeAngleDeg: relativeAngleDeg,
          sourceDistanceMeters: sourceDistanceMeters,
          distanceToWaypointMeters: distanceToWaypointMeters
        )
        result(nil)
      case SpatialAudioChannelContract.primeOffRouteLoopMethod:
        try? self.ensureInitialized()
        result(nil)
      case SpatialAudioChannelContract.stopOffRouteAlertMethod:
        self.stopOffRouteAlert()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func ensureInitialized() throws {
    guard !isInitialized else { return }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playback,
      mode: .default,
      options: [.mixWithOthers]
    )
    try session.setPreferredSampleRate(48_000)
    try session.setActive(true)

    let outputFormat = engine.outputNode.inputFormat(forBus: 0)
    let inputFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: outputFormat.sampleRate,
      channels: 1,
      interleaved: false
    )!
    spatialInputFormat = inputFormat

    engine.attach(environmentNode)
    engine.attach(eventPlayer)
    engine.attach(offRoutePlayer)

    engine.connect(eventPlayer, to: environmentNode, format: inputFormat)
    engine.connect(offRoutePlayer, to: environmentNode, format: inputFormat)
    engine.connect(environmentNode, to: engine.mainMixerNode, format: outputFormat)

    eventPlayer.renderingAlgorithm = .HRTFHQ
    offRoutePlayer.renderingAlgorithm = .HRTFHQ
    eventPlayer.reverbBlend = 10
    offRoutePlayer.reverbBlend = 42
    environmentNode.outputVolume = 1.0
    environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
    environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(
      yaw: 0,
      pitch: 0,
      roll: 0
    )

    engine.prepare()
    try engine.start()
    isInitialized = true
  }

  private func playCue(type: String) {
    try? ensureInitialized()

    switch type {
    case "waypointAdvanced":
      playEventAsset("assets/sounds/waypoint_pass.wav", position: AVAudio3DPoint(x: 0, y: 0, z: -1.2))
    case "waypointRegressed":
      playEventAsset("assets/sounds/waypoint_error.wav", position: AVAudio3DPoint(x: 0, y: 0, z: -1.0))
    case "arrived":
      playEventAsset("assets/sounds/waypoint_pass.wav", position: AVAudio3DPoint(x: 0, y: 0, z: -0.9))
    case "turnNow":
      playEventAsset("assets/sounds/offroute_chime.wav", position: AVAudio3DPoint(x: 0, y: 0, z: -1.0))
    default:
      break
    }
  }

  private func updateOffRouteAlert(
    side: String,
    severity: Double,
    headingErrorDeg: Double,
    relativeAngleDeg: Double,
    sourceDistanceMeters: Double,
    distanceToWaypointMeters: Double
  ) {
    try? ensureInitialized()
    offRouteSide = side
    offRouteSeverity = severity
    offRouteHeadingErrorDeg = headingErrorDeg
    self.relativeAngleDeg = relativeAngleDeg
    self.sourceDistanceMeters = sourceDistanceMeters
    self.distanceToWaypointMeters = distanceToWaypointMeters
    ensureOffRoutePulseRunning()
  }

  private func stopOffRouteAlert() {
    offRouteSeverity = 0
    offRouteHeadingErrorDeg = 180
    relativeAngleDeg = 0
    offRoutePulseTimer?.invalidate()
    offRoutePulseTimer = nil
    stereoPlayer?.stop()
    offRoutePlayer.volume = 0
    offRoutePlayer.stop()
  }

  private func playStereoAsset(_ asset: String, volume: Float, rate: Float) {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(
      .playback,
      mode: .default,
      options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
    )
    try? session.setActive(true)

    guard let url = resolvedAssetURL(for: asset) else { return }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = volume
      player.enableRate = true
      player.rate = max(0.5, min(2.0, rate))
      player.prepareToPlay()
      player.play()
      stereoPlayer = player
    } catch {
      return
    }
  }

  private func canUseSpatialAudio() -> Bool {
    !UIAccessibility.isMonoAudioEnabled && hasHeadphonesConnected()
  }

  private func hasHeadphonesConnected() -> Bool {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    return outputs.contains { output in
      switch output.portType {
      case .headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
        return true
      default:
        return false
      }
    }
  }

  private func ensureOffRoutePulseRunning() {
    if offRoutePulseTimer != nil {
      return
    }

    playOffRoutePulse()
  }

  private func continuousBeaconAsset() -> String {
    if offRouteHeadingErrorDeg < 18 {
      return "assets/sounds/offroute_chime.wav"
    }

    return "assets/sounds/offroute_drum.wav"
  }

  private func directionalPosition(
    relativeAngleDeg: Double,
    distanceMeters: Double
  ) -> AVAudio3DPoint {
    let normalizedAngleDeg = ((relativeAngleDeg + 180).truncatingRemainder(dividingBy: 360)) - 180
    let theta = normalizedAngleDeg * .pi / 180.0
    let distance = max(0.8, min(6.0, distanceMeters))
    let x = Float(sin(theta) * distance)
    let z = Float(-cos(theta) * distance)

    return AVAudio3DPoint(x: x, y: 0.0, z: z)
  }

  private func playOffRoutePulse() {
    guard abs(offRouteHeadingErrorDeg) <= 180 else {
      offRoutePulseTimer?.invalidate()
      offRoutePulseTimer = nil
      offRoutePlayer.stop()
      return
    }

    let asset = continuousBeaconAsset()
    let effectiveSourceDistance = min(sourceDistanceMeters, distanceToWaypointMeters, 6.0)
    let position = directionalPosition(
      relativeAngleDeg: relativeAngleDeg,
      distanceMeters: effectiveSourceDistance
    )
    let volume = Float(lerp(0.22, 0.56, offRouteSeverity))

    playAsset(asset, on: offRoutePlayer, position: position, volume: volume)

    let nextInterval = guidancePulseInterval(headingErrorDeg: offRouteHeadingErrorDeg)
    offRoutePulseTimer?.invalidate()
    offRoutePulseTimer = Timer.scheduledTimer(withTimeInterval: nextInterval, repeats: false) {
      [weak self] _ in
      self?.playOffRoutePulse()
    }
  }

  private func guidancePulseInterval(headingErrorDeg: Double) -> TimeInterval {
    let minFrequencyHz = 0.5
    let maxHeadingFrequencyHz = 2.0
    let maxDistanceFrequencyHz = 3.4
    let normalizedAngle = max(0.0, min(1.0, abs(headingErrorDeg) / 180.0))
    let headingFrequencyHz =
      minFrequencyHz + ((maxHeadingFrequencyHz - minFrequencyHz) * normalizedAngle)
    let normalizedDistance =
      max(0.0, min(1.0, (6.0 - distanceToWaypointMeters) / (6.0 - 0.8)))
    let distanceFrequencyHz =
      minFrequencyHz + ((maxDistanceFrequencyHz - minFrequencyHz) * normalizedDistance)
    let frequencyHz = max(headingFrequencyHz, distanceFrequencyHz)
    return 1.0 / frequencyHz
  }

  private func playEventAsset(_ asset: String, position: AVAudio3DPoint) {
    playAsset(
      asset,
      on: eventPlayer,
      position: position,
      volume: 0.95
    )
  }

  private func playAsset(
    _ asset: String,
    on player: AVAudioPlayerNode,
    position: AVAudio3DPoint,
    volume: Float
  ) {
    guard
      let file = audioFile(for: asset),
      let targetFormat = spatialInputFormat,
      let buffer = convertedPCMBuffer(from: file, to: targetFormat)
    else { return }

    player.stop()
    player.position = position
    player.volume = volume
    player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    player.play()
  }

  private func convertedPCMBuffer(
    from file: AVAudioFile,
    to targetFormat: AVAudioFormat
  ) -> AVAudioPCMBuffer? {
    let sourceFormat = file.processingFormat
    let sourceFrameCount = AVAudioFrameCount(file.length)

    guard
      let sourceBuffer = AVAudioPCMBuffer(
        pcmFormat: sourceFormat,
        frameCapacity: sourceFrameCount
      )
    else { return nil }

    do {
      try file.read(into: sourceBuffer)
    } catch {
      return nil
    }

    if sourceFormat.channelCount == targetFormat.channelCount &&
      sourceFormat.sampleRate == targetFormat.sampleRate &&
      sourceFormat.commonFormat == targetFormat.commonFormat &&
      sourceFormat.isInterleaved == targetFormat.isInterleaved {
      return sourceBuffer
    }

    guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
      return nil
    }

    let sampleRateRatio = targetFormat.sampleRate / sourceFormat.sampleRate
    let estimatedFrameCapacity = AVAudioFrameCount(
      ceil(Double(sourceBuffer.frameLength) * sampleRateRatio)
    ) + 32

    guard let convertedBuffer = AVAudioPCMBuffer(
      pcmFormat: targetFormat,
      frameCapacity: estimatedFrameCapacity
    ) else { return nil }

    var error: NSError?
    var consumedSource = false
    let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
      if consumedSource {
        outStatus.pointee = .endOfStream
        return nil
      }
      consumedSource = true
      outStatus.pointee = .haveData
      return sourceBuffer
    }

    guard status != .error, error == nil else {
      return nil
    }

    return convertedBuffer
  }

  private func audioFile(for asset: String) -> AVAudioFile? {
    guard let url = resolvedAssetURL(for: asset) else { return nil }
    return try? AVAudioFile(forReading: url)
  }

  private func resolvedAssetURL(for asset: String) -> URL? {
    if let key = lookupAssetKey?(asset) {
      if let resourceURL = Bundle.main.resourceURL {
        let candidate = resourceURL.appendingPathComponent(key)
        if FileManager.default.fileExists(atPath: candidate.path) {
          return candidate
        }
      }
      if let bundleURL = Bundle.main.bundleURL as URL? {
        let candidate = bundleURL.appendingPathComponent(key)
        if FileManager.default.fileExists(atPath: candidate.path) {
          return candidate
        }
      }
    }

    if let frameworksURL = Bundle.main.privateFrameworksURL {
      let candidate = frameworksURL
        .appendingPathComponent("App.framework")
        .appendingPathComponent("flutter_assets")
        .appendingPathComponent(asset)
      if FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
      }
    }

    if let resourceURL = Bundle.main.resourceURL {
      let enumerator = FileManager.default.enumerator(
        at: resourceURL,
        includingPropertiesForKeys: nil
      )
      let fileName = URL(fileURLWithPath: asset).lastPathComponent
      while let candidate = enumerator?.nextObject() as? URL {
        if candidate.lastPathComponent == fileName {
          return candidate
        }
      }
    }

    return nil
  }

  private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + ((b - a) * t)
  }
}
