/*
 * Created by Martin Carlberg on July 8, 2013.
 * Copyright 2013, Your Company All rights reserved.
 */

@import <Foundation/CPArray.j>
@import <Foundation/CPPredicate.j>
@import "LOFault.j"


@implementation LOFaultObject : CPObject <LOFault> {
    LOObjectContext objectContext @accessors;
    id              masterObject @accessors;
    CPString        relationshipKey @accessors;
    BOOL            faultFired @accessors;
    BOOL            faultPopulated @accessors;
    CPString        primaryKey @accessors;
}

+ (LOFaultObject)faultObjectWithObjectContext:(CPObjectContext)anObjectContext masterObject:(id)aMasterObject relationshipKey:(CPString)aRelationshipKey primaryKey:(CPString)aPrimaryKey {
    return [[LOFaultObject alloc] initWithObjectContext:anObjectContext masterObject:aMasterObject relationshipKey:aRelationshipKey primaryKey:aPrimaryKey];
}

- (id)initWithObjectContext:(CPObjectContext)anObjectContext masterObject:(id)aMasterObject relationshipKey:(CPString)aRelationshipKey primaryKey:(CPString)aPrimaryKey {
    self = [super init];
    if (self) {
        faultFired = NO;
        objectContext = anObjectContext;
        masterObject = aMasterObject;
        relationshipKey = aRelationshipKey;
        primaryKey = aPrimaryKey;
    }
    return self;
}

- (id)copy {
    var copy = [super copy];
    copy.objectContext = self.objectContext;
    copy.masterObject = self.masterObject;
    copy.relationshipKey = self.relationshipKey;
    copy.primaryKey = self.primaryKey;
    copy.faultFired = self.faultFired;
    copy.faultPopulated = self.faultPopulated;
    return copy;
}
/*
- (id)_handleObserverForKeyPath:(CPString)aKeyPath {
    return (@"faultFired" === aKeyPath || @"faultPopulated" === aKeyPath)
}

- (void)addObserver:(id)observer forKeyPath:(CPString)aKeyPath options:(unsigned)options context:(id)context {
    if ([self _handleObserverForKeyPath:aKeyPath]) {
        [[_CPKVOProxy proxyForObject:self] _addObserver:observer forKeyPath:aKeyPath options:options context:context]
    } else {
        [array addObserver:observer forKeyPath:aKeyPath options:options context:context];
    }
}

- (void)removeObserver:(id)observer forKeyPath:(CPString)aKeyPath {
    if ([self _handleObserverForKeyPath:aKeyPath]) {
        [[_CPKVOProxy proxyForObject:self] _removeObserver:observer forKeyPath:aKeyPath];
    } else {
        [array removeObserver:observer forKeyPath:aKeyPath];
    }
}*/

- (void)setValue:(id)aValue forKey:(CPString)aKey {
    if (@"faultFired" === aKey) {
        [self willChangeValueForKey:aKey];
        faultFired = aValue;
        [self didChangeValueForKey:aKey];
    } else if (@"faultPopulated" === aKey) {
        [self willChangeValueForKey:aKey];
        faultPopulated = aValue;
        [self didChangeValueForKey:aKey];
    } else {
        [self _requestFaultIfNecessary];
        // TODO: Save all the set values and maybe apply them later???
        [super setValue:aValue forKey:aKey];
    }
}

- (id)valueForKey:(CPString)aKey {
    if (@"faultFired" === aKey) {
        return faultFired;
    } else if (@"faultPopulated" === aKey) {
        return faultPopulated;
    }
    [self _requestFaultIfNecessary];
    // We do never have a valid value in the fault object so we just return nil
    return nil;
}

- (void)_requestFaultIfNecessary {
    if (!faultFired) {
        [self requestFaultWithCompletionBlock:nil];
    }
}

/*!
    This is hard coded: The relationshipKey from the master object is used as the entity name
    This can be changed when we are using a model.
 */
- (void) requestFaultWithCompletionBlock:(Function)aCompletionBlock {
    if (!faultFired) {
        faultFired = YES;
        faultPopulated = NO;
        var entityName = relationshipKey;
        var objectStore = [objectContext objectStore];
        var primaryKeyAttribute = [objectStore primaryKeyAttributeForType:entityName objectContext:objectContext];
        var foreignKey = [objectStore foreignKeyAttributeForToOneRelationshipAttribute:[objectContext typeOfObject:masterObject] forType:entityName objectContext:objectContext];
        var qualifier = [CPComparisonPredicate predicateWithLeftExpression:[CPExpression expressionForKeyPath:primaryKeyAttribute]
                                                           rightExpression:[CPExpression expressionForConstantValue:primaryKey]
                                                                  modifier:CPDirectPredicateModifier
                                                                      type:CPEqualToPredicateOperatorType
                                                                   options:0];
        var fs = [LOFetchSpecification fetchSpecificationForEntityNamed:entityName qualifier:qualifier];
        [objectContext requestFaultObject:self withFetchSpecification:fs withCompletionBlock:aCompletionBlock];
        [[CPNotificationCenter defaultCenter] postNotificationName:LOFaultDidFireNotification object:masterObject userInfo:[CPDictionary dictionaryWithObjects:[self, fs, relationshipKey] forKeys:[LOFaultKey,LOFaultFetchSpecificationKey, LOFaultFetchRelationshipKey]]];
        //console.log([self className] + " " + _cmd + " Fire fault: '" + entityName + "' q: " + [qualifier description]);
    } else if (aCompletionBlock) {
        if (faultPopulated) {
            aCompletionBlock(self);
        } else {
            [objectStore addCompletionBlock:aCompletionBlock toTriggeredFault:self];
        }
    }
}

- (id)faultReceivedWithObjects:(CPArray)objectList {
    [objectContext registerObjects:objectList];
    [masterObject willChangeValueForKey:relationshipKey];
    [masterObject setValue:objectList[0] forKey:relationshipKey];
    [masterObject didChangeValueForKey:relationshipKey];
    [self setFaultPopulated:YES];

    return objectList[0];
}

@end
