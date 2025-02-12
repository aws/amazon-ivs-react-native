package com.amazonaws.ivs.reactnative.player

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.net.Uri
import android.widget.FrameLayout
import com.amazonaws.ivs.player.*
import android.os.Build
import com.amazonaws.ivs.player.Player.State.*
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.events.RCTEventEmitter
import java.util.*
import java.util.concurrent.TimeUnit
import kotlin.concurrent.timerTask

class AmazonIvsView(private val context: ThemedReactContext) : FrameLayout(context), LifecycleEventListener {
  private var playerView: PlayerView? = null
  private var player: Player? = null
  private var streamUri: Uri? = null
  private val playerListener: Player.Listener?

  var playerObserver: Timer? = null
  private var lastLiveLatency: Long? = null
  private var lastBitrate: Long? = null
  private var lastDuration: Long? = null
  private var lastPipState: Boolean = false;
  private var finishedLoading: Boolean = false
  private var pipEnabled: Boolean = false
  private var isInBackground: Boolean = false
  private var preloadSourceMap: HashMap<Int, Source> = hashMapOf()


  enum class Events(private val mName: String) {
    STATE_CHANGED("onPlayerStateChange"),
    DURATION_CHANGED("onDurationChange"),
    ERROR("onError"),
    QUALITY_CHANGED("onQualityChange"),
    PIP_CHANGED("onPipChange"),
    CUE("onTextCue"),
    METADATA_CUE("onTextMetadataCue"),
    LOAD("onLoad"),
    LOAD_START("onLoadStart"),
    REBUFFERING("onRebuffering"),
    SEEK("onSeek"),
    DATA("onData"),
    LIVE_LATENCY_CHANGED("onLiveLatencyChange"),
    VIDEO_STATISTICS("onVideoStatistics"),
    PROGRESS("onProgress");

    override fun toString(): String {
      return mName
    }
  }

  init {
    playerView = PlayerView(context)
    player = playerView?.player
    playerView?.controlsEnabled = false

    (context as ThemedReactContext).addLifecycleEventListener(this)

    playerListener = object : Player.Listener() {
      override fun onStateChanged(state: Player.State) {
        onPlayerStateChange(state)
      }

      override fun onDurationChanged(duration: Long) {
        onDurationChange(duration)
      }

      override fun onRebuffering() {
        onPlayerRebuffering()
      }

      override fun onSeekCompleted(position: Long) {
        onSeek(position)
      }

      override fun onQualityChanged(quality: Quality) {
        onQualityChange(quality)
      }

      override fun onVideoSizeChanged(p0: Int, p1: Int) {
        post(mLayoutRunnable)
      }

      override fun onCue(cue: Cue) {
        if (cue is TextCue) {
          onTextCue(cue)
        } else if (cue is TextMetadataCue) {
          onTextMetadataCue(cue)
        }
      }

      override fun onError(e: PlayerException) {
        onError(e.getErrorMessage())
      }
    }

    player?.addListener(playerListener);
    addView(playerView)

    playerObserver = Timer("observerInterval", false)
    playerObserver?.schedule(timerTask {
      intervalHandler()
    }, 0, 1000)
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    super.onLayout(changed, left, top, right, bottom)
    if (changed) {
      post(mLayoutRunnable)
    }
  }

  fun setStreamUrl(streamUrl: String) {
    player?.let { player ->
      val reactContext = context as ReactContext
      val uri = Uri.parse(streamUrl);
      this.streamUri = uri;

      finishedLoading = false
      player.load(uri)

      reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.LOAD_START.toString(), Arguments.createMap())
    }
  }

  fun setMuted(muted: Boolean) {
    player?.isMuted = muted
  }

  fun setLooping(shouldLoop: Boolean) {
    player?.setLooping(shouldLoop)
  }

  fun setVolume(volume: Double) {
    player?.setVolume(volume.toFloat())
  }

  fun setLiveLowLatency(liveLowLatency: Boolean) {
    player?.setLiveLowLatencyEnabled(liveLowLatency)
  }

  fun setRebufferToLive(rebufferToLive: Boolean) {
    player?.setRebufferToLive(rebufferToLive)
  }

  fun setPlaybackRate(playbackRate: Double) {
    player?.playbackRate = playbackRate.toFloat()
  }

  fun setLogLevel(logLevel: Double) {
    when (logLevel.toInt()) {
      0 -> player?.setLogLevel(Player.LogLevel.DEBUG)
      1 -> player?.setLogLevel(Player.LogLevel.INFO)
      2 -> player?.setLogLevel(Player.LogLevel.WARNING)
      3 -> player?.setLogLevel(Player.LogLevel.ERROR)
    }
  }


  fun setResizeMode(resizeMode: String?) {
    playerView?.resizeMode = findResizeMode(resizeMode)
  }

  private fun findResizeMode(mode: String?): ResizeMode = when (mode) {
      "aspectFill" -> ResizeMode.FILL
      "aspectFit" -> ResizeMode.FIT
      "aspectZoom" -> ResizeMode.ZOOM
      else -> ResizeMode.FIT
  }

  private fun findQuality(quality: ReadableMap?): Quality? {
    val newQuality = player?.qualities?.firstOrNull() { x ->
        x.name == quality?.getString("name") &&
        x.codecs == quality.getString("codecs") &&
        x.bitrate == quality.getInt("bitrate") &&
        x.framerate == quality.getDouble("framerate").toFloat() &&
        x.width == quality.getInt("width") &&
        x.height == quality.getInt("height")
    }

    return newQuality
  }

  fun setQuality(quality: ReadableMap?) {
    if (quality != null) {
      findQuality(quality)?.let {
        player?.quality = it
      }
    }
  }

  fun setAutoMaxQuality(quality: ReadableMap?) {
    if (quality != null) {
      findQuality(quality)?.let {
        player?.setAutoMaxQuality(it)
      }
    }
  }

  fun setAutoQualityMode(autoQualityMode: Boolean) {
    player?.isAutoQualityMode = autoQualityMode
  }

  fun setPipEnabled(_pipEnabled: Boolean) {
    pipEnabled = _pipEnabled
    if (!pipEnabled) togglePip()
  }

  fun onTextCue(cue: TextCue) {
    val reactContext = context as ReactContext

    val textCue = Arguments.createMap()
    textCue.putString("type", cue.javaClass.name)
    textCue.putDouble("line", cue.line.toDouble())
    textCue.putDouble("size", cue.size.toDouble())
    textCue.putDouble("position", cue.position.toDouble())
    textCue.putString("text", cue.text)
    textCue.putInt("textAlignment", cue.textAlign.ordinal)

    val data = Arguments.createMap()
    data.putMap("textCue", textCue)

    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.CUE.toString(), data)
  }

  fun setMaxBitrate(bitrate: Double) {
    player?.setAutoMaxBitrate(bitrate.toInt())
  }

  fun setInitialBufferDuration(duration: Double) {
    val valueInMilliseconds = duration * 1000
    player?.setInitialBufferDuration(valueInMilliseconds.toLong())
  }


  fun onTextMetadataCue(cue: TextMetadataCue) {
    val reactContext = context as ReactContext

    val textMetadataCue = Arguments.createMap()
    textMetadataCue.putString("type", cue.javaClass.name)
    textMetadataCue.putString("text", cue.text)
    textMetadataCue.putString("description", cue.description)

    val data = Arguments.createMap()
    data.putMap("textMetadataCue", textMetadataCue)

    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.METADATA_CUE.toString(), data)
  }

  fun onDurationChange(duration: Long) {
    val reactContext = context as ReactContext
    val data = Arguments.createMap()
    val parsedDuration = getDuration(duration);
    data.putDouble("duration", parsedDuration)

    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.DURATION_CHANGED.toString(), data)
  }

  fun onError(error: String) {
    val reactContext = context as ReactContext
    val data = Arguments.createMap()
    data.putString("error", error)

    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.ERROR.toString(), data)
  }

  fun onSeek(position: Long) {
    val reactContext = context as ReactContext
    val data = Arguments.createMap()
    data.putDouble("position", convertMilliSecondsToSeconds(position))
    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.SEEK.toString(), data)
  }

  fun onProgress(position: Long) {
    val reactContext = context as ReactContext
    val data = Arguments.createMap()
    data.putDouble("position", convertMilliSecondsToSeconds(position))
    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.PROGRESS.toString(), data)
  }

  fun onPipChange(active: Boolean) {
      val reactContext = context as ReactContext
      val data = Arguments.createMap()
      data.putString("active", if (active) "true" else "false")

      reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.PIP_CHANGED.toString(), data)
  }

  private fun convertMilliSecondsToSeconds (milliSeconds: Long): Double {
    return milliSeconds / 1000.0
  }

  private val mLayoutRunnable = Runnable {
    measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY))
    layout(left, top, right, bottom)
  }

  fun play() {
    player?.play()
  }

  fun pause() {
    player?.pause()
  }

  fun seekTo(position: Double) {
    val milliseconds = (position * 1000.0).toLong()
    player?.seekTo(milliseconds)
  }

  fun setOrigin(origin: String) {
    player?.setOrigin(origin)
  }

  fun preload(id: Int, url: String) {
    // Beta API
    val mplayer = player as? MediaPlayer
    val source = mplayer?.preload(Uri.parse(url))
    source?.let {
      preloadSourceMap.put(id, source)
    }
  }

  fun loadSource(id: Int) {
    // Beta API
    val source = preloadSourceMap.get(id)
    source?.let {
      val mplayer = player as? MediaPlayer
      mplayer?.loadSource(source)
    }
  }

  fun releaseSource(id: Int) {
    // Beta API
    val source = preloadSourceMap.remove(id)
    source?.let {
      source.release()
    }
  }

  fun onPlayerStateChange(state: Player.State) {
    val reactContext = context as ReactContext

    when (state) {
      PLAYING -> {
        if (!finishedLoading) {
          val onLoadData = Arguments.createMap()
          val parsedDuration = getDuration(player!!.duration);
          onLoadData.putDouble("duration", parsedDuration)

          finishedLoading = true

          reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.LOAD.toString(), onLoadData)
        }
      }
      READY -> {
        val data = Arguments.createMap()
        val playerData = Arguments.createMap()
        playerData.putString("version", player?.version)
        playerData.putString("sessionId", player?.sessionId)

        val qualities = Arguments.createArray()
        for (quality in player!!.qualities) {
          val parsedQuality = Arguments.createMap()
          parsedQuality.putString("name", quality.name)
          parsedQuality.putString("codecs", quality.codecs)
          parsedQuality.putInt("bitrate", quality.bitrate)
          parsedQuality.putDouble("framerate", quality.framerate.toDouble())
          parsedQuality.putInt("width", quality.width)
          parsedQuality.putInt("height", quality.height)
          qualities.pushMap(parsedQuality)
        }
        playerData.putArray("qualities", qualities)
        data.putMap("playerData", playerData)

        reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.DATA.toString(), data)
      };
      BUFFERING -> {} // The following empty statements are intentional and avoid Kotlin’s "expression must be exhaustive" error.
      IDLE -> {}
      ENDED -> {}
    }

    val onStateChangeData = Arguments.createMap()
    onStateChangeData.putString("state", mapPlayerState(state))
    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.STATE_CHANGED.toString(), onStateChangeData)
  }

  fun onQualityChange(quality: Quality) {
    val reactContext = context as ReactContext

    val newQuality = Arguments.createMap()
    newQuality.putString("name", quality.name)
    newQuality.putString("codecs", quality.codecs)
    newQuality.putInt("bitrate", quality.bitrate)
    newQuality.putDouble("framerate", quality.framerate.toDouble())
    newQuality.putInt("width", quality.width)
    newQuality.putInt("height", quality.height)

    val data = Arguments.createMap()
    data.putMap("quality", newQuality)

    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.QUALITY_CHANGED.toString(), data)
  }

  fun onPlayerRebuffering() {
    val reactContext = context as ReactContext
    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.REBUFFERING.toString(), Arguments.createMap())
  }

  private fun intervalHandler() {
    val reactContext = context as ReactContext

    if (pipEnabled)
    {
        val activity: Activity? = reactContext.currentActivity
        val isPipActive = activity!!.isInPictureInPictureMode
        if(lastPipState !== isPipActive)
        {
          lastPipState = isPipActive
          onPipChange(isPipActive === true)
        }
    }

    if (lastLiveLatency != player?.liveLatency) {
      val liveLatencyData = Arguments.createMap()

      player?.liveLatency?.let { liveLatency ->
        liveLatencyData.putInt("liveLatency", liveLatency.toInt())
      } ?: run {
        liveLatencyData.putNull("liveLatency")
      }
      reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.LIVE_LATENCY_CHANGED.toString(), liveLatencyData)

      lastLiveLatency = player?.liveLatency
    }


    if (lastBitrate != player?.averageBitrate || lastDuration != player?.duration) {
      val onVideoData = Arguments.createMap()
      val videoData = Arguments.createMap()

      player?.duration?.let { duration ->
        val parsedDuration = getDuration(duration)
        videoData.putDouble("duration", parsedDuration)
      } ?: run {
        videoData.putNull("duration")
      }

      player?.averageBitrate?.let { averageBitrate ->
        videoData.putInt("bitrate", averageBitrate.toInt())
      } ?: run {
        videoData.putNull("bitrate")
      }

      onVideoData.putMap("videoData", videoData)
      reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, Events.VIDEO_STATISTICS.toString(), onVideoData)

      lastBitrate = player?.averageBitrate
      lastDuration = player?.duration
    }
    player?.position?.let { position ->
      if (position > 0 && player?.state === PLAYING) {
        onProgress(position)
      }
    }
  }

  private fun getDuration(duration: Long): Double {
    return convertMilliSecondsToSeconds(duration)
  }

  private fun mapPlayerState(state: Player.State): String {
    return when(state) {
      PLAYING -> "Playing"
      BUFFERING -> "Buffering"
      READY -> "Ready"
      IDLE -> "Idle"
      ENDED -> "Ended"
    }
  }

  fun togglePip() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    ) {
      val activity: Activity? = context.currentActivity
      val hasToBuild = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

      if (!pipEnabled) {

        val isInPip =
            if (hasToBuild) activity!!.isInPictureInPictureMode
            else activity!!.isInPictureInPictureMode
        if (isInPip) {
          activity?.moveTaskToBack(false)
        }
        return
      }

      if (hasToBuild) {
        val params = PictureInPictureParams.Builder().build()
        activity?.enterPictureInPictureMode(params)
      } else {
        activity?.enterPictureInPictureMode()
      }
    }
  }

  override fun onHostResume() {
    isInBackground = false
  }

  override fun onHostPause() {
    if (pipEnabled) {
      isInBackground = true
      togglePip()
    }
  }

  override fun onHostDestroy() {
    cleanup()
  }

  fun cleanup() {
    // Cleanup any remaining sources
    for (source in preloadSourceMap.values) {
      source.release()
    }
    preloadSourceMap.clear()

    player?.removeListener(playerListener!!)
    player?.release()
    player = null

    playerObserver?.cancel()
    playerObserver = null
  }
}
