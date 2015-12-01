//
//  CPPropertyDescription.j
//
//  Created by Raphael Bartolome on 15.10.09.
//

@import <Foundation/CPObject.j>

@class CPEntityDescription

CPPropertyDescriptionKey = "CPPropertyDescriptionKey";

@implementation CPPropertyDescription : CPObject
{
	CPString _name @accessors(property=name);
	BOOL _isOptional;
	CPEntityDescription _entity @accessors(property=entity);
	CPDictionary _userInfo @accessors(property=userInfo);
}

- (BOOL)isOptional
{
	return _isOptional;
}

- (void)setIsOptional:(BOOL)isOptional
{
	if(isOptional == null)
	{
		_isOptional = false;
	}
	else
	{
		_isOptional = isOptional;
	}
}
@end