#import "CustomGMBannerAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <BUAdSDK/BUAdSDK.h>
#import "CustomGMSDKLoader.h"
#import "CustomGMECPM.h"

@interface CustomGMBannerAdapter ()<BUMNativeExpressBannerViewDelegate,CustomGMLoaderDelegate>

@property (nonatomic, strong) BUNativeExpressBannerView *bannerAd;
@property (nonatomic, copy) NSString *placementId;

@property (nonatomic, assign) NSInteger bannerSize;
//是否静音 默认静音
@property (nonatomic, assign) BOOL videoMute;
//横幅尺寸 1 = 320x50 默认 ；2 = 320x100 ；3 = 300x250 ；4 = 468x60 ；5=728x90
@property (nonatomic, assign) BOOL isC2SBidding;
@end

@implementation CustomGMBannerAdapter


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
    if([item.config valueForKey:@"bannerSize"])
    {
        self.bannerSize = [item.config[@"bannerSize"] integerValue];
    }
    [[CustomGMSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (CGSize)getAdSize
{
    CGFloat width = 320;
    CGFloat height = 50;
    switch (self.bannerSize)
    {
        case 2:
        {
            width = 320;
            height = 100;
            break;
        }
        case 3:
        {
            width = 300;
            height = 250;
            break;
        }
        case 4:
        {
            width = 468;
            height = 60;
            break;
        }
        case 5:
        {
            width = 728;
            height = 90;
            break;
        }
    }
    return CGSizeMake(width, height);;
}

- (void)loadAd
{
    [[CustomGMSDKLoader sharedInstance] setPersonalizedAd];
    CGSize size = CGSizeZero;
    //自定义尺寸
    if(self.waterfallItem.bannerSize.width > 0
       && self.waterfallItem.bannerSize.height > 0)
    {
        size = self.waterfallItem.bannerSize;
    }
    else
    {
        size = [self getAdSize];
    }
    BUAdSlot *slot = [[BUAdSlot alloc] init];
    slot.ID = self.placementId;
    slot.mediation.mutedIfCan = self.videoMute;
    self.bannerAd = [[BUNativeExpressBannerView alloc] initWithSlot:slot rootViewController:self.waterfallItem.bannerRootViewController adSize:size];
    self.bannerAd.delegate = self;
    [self.bannerAd loadAdData];
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
    return self.bannerAd.mediation.isReady;
}

- (id)getCustomObject
{
    return self.bannerAd;
}

- (void)bannerDidAddSubView:(UIView *)subView
{
    [self setBannerCenterWithBanner:self.bannerAd subView:subView];
    [self AdShow];
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
        NSError *loadError = [NSError errorWithDomain:@"CustomGM.banner" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S Banner not ready"}];
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

#pragma mark- BUNativeExpressBannerViewDelegate

- (void)nativeExpressBannerAdViewDidLoad:(BUNativeExpressBannerView *)bannerAdView
{
    if(self.isC2SBidding)
    {
        NSString *ecpmStr = nil;
        if(bannerAdView.mediation != nil)
        {
            ecpmStr = [CustomGMECPM getECPMWithMediation:bannerAdView.mediation];
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

- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)bannerAdView didLoadFailWithError:(NSError *_Nullable)error
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

- (void)nativeExpressBannerAdViewRenderSuccess:(BUNativeExpressBannerView *)bannerAdView
{
}

- (void)nativeExpressBannerAdViewRenderFail:(BUNativeExpressBannerView *)bannerAdView error:(NSError * __nullable)error
{
    [self AdShowFailWithError:error];
}


- (void)nativeExpressBannerAdViewWillBecomVisible:(BUNativeExpressBannerView *)bannerAdView
{
}

- (void)nativeExpressBannerAdViewDidClick:(BUNativeExpressBannerView *)bannerAdView
{
    [self AdClick];
}

- (void)nativeExpressBannerAdViewDidRemoved:(BUNativeExpressBannerView *)bannerAdView
{
    [self AdClose];
}

@end
