import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "transparent_video_player") {
      let factory = TransparentVideoPlayerFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "transparent_video_player")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class TransparentVideoPlayerView: NSObject, FlutterPlatformView {
  private let playerLayer: AVPlayerLayer
  private let containerView: UIView
  private var player: AVPlayer?

  init(frame: CGRect, viewId: Int64, args: [String: Any]?) {
    self.playerLayer = AVPlayerLayer()
    self.containerView = UIView(frame: frame)
    super.init()

    containerView.backgroundColor = .clear
    containerView.isOpaque = false

    playerLayer.frame = containerView.bounds
    playerLayer.videoGravity = .resizeAspect
    playerLayer.backgroundColor = UIColor.clear.cgColor
    containerView.layer.addSublayer(playerLayer)

    if let path = args?["path"] as? String,
       let url = URL(string: path) {
      let player = AVPlayer(url: url)
      self.player = player
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
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let argsMap = args as? [String: Any]
    return TransparentVideoPlayerView(frame: frame, viewId: viewId, args: argsMap)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}