#import "CustomGMInterstitialAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "CustomGMSDKLoader.h"
#import "CustomGMECPM.h"

@interface CustomGMInterstitialAdapter ()<BUMNativeExpressFullscreenVideoAdDelegate,CustomGMLoaderDelegate>

@property (nonatomic, strong) BUNativeExpressFullscreenVideoAd *expressFullscreenVideoAd;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL isC2SBidding;
//是否静音
@property (nonatomic, assign) BOOL videoMute;
@end

@implementation CustomGMInterstitialAdapter

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
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(self.placementId == nil || appId == nil)
    {
        [self AdConfigError];
        return;
    }
    self.videoMute = YES;
    if([item.config valueForKey:@"videoMute"])
    {
        self.videoMute = [item.config[@"videoMute"] boolValue];
    }
    [[CustomGMSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[CustomGMSDKLoader sharedInstance] setPersonalizedAd];
    BUAdSlot *slot = [[BUAdSlot alloc] init];
    slot.ID = self.placementId;
    slot.mediation.mutedIfCan = self.videoMute;
    self.expressFullscreenVideoAd = [[BUNativeExpressFullscreenVideoAd alloc] initWithSlot:slot];
    self.expressFullscreenVideoAd.delegate = self;
    [self.expressFullscreenVideoAd loadAdData];
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
    [self.expressFullscreenVideoAd showAdFromRootViewController:rootViewController];
}

- (BOOL)isReady
{
    return self.expressFullscreenVideoAd.mediation.isReady;
}

- (id)getCustomObject
{
    return self.expressFullscreenVideoAd;
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
        NSError *loadError = [NSError errorWithDomain:@"CustomGM.interstitial" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S interstitial not ready"}];
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

#pragma mark - BUNativeExpressFullscreenVideoAdDelegate

- (void)nativeExpressFullscreenVideoAdDidDownLoadVideo:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    if(self.isC2SBidding)
    {
        NSString *ecpmStr = nil;
        if(fullscreenVideoAd.mediation != nil)
        {
            ecpmStr = [CustomGMECPM getECPMWithFullscreenVideoAdMediation:fullscreenVideoAd.mediation];
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
        self.isAdReady = YES;
        [self AdLoadFinsh];
    }
}

- (void)nativeExpressFullscreenVideoAd:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
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

- (void)nativeExpressFullscreenVideoAdViewRenderSuccess:(BUNativeExpressFullscreenVideoAd *)rewardedVideoAd
{
    
}

- (void)nativeExpressFullscreenVideoAdViewRenderFail:(BUNativeExpressFullscreenVideoAd *)rewardedVideoAd error:(NSError *_Nullable)error
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

- (void)nativeExpressFullscreenVideoAdDidPlayFinish:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error
{
    if(error != nil)
    {
        [self AdShowFailWithError:error];
        return;
    }
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)nativeExpressFullscreenVideoAdDidVisible:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    [self AdShow];
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}

- (void)nativeExpressFullscreenVideoAdDidClick:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    [self AdClick];
}

- (void)nativeExpressFullscreenVideoAdDidClose:(BUNativeExpressFullscreenVideoAd *)fullscreenVideoAd
{
    [self AdClose];
}

@end
