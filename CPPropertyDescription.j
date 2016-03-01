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
    BOOL _isTransient;
    CPEntityDescription _entity @accessors(property=entity);
    CPDictionary _userInfo @accessors(property=userInfo);
}

- (BOOL)isOptional
{
    return _isOptional;
}

- (void)setOptional:(BOOL)isOptional
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

- (BOOL)isTransient
{
    return _isTransient;
}

- (void)setTransient:(BOOL)isTransient
{
    if(isTransient == null)
    {
        _isTransient = false;
    }
    else
    {
        _isTransient = isTransient;
    }
}

@end