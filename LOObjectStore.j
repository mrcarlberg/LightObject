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

/*!
 * Must call [objectContext objectsReceived: withFetchSpecification:] when objects are received
 */
- (CPArray)requestObjectsWithFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Must call [objectContext faultReceived:(CPArray)objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification faultArray:(LOFaultArray)faultArray] when fault objects are received
 */
- (CPArray)requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * This method should save all changes to the backend.
 * The ObjectContext has a list of LOModifyRecord that contains all changes.
 */
- (void)saveChangesWithObjectContext:(LOObjectContext) objectContext {
}

/*!
 * Must return an array with keys for all attributes for this object
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray)attributeKeysForObject:(id) theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Must return an array with keys for all to many relationship attributes for this object
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray)relationshipKeysForObject:(id) theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns the type of the object
 */
- (CPString)typeOfObject:(id) theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns a unique id for the object
 */
- (CPString)globalIdForObject:(id) theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns an url for saving the data. This method can also be overwritten to alter
 * the data before it is sent to the url.
 */
- (CPString)urlForSaveChangesWithData:(id)data {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns an url for requestObjects.
 */
- (CPString)urlForRequestObjectsWithFetchSpecification:(LOFFetchSpecification)fetchSpecification {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

@end
