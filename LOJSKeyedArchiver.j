/*
 * LOJSKeyedArchiver.j
 *
 * Created by Martin Carlberg on Feb 29, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPCoder.j>

var LOJSKeyedArchiverClassKey = @"_type";

@implementation LOJSKeyedArchiver : CPCoder {
    id    _js;
}

+ (id)archivedDataWithRootObject:(id)rootObject {
    var js = {};
    var archiver = [[self alloc] initForWritingWithMutableData:js];
    
    return [archiver _encodeObject:rootObject];
}

+ (BOOL)allowsKeyedCoding {
    return YES;
}

- (id)initForWritingWithMutableData:(id)js {
    if (self = [super init])
    {
        _js = js;
    }
    return self;
}

- (void)encodeObject:(id)objectToEncode forKey:(CPString)aKey {
    _js[aKey] = [self _encodeObject:objectToEncode];
}

- (id)_encodeObject:(id)objectToEncode {
    var encodedJS = {};
    if ([self _isObjectAPrimitive:objectToEncode]) {
        encodedJS = objectToEncode;
    } else if ([objectToEncode isKindOfClass:[CPArray class]]) { // Override CPArray's default encoding because we want native JS Objects
        var encodedArray = [];
        for (var i = 0; i < [objectToEncode count]; i++) {
            encodedArray[i] = [self _encodeObject:[objectToEncode objectAtIndex:i]];
        }
        encodedJS = encodedArray;
    } else if ([objectToEncode isKindOfClass:[CPDictionary class]]) { // Override CPDictionary's default encoding because we want native JS Objects
        var encodedDictionary = {};
        var keys = [objectToEncode allKeys];
        for (var i = 0; i < [keys count]; i++) {
            var key = [keys objectAtIndex:i];
            encodedDictionary[key] = [self _encodeObject:[objectToEncode objectForKey:key]];
        }
        encodedJS = encodedDictionary;
    } else if (objectToEncode === [CPNull null]) { // Override CPNull's default encoding because we want native JS Objects
        encodedJS = nil;
    } else {
        var archiver = [[[self class] alloc] initForWritingWithMutableData:encodedJS];
        
//        encodedJS[LOJSKeyedArchiverClassKey] = [objectToEncode loObjectType];
        [objectToEncode encodeWithCoder:archiver];
    }

    return encodedJS;
}

- (void)encodeNumber:(int)aNumber forKey:(CPString)aKey {
    [self encodeObject:aNumber forKey:aKey];
}

- (void)encodeBool:(BOOL) aBOOL forKey:(CPString) aKey {
    [self encodeObject:aBOOL ? @"Yes" : "No" forKey:aKey];
}

- (void)encodeInt:(int)anInt forKey:(CPString)aKey {
    [self encodeObject:anInt forKey:aKey];
}

- (id)_encodeDictionaryOfObjects:(CPDictionary)dictionaryToEncode forKey:(CPString)aKey {
    var encodedDictionary = {};
    
    var keys = [dictionaryToEncode allKeys];
    for (var i = 0; i < [keys count]; i++)
    {
        encodedDictionary[keys[i]] = [self _encodeObject:[dictionaryToEncode objectForKey:keys[i]]];
    }
    
    _js[aKey] = encodedDictionary;
}

- (BOOL)_isObjectAPrimitive:(id)anObject {
    var typeOfObject = typeof(anObject);
    return (typeOfObject === "string" || typeOfObject === "number" || typeOfObject === "boolean" || anObject === null);
}

@end
