# IVS Player component - reference

IVS Player component allows setup and interaction with native implementation of Amazon IVS player on iOS and Android.
This document contains information about available props, callbacks, and refs.

Amazon IVS documentation:
https://docs.aws.amazon.com/ivs/index.html

Android reference:
https://aws.github.io/amazon-ivs-player-docs/1.2.1/android/reference/packages.html

iOS reference:
https://aws.github.io/amazon-ivs-player-docs/1.2.0/ios/index.html

Web reference:
https://aws.github.io/amazon-ivs-player-docs/1.2.0/web/

```tsx
import IVSPlayer from 'amazon-ivs-react-native';

function App() {
  return (
    <IVSPlayer streamUrl="https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.DmumNckWFTqz.m3u8" />
  );
}
```

## Props

### children _(optional)_

Can be used to display something `absolutely` on top of the video player.

type: `React.ReactNode`

### style _(optional)_

Style of IVSPlayer wrapper.

default: `undefined`
type: `StyleProp<ViewStyle>`

### streamUrl _(optional)_

An URL of the the stream to load. Should be in a valid URL format.

default: `undefined`
type: `string`

### autoplay _(optional)_

Opening a player or specifying new `streamUrl` will make it automatically play, when it is ready.

default: `true`
type: `boolean`

### logLevel _(optional)_

Specifies level of logging information from player to the console.

default: `IVSLogLevelError`
type: [`LogLevel`](./types.md#LogLevel)

### muted _(optional)_

Disables audio from the currently played video/stream.

default: `false`
type: `boolean`

### paused _(optional)_

Pauses playback of current video/stream.

default: `false`
type: `boolean`

### playbackRate _(optional)_

The video-playback rate.
Supported range: `0.5` to `2.0`.

default: `1.0`
type: `number`

### volume _(optional)_

Volume of the audio track, if any. This setting is independent from device volume.
Supported range: `0.0` to `1.0`.

default: `1.0`
type: `number`

### quality _(optional)_

Specifies what video/stream quality should be used for playback. Setting the property to `null` implicitly enables autoQualityMode, and a new quality will be selected asynchronously.
Available qualites for current video/stream can be read from `onData` callback.

type: [`Quality | null`](./types.md#Quality)

### autoMaxQuality _(optional)_

Specifies maximum quality that can be used when `autoQualityMode` is turned on. This can be used to control resource usage. The quality you provide here is applied to the current stream.

default: `undefined`
type: [`Quality`](./types.md#Quality)

### autoQualityMode _(optional)_

Automatically select video quality based on the quality of the internet connection.

default: `true`
type: `boolean`

### maxBitrate _(optional)_

Sets the max bitrate when using `autoQualityMode`. Allows you to control resource usage in the case of multiple players.

Android only
type: `number`

### liveLowLatency _(optional)_

Indicates whether live low-latency streaming is enabled for the current stream.
Only works with live streams.

type: `boolean`

### onRebuffering _(optional)_

Indicates that the player is buffering from a previous PLAYING state.
Excludes user actions such as seeking, starting or resuming the stream.

type: `() => void`

### onError _(optional)_

Callback function that is called when error occurs.

type: `(error: string) => void`

### onLiveLatencyChange _(optional)_

Callback that return changes in live latency. Value is milliseconds.

type: `(liveLatency: number) => void`

### onData _(optional)_

Callback that returns qualities, version, and sessionId, when new data is present.

type: `({ qualities: Quality, version: string, sessionId: string }) => void`

### onVideoStatistics _(optional)_

Callback that return changes in duration, bitrate, framesDropped, and framesDecoded.
Duration returns null if no stream is loaded. It returns Infinity if stream length is infinite or unknown.
framesDropped and framesDecoded are only available on iOS.

type: `({ duration: number | null, bitrate: number, framesDropped: number, framesDecoded: number }) => void`

### onPlayerStateChange _(optional)_

Callback that returns player state when it changes. E.g. play, pause, error, buffering, etc.

type: [`(state: PlayerState) => void`](./types.md#)

### onLoad _(optional)_

Callback that is called on new video load.
This returns null if no stream is loaded or the stream length is infinite or unknown.

type: `(duration: number | number) => void`

### onLoadStart _(optional)_

Callback that is called on new video load.

type: `() => void`

### onProgress _(optional)_

Callback that returns current player position. Its interval can be configured using `progressInterval` prop.

type: `(position: number) => void`

### progressInterval _(optional)_

Value that specifies how often `onProgress` callback should be called in seconds.

default: `1`
type: `number`

### onTimePoint _(optional)_

Callback that returns current player position. Only called when position is included in `breakpoints` prop array.

**!!!WARNING!!!** You need to specify `breakpoints` for this callback to be called. **!!!WARNING!!!**

iOS only
type: `(position: number) => number`

### breakpoints _(optional)_

Specifies time breakpoints in which `onTimePoint` callback should be called. Breakpoint value is seconds.

default: `[]`
type: `number[]`

### onTextCue _(optional)_

Callback that returns text cue when it is present during video/stream playback.

type: [`(textCue: TextCue => void)`](./types.md#TextCue)

### onTextMetadataCue _(optional)_

Callback that returns text metadata cue when it is present from video/stream playback.

type: [`(textMetadataCue: TextMetadataCue => void)`](./types.md#TextMetadataCue)

### onDurationChange _(optional)_

Callback that returns changes to the duration of video/stream.
This returns null if no stream is loaded. It returns Infinity if stream length is infinite or unknown.

type: `(duration: number | null) => void`

### onSeek _(optional)_

Callback that returns new position when it is changed using `seekTo` ref.

type: `(position: number) => void`

### onQualityChange _(optional)_

Callback that returns new quality that is used in video/stream playback.

type: [`(quality: Quality) => void`](./types.md#Quality)

## Ref methods

### play

A reference method that will play the stream/video if it is stopped. For a stream that is currently playing it won't do anything.

type: `() => void`

```tsx
import IVSPlayer, { IVSPlayerRef } from 'amazon-ivs-react-native';

const URL = 'https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.DmumNckWFTqz.m3u8';

function App() {
  const mediaPlayerRef = React.useRef<IVSPlayerRef>(null);

  const handlePlay = () => { mediaPlayerRef.current?.play() };

  return (
    <>
      <IVSPlayer ref={mediaPlayerRef} streamUrl={URL} />
      <Button onPress={handlePlay} title="Play">
    </>
  );
}
```

### pause

A reference method that will pause the stream/video if it is playing. For a stream that is currently paused it won't do anything.

type: `() => void`

```tsx
import IVSPlayer, { IVSPlayerRef } from 'amazon-ivs-react-native';

const URL = 'https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.DmumNckWFTqz.m3u8';

function App() {
  const mediaPlayerRef = React.useRef<IVSPlayerRef>(null);

  const handlePause = () => { mediaPlayerRef.current?.pause() };

  return (
    <>
      <IVSPlayer ref={mediaPlayerRef} streamUrl={URL} />
      <Button onPress={handlePause} title="Pause">
    </>
  );
}
```

### seekTo

Seeks to the given time in the stream and begins playing at that position if `play()` has been called. If no stream is loaded the seek will be be deferred until load is called. The position will update to the seeked time. Specified value should be in seconds.

type: `(position: number, completionHandler: function?) => void`

```tsx
import IVSPlayer, { IVSPlayerRef } from 'amazon-ivs-react-native';

const URL = 'https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.DmumNckWFTqz.m3u8';

function App() {
  const mediaPlayerRef = React.useRef<IVSPlayerRef>(null);

  const handleSeekTo = () => { mediaPlayerRef.current?.seekTo({ position: 15 }) };

  return (
    <>
      <IVSPlayer ref={mediaPlayerRef} streamUrl={URL} />
      <Button onPress={handleSeekTo} title="Pause">
    </>
  );
}
```
