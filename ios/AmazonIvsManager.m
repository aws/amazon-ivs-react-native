#import "React/RCTBridgeModule.h"
#import "RCTViewManager.h"

@interface RCT_EXTERN_MODULE(AmazonIvsManager, RCTViewManager)
RCT_EXPORT_VIEW_PROPERTY(muted, BOOL)
RCT_EXPORT_VIEW_PROPERTY(looping, BOOL)
RCT_EXPORT_VIEW_PROPERTY(liveLowLatency, BOOL)
RCT_EXPORT_VIEW_PROPERTY(quality, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(autoMaxQuality, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(autoQualityMode, BOOL)
RCT_EXPORT_VIEW_PROPERTY(playbackRate, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(logLevel, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(progressInterval, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(volume, NSNumber)
RCT_EXTERN_METHOD(play:(nonnull NSNumber *)node)
RCT_EXTERN_METHOD(pause:(nonnull NSNumber *)node)
RCT_EXPORT_VIEW_PROPERTY(streamUrl, NSString)
RCT_EXTERN_METHOD(seekTo:(nonnull NSNumber *)node position:(nonnull NSNumber)position)
RCT_EXPORT_VIEW_PROPERTY(onSeek, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onData, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPlayerStateChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDurationChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onQualityChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onBuffer, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoad, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLiveLatencyChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onTextCue, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onTextMetadataCue, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onProgress, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onBandwidthEstimateChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock)
@end
