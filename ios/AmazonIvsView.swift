import Foundation
import UIKit
import AmazonIVSPlayer

@objc(AmazonIvsView)
class AmazonIvsView: UIView, IVSPlayer.Delegate {
    @objc var onSeek: RCTDirectEventBlock?
    @objc var onData: RCTDirectEventBlock?
    @objc var onVideoStatistics: RCTDirectEventBlock?
    @objc var onPlayerStateChange: RCTDirectEventBlock?
    @objc var onDurationChange: RCTDirectEventBlock?
    @objc var onQualityChange: RCTDirectEventBlock?
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

    override init(frame: CGRect) {
        self.muted = player.muted
        self.liveLowLatency = player.isLiveLowLatency
        self.autoQualityMode = player.autoQualityMode
        self.playbackRate = Double(player.playbackRate)
        self.logLevel = NSNumber(value: player.logLevel.rawValue)
        self.progressInterval = 1
        self.volume = Double(player.volume)
        self.breakpoints = []

        super.init(frame: frame)

        self.addSubview(self.playerView)
        self.playerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.addProgressObserver()
        self.addPlayerObserver()
        self.addTimePointObserver()
        self.addApplicationLifecycleObservers()

        player.delegate = self
        self.playerView.player = player
    }

    deinit {
        self.removeProgressObserver()
        self.removePlayerObserver()
        self.removeTimePointObserver()
        self.removeApplicationLifecycleObservers()
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

    @objc var autoMaxQuality: NSDictionary? {
        didSet {
            let quality = findQuality(quality: autoMaxQuality)
            player.setAutoMaxQuality(quality)
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

    private func getDuration(_ duration: CMTime) -> Double {
        if duration.isNumeric {
            return duration.seconds;
        } else {
            return Double.infinity; // live video
        }
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

    private var didPauseOnBackground = false

    @objc private func applicationDidEnterBackground(notification: Notification) {
        if player.state == .playing || player.state == .buffering {
            didPauseOnBackground = true
            pause()
        } else {
            didPauseOnBackground = false
        }
    }

    @objc private func applicationDidBecomeActive(notification: Notification) {
        if didPauseOnBackground && player.error == nil {
            play()
            didPauseOnBackground = false
        }
    }

    private func addApplicationLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func removeApplicationLifecycleObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
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
            onLoad?(["duration": duration ])
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
        onDurationChange?(["duration": parsedDuration])
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
}
