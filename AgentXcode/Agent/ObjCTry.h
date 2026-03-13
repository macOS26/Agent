#import <Foundation/Foundation.h>

/// Executes a block, catching any ObjC exception. Returns YES on success, NO if an exception was thrown.
BOOL ObjCTry(void (NS_NOESCAPE ^_Nonnull block)(void));
