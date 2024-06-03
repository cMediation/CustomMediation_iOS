#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <TradPlusAds/TPSDKLoaderDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CustomGMLoaderDelegate <NSObject>

- (void)initFinish;
- (void)initFailWithError:(NSError *)error;

@end;

@interface CustomGMSDKLoader : NSObject

+ (CustomGMSDKLoader *)sharedInstance;
- (void)initWithAppID:(NSString *)appID
                 delegate:(nullable id <CustomGMLoaderDelegate>)delegate;

+ (NSString *)getSDKVersion;
//个性化广告设置
- (void)setPersonalizedAd;
@property (nonatomic,assign)BOOL didInit;
@end
NS_ASSUME_NONNULL_END
