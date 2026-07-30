import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    window?.backgroundColor = .clear
    
    let controller = window?.rootViewController as! FlutterViewController
    let factory = TransparentVideoPlayerFactory(messenger: controller.binaryMessenger)
    let registrar = controller.registrar(forPlugin: "transparent_video_player")!
    registrar.register(factory, withId: "transparent_video_player")
    
    GeneratedPluginRegistrant.register(with: controller)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class TransparentVideoPlayerView: NSObject, FlutterPlatformView {
  private let playerLayer: AVPlayerLayer
  private let containerView: UIView

  init(frame: CGRect, viewId: Int64, args: [String: Any]?) {
    self.playerLayer = AVPlayerLayer()
    self.containerView = UIView(frame: frame)
    super.init()

    containerView.backgroundColor = .clear
    containerView.isOpaque = false

    playerLayer.frame = frame
    playerLayer.videoGravity = .resizeAspect
    playerLayer.backgroundColor = UIColor.clear.cgColor
    containerView.layer.addSublayer(playerLayer)

    if let path = args?["path"] as? String,
       let url = URL(string: path) {
      let player = AVPlayer(url: url)
      playerLayer.player = player
      player.actionAtItemEnd = .none
      player.play()

      NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: player.currentItem,
        queue: .main
      ) { [weak player] _ in
        player?.seek(to: .zero)
        player?.play()
      }
    }
  }

  func view() -> UIView {
    return containerView
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

class TransparentVideoPlayerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withViewId viewId: Int64,
    args: Any?,
    context: FlutterPlatformViewCreationContext?
  ) -> FlutterPlatformView {
    let frame = CGRect(x: 0, y: 0, width: 420, height: 420)
    let argsMap = args as? [String: Any]
    return TransparentVideoPlayerView(frame: frame, viewId: viewId, args: argsMap)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}