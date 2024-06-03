#import "CustomGMECPM.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

@implementation CustomGMECPM

+ (nullable NSString *)getECPMWithMediation:(id )mediation
{
    if(![mediation respondsToSelector:@selector(adapterToAdPackage)])
    {
        return nil;
    }
    id adapterToAdPackage = [mediation performSelector:@selector(adapterToAdPackage)];
    if(![adapterToAdPackage isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    NSDictionary *list = adapterToAdPackage;
    return [self getEcpmWithList:list];
}

+ (nullable NSString *)getECPMWithFullscreenVideoAdMediation:(BUNativeExpressFullscreenVideoAdMediation *)mediation
{
    id intersitiial = nil;
    if([mediation respondsToSelector:@selector(intersitiialProAd)])
    {
        intersitiial = [mediation performSelector:@selector(intersitiialProAd)];
    }
    if(intersitiial == nil && [mediation respondsToSelector:@selector(fullscreenVideoAd)])
    {
        intersitiial = [mediation performSelector:@selector(fullscreenVideoAd)];
    }
    if(![intersitiial respondsToSelector:@selector(adapterToAdPackage)])
    {
        return nil;
    }
    id adapterToAdPackage = [intersitiial performSelector:@selector(adapterToAdPackage)];
    if(![adapterToAdPackage isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    NSDictionary *list = adapterToAdPackage;
    return [self getEcpmWithList:list];
}

+ (nullable NSString *)getEcpmWithList:(NSDictionary *)list
{
    __block double ecpmNumer = 0;
    [list enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if([obj respondsToSelector:@selector(ecpm)])
        {
            id ecpmItem = [obj performSelector:@selector(ecpm)];
            NSString *tempECPM = [NSString stringWithFormat:@"%@",ecpmItem];
            double tempNum = [tempECPM doubleValue];
            if(tempNum > ecpmNumer)
            {
                ecpmNumer = tempNum;
            }
        }
    }];
    if(ecpmNumer == 0)
    {
        return nil;
    }
    return [NSString stringWithFormat:@"%@",@(ecpmNumer/100.0)];
}

#pragma clang diagnostic pop
@end
