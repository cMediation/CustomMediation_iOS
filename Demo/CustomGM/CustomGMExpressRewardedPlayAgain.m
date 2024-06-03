#import "CustomGMExpressRewardedPlayAgain.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>

@interface CustomGMExpressRewardedPlayAgain()

@property (nonatomic,assign)BOOL didShow;
@end

@implementation CustomGMExpressRewardedPlayAgain

- (void)nativeExpressRewardedVideoAdDidLoad:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
}

- (void)nativeExpressRewardedVideoAd:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
}

- (void)nativeExpressRewardedVideoAdDidDownLoadVideo:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
}

- (void)nativeExpressRewardedVideoAdDidVisible:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    if(self.rewardedAdapter != nil)
    {
        if(!self.didShow)
        {
            self.didShow = YES;
            [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_show" info:nil];
            [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_play_begin" info:nil];
        }
    }
}

- (void)nativeExpressRewardedVideoAdDidShowFailed:(BUNativeExpressRewardedVideoAd *_Nonnull)rewardedVideoAd error:(NSError *_Nonnull)error
{
    if(self.rewardedAdapter != nil)
    {
        NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
        if(error != nil)
        {
            info[@"error"] = error;
        }
        [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_showFail" info:info];
    }
}

- (void)nativeExpressRewardedVideoAdDidClose:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
}

- (void)nativeExpressRewardedVideoAdDidClick:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    if(self.rewardedAdapter != nil)
    {
        [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_click" info:nil];
    }
}

- (void)nativeExpressRewardedVideoAdDidPlayFinish:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    if(self.rewardedAdapter != nil)
    {
        if(error != nil)
        {
            [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_showFail" info:@{@"error":error}];
        }
        [self.rewardedAdapter ADShowExtraCallbackWithEvent:@"playAgain_play_end" info:nil];
    }
}

- (void)nativeExpressRewardedVideoAdServerRewardDidSucceed:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd verify:(BOOL)verify
{
    if(self.rewardedAdapter != nil)
    {
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"rewardId"] = rewardedVideoAd.rewardedVideoModel.userId;
        dic[@"rewardName"] = rewardedVideoAd.rewardedVideoModel.rewardName;
        dic[@"rewardNumber"] = @(rewardedVideoAd.rewardedVideoModel.rewardAmount);
        [self.rewardedAdapter AdPlayAgainRewardedWithInfo:dic];
    }
}

@end
