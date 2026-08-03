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

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return .portrait
  }
}

class TransparentVideoPlayerView: NSObject, FlutterPlatformView {
  private let playerLayer: AVPlayerLayer
  private let containerView: UIView
  private var player: AVPlayer?
  private var playerItemContext = 0

  init(frame: CGRect, viewId: Int64, args: [String: Any]?) {
    self.playerLayer = AVPlayerLayer()
    self.containerView = UIView(frame: frame)
    super.init()

    containerView.backgroundColor = .clear
    containerView.isOpaque = false
    containerView.layer.masksToBounds = false

    playerLayer.frame = containerView.bounds
    playerLayer.videoGravity = .resizeAspect
    playerLayer.backgroundColor = UIColor.clear.cgColor
    playerLayer.isOpaque = false
    containerView.layer.addSublayer(playerLayer)

    if let path = args?["path"] as? String {
      let url = URL(fileURLWithPath: path)
      let playerItem = AVPlayerItem(url: url)
      let player = AVPlayer(playerItem: playerItem)
      self.player = player
      playerLayer.player = player
      player.actionAtItemEnd = .none

      playerItem.addObserver(
        self,
        forKeyPath: "status",
        options: [.old, .new],
        context: &playerItemContext
      )

      NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: playerItem,
        queue: .main
      ) { [weak player] _ in
        player?.seek(to: .zero)
        player?.play()
      }

      NotificationCenter.default.addObserver(
        forName: .AVPlayerItemFailedToPlayToEndTime,
        object: playerItem,
        queue: .main
      ) { notification in
        debugPrint("Transparent video failed: \(notification)")
      }
    }
  }

  func view() -> UIView {
    return containerView
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    guard context == &playerItemContext else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
      return
    }

    guard let item = object as? AVPlayerItem, keyPath == "status" else { return }
    if item.status == .readyToPlay {
      player?.seek(to: .zero)
      player?.play()
    } else if item.status == .failed {
      debugPrint("Transparent video item error: \(String(describing: item.error))")
    }
  }

  deinit {
    if let item = player?.currentItem {
      item.removeObserver(self, forKeyPath: "status", context: &playerItemContext)
    }
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
