#import <Foundation/Foundation.h>

/// Executes a block, catching any ObjC exception. Returns YES on success, NO if an exception was thrown.
BOOL ObjCTry(void (NS_NOESCAPE ^_Nonnull block)(void));

/// Safely invoke a selector on an NSObject, returning the result only if the method
/// returns an object type ('@'). Primitives return nil (use KVC for those).
/// Catches ObjC exceptions — never crashes.
id _Nullable ObjCSafePerform(NSObject *_Nonnull obj, SEL _Nonnull sel);
