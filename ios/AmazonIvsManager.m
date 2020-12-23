#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "RCTViewManager.h"

@interface RCT_EXTERN_MODULE(AmazonIvsManager, RCTViewManager)
RCT_EXTERN_METHOD(play:(nonnull NSNumber *)node)
RCT_EXTERN_METHOD(pause:(nonnull NSNumber *)node)
@end
