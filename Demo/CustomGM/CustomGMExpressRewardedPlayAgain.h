#import <Foundation/Foundation.h>
#import <BUAdSDK/BUAdSDK.h>
#import "CustomGMRewardedAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomGMExpressRewardedPlayAgain : NSObject<BUMNativeExpressRewardedVideoAdDelegate>

@property (nonatomic,weak) CustomGMRewardedAdapter *rewardedAdapter;
@end

NS_ASSUME_NONNULL_END
