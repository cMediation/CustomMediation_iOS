#import "CustomGMSplashAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "CustomGMSDKLoader.h"
#import "CustomGMECPM.h"

@interface CustomGMSplashAdapter ()<BUMSplashAdDelegate, BUSplashZoomOutDelegate,CustomGMLoaderDelegate>

@property (nonatomic, strong) BUSplashAd *splashAd;
@property (nonatomic, strong) BUSplashZoomOutView *zoomOutView;
@property (nonatomic, strong) UIView *bottomView;
@property (nonatomic, copy)   NSString *placementId;
@property (nonatomic, assign) BOOL isC2SBidding;
@property (nonatomic, assign) BOOL supportZoomOut;
@property (nonatomic, assign) NSTimeInterval tolerateTimeout;
//是否静音
@property (nonatomic, assign) BOOL videoMute;
@end

@implementation CustomGMSplashAdapter

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
    if([item.config valueForKey:@"supportZoomOut"])
    {
        self.supportZoomOut = [item.config[@"supportZoomOut"] boolValue];
    }
    if([item.config valueForKey:@"tolerateTimeout"])
    {
        self.tolerateTimeout = [item.config[@"tolerateTimeout"] doubleValue]/1000.0;
    }
    [[CustomGMSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[CustomGMSDKLoader sharedInstance] setPersonalizedAd];
    CGSize size = [UIScreen mainScreen].bounds.size;
    if(self.waterfallItem.splashBottomSize.height > 0)
    {
        size.height -= self.waterfallItem.splashBottomSize.height;
    }
    BUAdSlot *slot = [[BUAdSlot alloc] init];
    slot.ID = self.placementId;
    slot.mediation.mutedIfCan = YES;
    self.splashAd = [[BUSplashAd alloc] initWithSlot:slot adSize:size];
    self.splashAd.delegate = self;
    self.splashAd.zoomOutDelegate = self;
    self.splashAd.supportZoomOutView = self.supportZoomOut;
    if(self.tolerateTimeout > 0)
    {
        self.splashAd.tolerateTimeout = self.tolerateTimeout;
    }
    if (self.waterfallItem.splashBottomSize.width > 0 && self.waterfallItem.splashBottomSize.height > 0) {
        self.bottomView = [[UIView alloc] init];
        CGRect rect = CGRectZero;
        rect.size = self.waterfallItem.splashBottomSize;
        self.bottomView.frame = rect;
        self.splashAd.mediation.customBottomView = self.bottomView;
    }
    [self.splashAd loadAdData];
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

- (BOOL)isReady
{
    return self.splashAd.mediation.isReady;
}

- (id)getCustomObject
{
    return self.splashAd;
}

- (void)showAdInWindow:(UIWindow *)window bottomView:(UIView *)bottomView
{
    UIViewController *rootViewController = self.waterfallItem.splashWindow.rootViewController;
    if(self.splashAd.zoomOutView)
    {
        self.splashAd.zoomOutView.rootViewController = rootViewController;
    }
    if(self.bottomView != nil && bottomView != nil)
    {
        [self.bottomView addSubview:bottomView];
    }
    [self.splashAd showSplashViewInRootViewController:rootViewController];
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
        NSError *loadError = [NSError errorWithDomain:@"CustomGM.splash" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S splash not ready"}];
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

#pragma mark - BUSplashAdDelegate

- (void)splashAdLoadSuccess:(BUSplashAd *)splashAd
{
    if(self.isC2SBidding)
    {
        NSString *ecpmStr = nil;
        if(splashAd.mediation != nil)
        {
            ecpmStr = [CustomGMECPM getECPMWithMediation:splashAd.mediation];
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

- (void)splashAdLoadFail:(BUSplashAd *)splashAd error:(BUAdError * _Nullable)error
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

- (void)splashAdWillShow:(BUSplashAd *)splashAd
{
    [self AdShow];
}

- (void)splashAdRenderFail:(BUSplashAd *)splashAd error:(NSError *)error
{
    [self AdShowFailWithError:error];
}

- (void)splashAdDidClick:(BUSplashAd *)splashAd
{
    [self AdClick];
}

- (void)splashAdDidClose:(BUSplashAd *)splashAd closeType:(BUSplashAdCloseType)closeType
{
    if (closeType == BUSplashAdCloseType_ClickSkip)
    {
        [self ADShowExtraCallbackWithEvent:@"tradplus_splash_skip" info:nil];
    }
    if(!self.splashAd.zoomOutView)
    {
        [self AdClose];
        [self.splashAd.mediation destoryAd];
    }
    else {
        [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_show" info:nil];
    }
}

- (void)splashAdDidShow:(BUSplashAd *)splashAd 
{
}

- (void)splashAdRenderSuccess:(BUSplashAd *)splashAd 
{
}


- (void)splashAdViewControllerDidClose:(BUSplashAd *)splashAd 
{
}

- (void)splashDidCloseOtherController:(BUSplashAd *)splashAd interactionType:(BUInteractionType)interactionType
{
}

- (void)splashVideoAdDidPlayFinish:(BUSplashAd *)splashAd didFailWithError:(NSError *)error
{
}


#pragma mark - BUSplashZoomOutViewDelegate
- (void)splashZoomOutReadyToShow:(BUSplashAd *)splashAd
{
    if (self.splashAd.zoomOutView)
    {
        [self.splashAd showZoomOutViewInRootViewController:self.waterfallItem.splashWindow.rootViewController];
    }
}

- (void)splashZoomOutViewDidClick:(BUSplashAd *)splashAd
{
    [self AdClick];
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_close" info:nil];
    [self AdClose];
}

- (void)splashZoomOutViewDidClose:(BUSplashAd *)splashAd
{
    [self ADShowExtraCallbackWithEvent:@"tradplus_splash_zoom_close" info:nil];
    [self AdClose];
}

@end
