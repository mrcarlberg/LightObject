/*
 * LOSimpleJSONObjectStore.j
 *
 * Created by Martin Carlberg on Mars 5, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectStore.j"

@implementation LOObjectStore : CPObject {
}

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

/*
 * Must call [objectContext objectsReceived: withFetchSpecification:] when objects are received
 */
- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*
 * Must call [objectContext setModifiedObjects:[CPArray array]] before return
 */
- (void) saveChangesWithObjectContext:(LOObjectContext) objectContext {
    [objectContext setModifiedObjects:[CPArray array]];
}

/*
 * Must return an array with keys for all attributes for this object
 */
- (CPArray) attributeKeysForObject:(id) theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*
 * Returns the type of the object
 */
- (CPString) typeOfObject:(id) theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*
 * Returns a unique id for the object
 */
- (CPString) globalIdForObject:(id) theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

@end
