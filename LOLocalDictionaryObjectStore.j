/*
 * Created by Martin Carlberg on Juli 18, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectStore.j"

@implementation LOLocalDictionaryObjectStore : LOObjectStore {
    CPMutableDictionary     objectFixture @accessors;
}

- (id)init {
    self = [super init];
    if (self) {
        objectFixture = [CPMutableDictionary dictionary];
    }
    return self;
}

/*!
 * Must call [objectContext objectsReceived: withFetchSpecification:] when objects are received
 */
- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    var fixtureObjects = [objectFixture objectForKey:[fetchSpecification entityName]];
    var objects = [];

    if (fixtureObjects) {
        var predicate = [fetchSpecification qualifer];

        if (predicate) {
            objects = [fixtureObjects filteredArrayUsingPredicate:predicate];
        } else {
            objects = [fixtureObjects copy];
        }
    }
    [objectContext objectsReceived:objects withFetchSpecification:fetchSpecification];
}

/*!
 * This method should save all changes to the backend.
 * The ObjectContext has a list of LOModifyRecord that contains all changes.
 * Must call [objectContext saveChangesDidComplete] when done
 */
- (void) saveChangesWithObjectContext:(LOObjectContext) objectContext {
    [objectContext saveChangesDidComplete];
}

/*!
 * Must return an array with keys for all attributes for this object.
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray) attributeKeysForObject:(id) theObject {
    return [[theObject allKeys] deleteObject:@"entity"];
}

/*!
 * Returns the type of the object
 */
- (CPString) typeOfObject:(id) theObject {
    return [theObject objectForKey:@"entity"];
}

/*!
 * Returns a unique id for the object
 */
- (CPString) globalIdForObject:(id) theObject {
    return [theObject UID];
}

@end
