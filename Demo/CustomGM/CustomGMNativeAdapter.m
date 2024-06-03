#import "CustomGMNativeAdapter.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import "CustomGMSDKLoader.h"
#import <BUAdSDK/BUAdSDK.h>
#import "CustomGMECPM.h"

@interface CustomGMNativeAdapter()<BUMNativeAdsManagerDelegate,BUMNativeAdDelegate,CustomGMLoaderDelegate>

@property (nonatomic, strong) BUNativeAdsManager *nativeAdManager;
@property (nonatomic, strong) BUNativeAd *nativeAd;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, assign) BOOL isC2SBidding;
//是否静音
@property (nonatomic, assign) BOOL videoMute;
@end

@implementation CustomGMNativeAdapter

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
    [self loadNativeAdWithPlacementId:self.placementId];
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
    return self.nativeAd.mediation.isReady;
}

- (id)getCustomObject
{
    return self.nativeAd;
}

#pragma mark - NativeAd

- (void)loadNativeAdWithPlacementId:(NSString *)placementId
{
    [[CustomGMSDKLoader sharedInstance] setPersonalizedAd];
    BUAdSlot *slot = [[BUAdSlot alloc] init];
    slot.ID = placementId;
    BUSize *imgSize = [BUSize sizeBy:BUProposalSize_Feed690_388];
    slot.imgSize = imgSize;
    slot.adSize = self.waterfallItem.templateRenderSize;
    slot.mediation.mutedIfCan = self.videoMute;
    self.nativeAdManager = [[BUNativeAdsManager alloc] initWithSlot:slot];
    self.nativeAdManager.delegate = self;
    self.nativeAdManager.mediation.rootViewController = self.waterfallItem.nativeRootViewController;
    [self.nativeAdManager loadAdDataWithCount:1];
}

- (void)templateRender:(UIView *)subView
{
    if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
    {
        self.nativeAd.mediation.canvasView.frame = subView.bounds;
    }
    else//TPTemplateContentModeCenter
    {
        CGPoint center = CGPointZero;
        center.x = CGRectGetWidth(subView.bounds)/2;
        center.y = CGRectGetHeight(subView.bounds)/2;
        self.nativeAd.mediation.canvasView.center = center;
    }
    [self.nativeAd.mediation render];
}

- (UIView *)endRender:(NSDictionary *)viewInfo clickView:(NSArray *)array
{
    UIView *adView = viewInfo[kTPRendererAdView];
    [self.nativeAd registerContainer:adView withClickableViews:array];
    return nil;
}

#pragma mark - C2SBidding

- (void)initSDKC2SBidding
{
    self.isC2SBidding = YES;
    [self initSDKWithWaterfallItem:self.waterfallItem initSource:2];
}

- (void)loadAdC2SBidding
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if([self isReady])
    {
        [self AdLoadFinsh];
    }
    else
    {
        NSError *loadError = [NSError errorWithDomain:@"CustomGM.native" code:404 userInfo:@{NSLocalizedDescriptionKey : @"C2S native not ready"}];
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

#pragma mark - BUNativeAdsManagerDelegate
- (void)nativeAdsManagerSuccessToLoad:(BUNativeAdsManager *)adsManager nativeAds:(NSArray<BUNativeAd *> *)nativeAdDataArray
{
    TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
    if(nativeAdDataArray != nil && nativeAdDataArray.count > 0)
    {
        self.nativeAd = nativeAdDataArray.firstObject;
        self.nativeAd.delegate = self;
        self.nativeAd.rootViewController = self.waterfallItem.nativeRootViewController;
        if(self.nativeAd.mediation.isExpressAd)
        {
            res.adView = self.nativeAd.mediation.canvasView;
        }
        else
        {
            BUMaterialMeta *data = self.nativeAd.data;
            res.title = data.AdTitle;
            res.body = data.AdDescription;
            res.ctaText = data.buttonText;
            res.rating = @(data.score);
            res.commentNum = data.commentNum;
            res.source = data.source;
            res.videoUrl = data.videoUrl;
            res.videoDuration = data.videoDuration;
            res.extraInfo[@"aspectRatio"] = @(data.videoResolutionWidth/data.videoResolutionHeight);
            if(data.icon.imageURL != nil)
            {
                res.iconImageURL = [NSString stringWithFormat:@"%@",data.icon.imageURL];
                [self.downLoadURLArray addObject:res.iconImageURL];
            }
            if(data.mediation.adLogo != nil)
            {
                if(data.mediation.adLogo.mediation.image != nil)
                {
                    res.adChoiceImage = data.mediation.adLogo.mediation.image;
                }
                else if(data.mediation.adLogo.imageURL != nil)
                {
                    res.adChoiceImageURL = data.mediation.adLogo.imageURL;
                }
                res.adChoiceView.contentMode = UIViewContentModeScaleAspectFit;
            }
            if (data.imageMode == BUMMediatedNativeAdModeLandscapeVideo ||
                data.imageMode == BUMMediatedNativeAdModePortraitVideo)
            {
                res.mediaView = self.nativeAd.mediation.canvasView.mediaView;
            }
            else
            {
                if(data.imageAry != nil && data.imageAry.count > 0)
                {
                    BUImage *image = data.imageAry.firstObject;
                    res.mediaImageURL = [NSString stringWithFormat:@"%@",image.imageURL];
                    [self.downLoadURLArray addObject:res.mediaImageURL];
                    if(data.imageAry.count > 1)
                    {
                        NSMutableArray *urlArray = [[NSMutableArray alloc] init];
                        for(BUImage *image in data.imageAry)
                        {
                            if(image.imageURL != nil)
                            {
                                [urlArray addObject:image.imageURL];
                            }
                        }
                        if(urlArray.count > 0)
                        {
                            res.imageURLList = urlArray;
                        }
                    }
                }
            }
        }
    }
    self.waterfallItem.adRes = res;
    if(self.isC2SBidding)
    {
        NSString *ecpmStr = nil;
        if(self.nativeAd.mediation != nil)
        {
            ecpmStr = [CustomGMECPM getECPMWithMediation:adsManager.mediation];
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


- (void)nativeAdsManager:(BUNativeAdsManager *_Nonnull)adsManager didFailWithError:(NSError *_Nullable)error
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

#pragma mark BUNativeAdViewDelegate
- (void)nativeAdExpressViewRenderSuccess:(BUNativeExpressAdView *_Nonnull)nativeExpressAdView
{
    
}

- (void)nativeAdExpressViewRenderFail:(BUNativeExpressAdView *_Nonnull)nativeExpressAdView error:(NSError *_Nullable)error
{
    [self AdShowFailWithError:error];
}

- (void)nativeAdDidBecomeVisible:(BUNativeExpressAdView *_Nonnull)nativeAdView
{
    [self AdShow];
}

- (void)nativeAdExpressView:(BUNativeExpressAdView *_Nonnull)nativeAdView stateDidChanged:(BUPlayerPlayState)playerState
{
}

- (void)nativeAdDidClick:(BUNativeExpressAdView *_Nonnull)nativeAdView withView:(UIView *_Nullable)view
{
    [self AdClick];
}

- (void)nativeAdViewWillPresentFullScreenModal:(BUNativeExpressAdView *_Nonnull)nativeAdView
{
    
}

- (void)nativeAdExpressViewDidClosed:(BUNativeExpressAdView *_Nullable)nativeAdView closeReason:(NSArray<NSDictionary *> *_Nullable)filterWords
{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"dislikeInfo"] = @"用户关闭";
    if(filterWords != nil && filterWords.count >0)
    {
        NSDictionary *dislikeDic = filterWords[0];
        if([dislikeDic valueForKey:@"dislike_words"])
        {
            if([dislikeDic[@"dislike_words"] isKindOfClass:[NSArray class]])
            {
                NSArray * arr = dislikeDic[@"dislike_words"];
                if(arr != nil && arr.count >0)
                {
                    dic[@"dislikeInfo"] = arr[0];
                }
                else
                {
                    return;
                }
            }
        }
        dic[@"dislikeObject"] = filterWords;
        [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
    }
    else
    {
        [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
    }
}

#pragma mark BUNativeAdVideoDelegate

- (void)nativeAdVideoDidClick:(BUNativeExpressAdView *_Nullable)nativeAdView
{
    [self AdClick];
}

- (void)nativeAdVideoDidPlayFinish:(BUNativeExpressAdView *_Nullable)nativeAdView
{
    [self ADShowExtraCallbackWithEvent:@"tradplus_play_end" info:nil];
}

- (void)nativeAdShakeViewDidDismiss:(BUNativeAd * _Nullable)nativeAd
{
    
}


- (void)nativeAdVideo:(BUNativeAd * _Nullable)nativeAdView rewardDidCountDown:(NSInteger)countDown
{
}


- (void)nativeAdVideo:(BUNativeAd * _Nullable)nativeAd stateDidChanged:(BUPlayerPlayState)playerState
{
    if (playerState == BUPlayerStatePlaying)
        [self ADShowExtraCallbackWithEvent:@"tradplus_play_begin" info:nil];
}


- (void)nativeAdWillPresentFullScreenModal:(BUNativeAd * _Nonnull)nativeAd
{
}


- (void)nativeAd:(BUNativeAd *)nativeAd dislikeWithReason:(NSArray<BUDislikeWords *> *)filterWords
{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    dic[@"dislikeInfo"] = @"用户关闭";
    if(filterWords != nil && filterWords.count >0)
    {
        BUDislikeWords *dislikeDic = filterWords.firstObject;
        dic[@"dislikeInfo"] = dislikeDic.name;
        dic[@"dislikeObject"] = filterWords;
        [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
    }
    else
    {
        [self ADShowExtraCallbackWithEvent:@"tradplus_native_dislike" info:dic];
    }
}
@end
