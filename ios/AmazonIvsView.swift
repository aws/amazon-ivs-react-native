import Foundation
import UIKit
import AmazonIVSPlayer
import AmazonIVSPlayer_Private // Beta API access

@objc(AmazonIvsView)
class AmazonIvsView: UIView, IVSPlayer.Delegate {
    @objc var onSeek: RCTDirectEventBlock?
    @objc var onData: RCTDirectEventBlock?
    @objc var onVideoStatistics: RCTDirectEventBlock?
    @objc var onPlayerStateChange: RCTDirectEventBlock?
    @objc var onDurationChange: RCTDirectEventBlock?
    @objc var onQualityChange: RCTDirectEventBlock?
    @objc var onPipChange: RCTDirectEventBlock?
    @objc var onRebuffering: RCTDirectEventBlock?
    @objc var onLoadStart: RCTDirectEventBlock?
    @objc var onLoad: RCTDirectEventBlock?
    @objc var onTextCue: RCTDirectEventBlock?
    @objc var onTextMetadataCue: RCTDirectEventBlock?
    @objc var onLiveLatencyChange: RCTDirectEventBlock?
    @objc var onProgress: RCTDirectEventBlock?
    @objc var onTimePoint: RCTDirectEventBlock?

    @objc var onError: RCTDirectEventBlock?

    private let player = IVSPlayer()
    private let playerView = IVSPlayerView()
    private var finishedLoading: Bool = false;

    private var progressObserverToken: Any?
    private var playerObserverToken: Any?
    private var timePointObserver: Any?
    private var oldQualities: [IVSQuality] = [];
    private var lastLiveLatency: Double?;
    private var lastBitrate: Int?;
    private var lastDuration: CMTime?;
    private var lastFramesDropped: Int?;
    private var lastFramesDecoded: Int?;
    private var preloadSourceMap: [Int: IVSSource] = [:]


    private var _pipController: Any? = nil
    private var isPipActive: Bool = false


    @available(iOS 15, *)
    private var pipController: AVPictureInPictureController? {
       get {
           return _pipController as! AVPictureInPictureController?
       }
       set {
           _pipController = newValue
       }
   }


    override init(frame: CGRect) {
        self.muted = player.muted
        self.loop = player.looping
        self.liveLowLatency = player.isLiveLowLatency
        self.rebufferToLive = false;
        self.autoQualityMode = player.autoQualityMode
        self.pipEnabled = false
        self.playbackRate = Double(player.playbackRate)
        self.logLevel = NSNumber(value: player.logLevel.rawValue)
        self.progressInterval = 1
        self.volume = Double(player.volume)
        self.breakpoints = []
        self.initialBufferDuration = 1

        super.init(frame: frame)

        self.addSubview(self.playerView)
        self.playerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.playerView.videoGravity = findResizeMode(mode: resizeMode)

        self.addProgressObserver()
        self.addPlayerObserver()
        self.addTimePointObserver()

        player.delegate = self
        self.playerView.player = player
        preparePictureInPicture()
    }

    deinit {
        self.preloadSourceMap.removeAll()
        self.removeProgressObserver()
        self.removePlayerObserver()
        self.removeTimePointObserver()
    }



    func load(urlString: String) {
        finishedLoading = false
        let url = URL(string: urlString)

        onLoadStart?(["": NSNull()])
        player.load(url)
    }



    @objc var progressInterval: NSNumber {
        // TODO: Figure out why updatating observer does not work and results in multiple calls per second
        didSet {
            self.removeProgressObserver()
            self.addProgressObserver()
        }
    }
    
    @objc var loop: Bool {
        didSet {
            player.looping = loop
        }
    }

    @objc var muted: Bool {
        didSet {
            player.muted = muted
        }
    }

    @objc var playbackRate: Double {
        didSet {
            player.playbackRate = Float(playbackRate)
        }
    }

    @objc var liveLowLatency: Bool {
        didSet {
            player.setLiveLowLatencyEnabled(liveLowLatency)
        }
    }

    @objc var rebufferToLive: Bool {
        didSet {
            player.setRebufferToLive(rebufferToLive)
        }
    }

    @objc var quality: NSDictionary? {
        didSet {
            let newQuality = findQuality(quality: quality)
            player.quality = newQuality
        }
    }

    @objc var autoQualityMode: Bool {
        didSet {
            player.autoQualityMode = autoQualityMode
        }
    }

    @objc var pipEnabled: Bool {
        didSet {
            guard #available(iOS 15, *), AVPictureInPictureController.isPictureInPictureSupported() else {
                return
            }
            if self.pipController != nil {
                self.pipController!.canStartPictureInPictureAutomaticallyFromInline = pipEnabled
                self.togglePip()
                if !self.pipEnabled {
                    self.pipController = nil
                }
            } else {
                self.preparePictureInPicture()
            }
        }
    }


    @objc var autoMaxQuality: NSDictionary? {
        didSet {
            let quality = findQuality(quality: autoMaxQuality)
            player.setAutoMaxQuality(quality)
        }
    }

    @objc var initialBufferDuration: Double {
        didSet {
            let parsedTime = CMTimeMakeWithSeconds(initialBufferDuration, preferredTimescale: 10)
            player.setInitialBufferDuration(parsedTime)
        }
    }

    private func findQuality(quality: NSDictionary?) -> IVSQuality? {
        let quality = player.qualities.first(where: {
            $0.name == quality?["name"] as? String &&
            $0.codecs == quality?["codecs"] as? String &&
            $0.bitrate == quality?["bitrate"] as? Int &&
            $0.framerate == quality?["framerate"] as? Float &&
            $0.width == quality?["width"] as? Int &&
            $0.height == quality?["height"] as? Int
        })

        return quality
    }

    private func getDuration(_ duration: CMTime) -> NSNumber? {
        let value: NSNumber?
        if duration.isNumeric {
            value = NSNumber(value: duration.seconds);
        } else {
            value = 0
        }
        return value
    }

    @objc var streamUrl: String? {
        didSet {
            if let url = streamUrl, !streamUrl!.isEmpty {
                self.load(urlString: url)
            }
        }
    }

    @objc var volume: Double {
        didSet {
            player.volume = Float(volume)
        }
    }

    @objc var logLevel: NSNumber {
        didSet {
            switch logLevel {
            case 0:
                player.logLevel = IVSPlayer.LogLevel.debug
            case 1:
                player.logLevel = IVSPlayer.LogLevel.info
            case 2:
                player.logLevel = IVSPlayer.LogLevel.warning
            case 3:
                player.logLevel = IVSPlayer.LogLevel.error
            default:
                break
            }
        }
    }

    @objc var resizeMode: String? {
        didSet{
            playerView.videoGravity = findResizeMode(mode: resizeMode)
        }
    }

    private func findResizeMode(mode: String?) -> AVLayerVideoGravity {
        switch mode {
        case "aspectFill":
            return  AVLayerVideoGravity.resizeAspectFill
        case "aspectFit":
            return AVLayerVideoGravity.resizeAspect
        case "aspectZoom":
            return AVLayerVideoGravity.resize
        default:
            return AVLayerVideoGravity.resizeAspect
        }
    }

    @objc var breakpoints: NSArray {
        didSet {
            self.removeTimePointObserver()
            self.addTimePointObserver()
        }
    }

    @objc func play() {
        player.play()
    }

    @objc func pause() {
        player.pause()
    }

    @objc func seek(position: Double) {
        let parsedTime = CMTimeMakeWithSeconds(position, preferredTimescale: 1000000)
        player.seek(to: parsedTime)
    }

    @objc func setOrigin(origin: NSString){
        let url = URL(string: origin as String)
        player.setOrigin(url)
    }

    @objc func preload(id: Int, url: NSString) {
        // Beta API
        let url = URL(string: url as String)
        if let url = url {
            let source = player.preload(url)
            preloadSourceMap[id] = source; 
        }
    }

    @objc func loadSource(id: Int) {
        // Beta API
        if let source = preloadSourceMap[id] {
            player.load(source)
        }
    }

    @objc func releaseSource(id: Int) {
        // Beta API
        preloadSourceMap.removeValue(forKey: id)
    }

    @objc func togglePip() {
        guard #available(iOS 15, *), let pipController = pipController else {
            return
        }
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else if self.pipEnabled {
            pipController.startPictureInPicture()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addPlayerObserver() {
        playerObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) {
            [weak self] time in
            if self?.lastLiveLatency != self?.player.liveLatency.seconds {
                if let liveLatency = self?.player.liveLatency.seconds {
                    let parsedValue = 1000*liveLatency
                    self?.onLiveLatencyChange?(["liveLatency": parsedValue])
                } else {
                    self?.onLiveLatencyChange?(["liveLatency": NSNull()])
                }

                self?.lastLiveLatency = self?.player.liveLatency.seconds
            }

            if
                self?.lastBitrate != self?.player.videoBitrate ||
                self?.lastDuration != self?.player.duration ||
                self?.lastFramesDecoded != self?.player.videoFramesDecoded ||
                self?.lastFramesDropped != self?.player.videoFramesDropped ||
                self?.onVideoStatistics != nil {
                let videoData: [String: Any] = [
                    "duration": self?.getDuration(self!.player.duration) ?? NSNull(),
                    "bitrate": self?.player.videoBitrate ?? NSNull(),
                    "framesDropped": self?.player.videoFramesDropped ?? NSNull(),
                    "framesDecoded": self?.player.videoFramesDecoded ?? NSNull()
                ]

                self?.onVideoStatistics?(["videoData": videoData])

                self?.lastBitrate = self?.player.videoBitrate
                self?.lastDuration = self?.player.duration
                self?.lastFramesDropped = self?.player.videoFramesDropped
                self?.lastFramesDecoded = self?.player.videoFramesDecoded
            }
        }
    }

    private func mapPlayerState(state: IVSPlayer.State) -> String {
        switch state {
        case IVSPlayer.State.playing: return "Playing"
        case IVSPlayer.State.buffering: return "Buffering"
        case IVSPlayer.State.ready: return "Ready"
        case IVSPlayer.State.idle: return "Idle"
        case IVSPlayer.State.ended: return "Ended"
        }
    }

    func addProgressObserver() {
        progressObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: Double(truncating: progressInterval), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) {
            [weak self] time in
            self?.onProgress?(["position": (self?.player.position.seconds ?? nil) as Any])
        }
    }

    func addTimePointObserver() {
        timePointObserver = player.addBoundaryTimeObserver(forTimes: breakpoints as! [NSNumber], queue: .main) {
            [weak self] in
            self?.onTimePoint?(["position": (self?.player.position.seconds ?? nil) as Any])

        }
    }

    func removePlayerObserver() {
        if let token = playerObserverToken {
            player.removeTimeObserver(token)
            self.playerObserverToken = nil
        }
    }

    func removeProgressObserver() {
        if let token = progressObserverToken {
            player.removeTimeObserver(token)
            self.progressObserverToken = nil
        }
    }

    func removeTimePointObserver() {
        if let token = timePointObserver {
            player.removeTimeObserver(token)
            self.timePointObserver = nil
        }
    }

    func player(_ player: IVSPlayer, didSeekTo time: CMTime) {
        onSeek?(["position": CMTimeGetSeconds(time)])
    }

    func player(_ player: IVSPlayer, didChangeState state: IVSPlayer.State) {
        onPlayerStateChange?(["state": mapPlayerState(state: state)])

        if state == IVSPlayer.State.playing, finishedLoading == false {
            let duration = getDuration(player.duration)
            onLoad?(["duration": duration ?? NSNull()])
            finishedLoading = true
        }

        if state == IVSPlayer.State.ready {
            if player.qualities != oldQualities {
                let qualities: NSMutableArray = []
                for quality in player.qualities {
                    let qualityData: [String: Any] = [
                        "name": quality.name,
                        "codecs": quality.codecs,
                        "bitrate": quality.bitrate,
                        "framerate": quality.framerate,
                        "width": quality.width,
                        "height": quality.height
                    ]

                    qualities.add(qualityData)
                }

                onData?(["playerData": [
                    "qualities": qualities,
                    "version": player.version,
                    "sessionId": player.sessionId
                ]])
            }

            oldQualities = player.qualities
        }
    }

    func player(_ player: IVSPlayer, didChangeDuration duration: CMTime) {
        let parsedDuration = getDuration(duration)
        onDurationChange?(["duration": parsedDuration ?? NSNull()])
    }

    func player(_ player: IVSPlayer, didChangeQuality quality: IVSQuality?) {
            if quality == nil {
                onQualityChange?(["quality": NSNull()])
            } else {
                let qualityData: [String: Any] = [
                    "name": quality?.name ?? "",
                    "codecs": quality?.codecs ?? "",
                    "bitrate": quality?.bitrate ?? 0,
                    "framerate": quality?.framerate ?? 0,
                    "width": quality?.width ?? 0,
                    "height": quality?.height ?? 0
                ]

                onQualityChange?(["quality": qualityData])
            }
    }

    func player(_ player: IVSPlayer, didOutputCue cue: IVSCue) {
        if let cue = cue as? IVSTextCue {
            let textCue: [String: Any] = [
                "type": cue.type.rawValue,
                "line": cue.line,
                "size": cue.size,
                "position": cue.position,
                "text": cue.text,
                "textAlignment": cue.textAlignment
            ]

            onTextCue?(["textCue": textCue])
        }

        if let cue = cue as? IVSTextMetadataCue {
            let textMetadataCue = [
                "type": cue.type.rawValue,
                "text": cue.text,
                "textDescription": cue.textDescription

            ]

            onTextMetadataCue?(["textMetadataCue": textMetadataCue])
        }
    }

    func playerWillRebuffer(_ player: IVSPlayer) {
        onRebuffering?(["": NSNull()])
    }

    func player(_ player: IVSPlayer, didFailWithError error: Error) {
        onError?(["error": error.localizedDescription])
    }

    private func preparePictureInPicture() {

        guard #available(iOS 15, *), AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }

        if !self.pipEnabled {
            return
        }
        if let existingController = self.pipController {
            if existingController.ivsPlayerLayer == playerView.playerLayer {
                return
            }
            self.pipController = nil
        }

        guard let pipController = AVPictureInPictureController(ivsPlayerLayer: playerView.playerLayer) else {
            return
        }

        self.pipController = pipController
        pipController.canStartPictureInPictureAutomaticallyFromInline = self.pipEnabled
        pipController.delegate = self
    }
}
@available(iOS 15, *)
extension AmazonIvsView: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPipActive = true
        onPipChange?(["active": isPipActive])
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPipActive = false
        onPipChange?(["active": isPipActive])
    }
}

