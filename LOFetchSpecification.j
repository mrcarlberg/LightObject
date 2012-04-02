/*
 * LOFetchSpecification.j
 *
 * Created by Martin Carlberg on Feb 27, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>

@implementation LOFetchSpecification : CPObject
{
    CPString        entityName  @accessors;
}

+ (LOFetchSpecification) fetchSpecificationForEnityName:(CPString) anEntityName {
    return [[LOFetchSpecification alloc] initWithEntityName:anEntityName];
}

- (id)initWithEntityName:(CPString) anEntityName {
    self = [super init];
    if (self) {
        entityName = anEntityName;
    }
    return self;
}

@end