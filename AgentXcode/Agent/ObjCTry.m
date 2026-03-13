#import "ObjCTry.h"

BOOL ObjCTry(void (NS_NOESCAPE ^_Nonnull block)(void)) {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}
