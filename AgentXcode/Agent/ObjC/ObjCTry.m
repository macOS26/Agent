#import "ObjCTry.h"

BOOL ObjCTry(void (NS_NOESCAPE ^_Nonnull block)(void)) {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}

id _Nullable ObjCSafePerform(NSObject *_Nonnull obj, SEL _Nonnull sel) {
    @try {
        NSMethodSignature *sig = [obj methodSignatureForSelector:sel];
        if (!sig) return nil;

        // Only proceed if the return type is an object ('@')
        const char *returnType = [sig methodReturnType];
        if (returnType[0] != '@') return nil;

        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setSelector:sel];
        [inv setTarget:obj];
        [inv invoke];

        __unsafe_unretained id result = nil;
        [inv getReturnValue:&result];
        return result;
    } @catch (NSException *exception) {
        return nil;
    }
}
