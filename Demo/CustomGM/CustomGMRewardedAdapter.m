#import "CustomGMRewardedAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "CustomGMSDKLoader.h"
#import "CustomGMExpressRewardedPlayAgain.h"
#import "CustomGMECPM.h"

@interface CustomGMRewardedAdapter ()<BUMNativeExpressRewardedVideoAdDelegate,CustomGMLoaderDelegate>

@property (nonatomic, strong) BUNativeExpressRewardedVideoAd *expressRewardedVideoAd;
@property (nonatomic, strong) CustomGMExpressRewardedPlayAgain *expressRewardedPlayAgainObj;
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL shouldReward;
@property (nonatomic, assign) BOOL isSkip;
@property (nonatomic, assign) BOOL isC2SBidding;
@property (nonatomic, strong) NSMutableDictionary *rewardDic;
//是否静音
@property (nonatomic, assign) BOOL videoMute;
@end

@implementation CustomGMRewardedAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"C2SBidding"])
    {
        [self initSDKC2SBidding];
    }
    else if([event isEqualToString:@"LoadAdC2SBidding"])
    {
        [self loadAdC2SBidding];
    }
    else
    {
        return NO;
    }
    return YES;
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    [self initSDKWithWaterfallItem:item initSource:3];
}

- (void)initSDKWithWaterfallItem:(TradPlusAdWaterfallItem *)item initSource:(NSInteger)initSource
{
    self.appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil || self.appId == nil)
    {
        [self AdConfigError];
        return;;
    }
    self.videoMute = YES;
    if([item.config valueForKey:@"videoMute"])
    {
        self.videoMute = [item.config[@"videoMute"] boolValue];
    }
    [[CustomGMSDKLoader sharedInstance] initWithAppID:self.appId delegate:self];
}

- (void)loadAd
{
    [[CustomGMSDKLoader sharedInstance] setPersonalizedAd];
    BURewardedVideoModel *model = [[BURewardedVideoModel alloc] init];
    //设置服务器奖励验证数据 user_id
    if(self.waterfallItem.serverSideUserID != nil
       && self.waterfallItem.serverSideUserID.length > 0)
    {
        NSString *userID = self.waterfallItem.serverSideUserID;
        model.userId = userID;
    }
    else{
        model.userId = self.appId;
    }
    if(self.waterfallItem.serverSideCustomData != nil
       && self.waterfallItem.serverSideCustomData.length > 0)
    {
        model.extra = self.waterfallItem.serverSideCustomData;
    }
    BUAdSlot *slot = [[BUAdSlot alloc] init];
    slot.ID = self.placementId;
    slot.mediation.mutedIfCan = self.videoMute;
    self.expressRewardedVideoAd = [[BUNativeExpressRewardedVideoAd alloc] initWithSlot:slot rewardedVideoModel:model];
    self.expressRewardedVideoAd.delegate = self;
    self.expressRewardedPlayAgainObj = [[CustomGMExpressRewardedPlayAgain alloc] init];
    self.expressRewardedPlayAgainObj.rewardedAdapter = self;
    self.expressRewardedVideoAd.rewardPlayAgainInteractionDelegate = self.expressRewardedPlayAgainObj;
    [self.expressRewardedVideoAd loadAdData];
}

- (void)initFinish
{
    [self loadAd];
}

- (void)initFailWithError:(NSError *)error
{
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Init Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.localizedDescription];
        }
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)showAdFromRootViewController:(UIViewController *)rootViewController
{
    [self.expressRewardedVideoAd showAdFromRootViewController:rootViewController];
}

- (BOOL)isReady
{
    return self.expressRewardedVideoAd.mediation.isReady;
}

- (id)getCustomObject
{
    return self.expressRewardedVideoAd;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)loadAdC2SBidding
{
    if([self isReady])
    {
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"CustomGM.rewarded" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S rewarded not ready"}];
        [self AdLoadFailWithError:loadError];
    }
}

- (void)finishC2SBiddingWithEcpmStr:(NSString *)ecpmStr
{
    NSString *version = [BUAdSDKManager SDKVersion];
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{@"ecpm":ecpmStr,@"version":version};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFinish" info:dic];
}

- (void)failC2SBiddingWithErrorStr:(NSString *)errorStr
{
    NSDictionary *dic = @{@"error":errorStr};
    [self ADLoadExtraCallbackWithEvent:@"C2SBiddingFail" info:dic];
}

#pragma mark - BUMNativeExpressRewardedVideoAdDelegate
// 广告加载成功
- (void)nativeExpressRewardedVideoAdDidLoad:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    if(self.isC2SBidding)
    {
        NSString *ecpmStr = nil;
        if(rewardedVideoAd.mediation != nil)
        {
            ecpmStr = [CustomGMECPM getECPMWithMediation:rewardedVideoAd.mediation];
        }
        if(ecpmStr != nil)
        {
            [self finishC2SBiddingWithEcpmStr:ecpmStr];
        }
        else
        {
            NSString *errorStr = @"C2S Bidding Fail,can not get ecpm";
            [self failC2SBiddingWithErrorStr:errorStr];
        }
    }
    else
    {
        [self AdLoadFinsh];
    }
}

- (void)nativeExpressRewardedVideoAd:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    if(self.isC2SBidding)
    {
        NSString *errorStr = @"C2S Bidding Fail";
        if(error != nil)
        {
            errorStr = [NSString stringWithFormat:@"errCode: %ld, errMsg: %@", (long)error.code, error.description];
        }
        [self failC2SBiddingWithErrorStr:errorStr];
    }
    else
    {
        [self AdLoadFailWithError:error];
    }
}

- (void)nativeExpressRewardedVideoAdDidDownLoadVideo:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    
}

- (void)nativeExpressRewardedVideoAdDidShowFailed:(BUNativeExpressRewardedVideoAd *_Nonnull)rewardedVideoAd error:(NSError *_Nonnull)error
{
    [self AdShowFailWithError:error];
}

- (void)nativeExpressRewardedVideoAdDidVisible:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)nativeExpressRewardedVideoAdDidClose:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    if (self.shouldReward || !self.isSkip)
        [self AdRewardedWithInfo:self.rewardDic];
    [self AdClose];
}

// 广告被点击
- (void)nativeExpressRewardedVideoAdDidClick:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    [self AdClick];
}

// 广告被点击跳过
- (void)nativeExpressRewardedVideoAdDidClickSkip:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd
{
    self.isSkip = YES;
}

// 广告视频播放完成
- (void)nativeExpressRewardedVideoAdDidPlayFinish:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error
{
    if(error != nil)
    {
        [self AdShowFailWithError:error];
        return;
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

// 广告奖励下发
- (void)nativeExpressRewardedVideoAdServerRewardDidSucceed:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd verify:(BOOL)verify
{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"rewardId"] = rewardedVideoAd.rewardedVideoModel.userId;
    dic[@"rewardName"] = rewardedVideoAd.rewardedVideoModel.rewardName;
    dic[@"rewardNumber"] = @(rewardedVideoAd.rewardedVideoModel.rewardAmount);
    self.rewardDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    self.shouldReward = YES;
}

// 广告奖励下发失败
- (void)nativeExpressRewardedVideoAdServerRewardDidFail:(BUNativeExpressRewardedVideoAd *)rewardedVideoAd error:(NSError *_Nullable)error
{
    
}

@end
