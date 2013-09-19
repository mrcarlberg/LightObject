/*
 * LOFetchSpecification.j
 *
 * Created by Martin Carlberg on Feb 27, 2012.
 * Copyright 2012, All rights reserved.
 */

@import <Foundation/CPObject.j>

@implementation LOFetchSpecification : CPObject
{
    CPString        entityName  @accessors;
    CPString        alias  @accessors; // This is user info for the object store. It can be used to fetch entityName from a function
    CPString        method  @accessors; // This is user info for the object store. It can be used to add to the url path
    CPString        operator  @accessors; // This is user info for the object store. It can be used to add to the url path
    CPPredicate     qualifier  @accessors;
    id              userInfo  @accessors;
    Function        requestPreProcessBlock @accessors; // This is a block that is called before the request is sent
}

+ (LOFetchSpecification) fetchSpecificationForEntityNamed:(CPString) anEntityName {
    return [[LOFetchSpecification alloc] initWithEntityName:anEntityName];
}

- (id)initWithEntityName:(CPString) anEntityName {
    self = [super init];
    if (self) {
        entityName = anEntityName;
    }
    return self;
}

+ (LOFetchSpecification) fetchSpecificationForEntityNamed:(CPString) anEntityName qualifier:(CPPredicate) aQualifier {
    return [[LOFetchSpecification alloc] initWithEntityName:anEntityName qualifier:aQualifier];
}

- (id)initWithEntityName:(CPString) anEntityName qualifier:(CPPredicate) aQualifier {
    self = [super init];
    if (self) {
        entityName = anEntityName;
        qualifier = aQualifier;
    }
    return self;
}

- (CPString)description {
    return [CPString stringWithFormat:@"<%@ entityName: %@ operator: %@ qualifer: %@ userInfo: %@>", [self className], entityName, operator, qualifier, userInfo];
}

@end
