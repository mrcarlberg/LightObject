/*
 * Created by Kjell Nilsson on Jun 27, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>

LOValidationErrorKeyString = @"LOValidationErrorKeyString";
LOObjectValidationDomainString = @"LOObjectValidationDomainString";

@implementation LOError : CPObject {
    int code @accessors;
    CPString domain @accessors;
    CPDictionary userInfo @accessors;
}

+ (CPString)LOObjectValidationDomainString {
	return LOObjectValidationDomainString;
}

+ (CPString)LOValidationErrorKeyString {
	return LOValidationErrorKeyString;
}

+ (id)errorWithDomain:(CPString)aDomain code:(int)aCode userInfo:(CPDictionary)aUserInfo {
	return [[LOError alloc] initWithDomain:aDomain code:aCode userInfo:aUserInfo];
}

- (id)initWithDomain:(CPString)aDomain code:(int)aCode userInfo:(CPDictionary)aUserInfo {
	self = [super init];
	if (self) {
		domain = aDomain;
		code = aCode;
		userInfo = aUserInfo;
	}
	return self;
}

@end