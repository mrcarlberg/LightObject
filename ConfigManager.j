/*
 * Created by Martin Carlberg on July 9, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>

var _sharedInstance = nil;

@implementation ConfigManager : CPObject {
    configBaseUrl;
}

+ (ConfigManager) sharedInstance {
    if (!_sharedInstance) {
        _sharedInstance = [[ConfigManager alloc] init];
    }
    return _sharedInstance;
}

- (CPString) configBaseUrl {
    return configBaseUrl;
}

- (id)init {
    self = [super init];
    
    if (self) {
        var mainBundle = [CPBundle mainBundle];
        var bundleURL = [[mainBundle bundleURL] absoluteURL];
        var configURL = [CPURL URLWithString:@"../../Config/Config" relativeToURL:bundleURL];
        CPLog.trace(_cmd + @" configURLPath: " + configURL);
        var answer = [CPURLConnection sendSynchronousRequest:[CPURLRequest requestWithURL:configURL] returningResponse:nil];
        if (answer) {
            CPLog.trace(_cmd + @" configURL: " + [answer rawString]);
            configBaseUrl = [answer rawString];
        }
    }
    
    return self;
}

@end
