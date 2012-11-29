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
- (CPArray)requestObjectsWithFetchSpecification:(LOFFetchSpecification)aFetchSpecification objectContext:(LOObjectContext)anObjectContext withCompletionBlock:(Function)aCompletionBlock {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Must call [objectContext objectsReceived: withFetchSpecification:] when objects are received
 */
- (CPArray)requestObjectsWithFetchSpecification:(LOFFetchSpecification)aFetchSpecification objectContext:(LOObjectContext)anObjectContext {
    [self requestObjectsWithFetchSpecification:aFetchSpecification objectContext:anObjectContext withCompletionBlock:nil];
}

/*!
 * Must call [objectContext faultReceived:(CPArray)objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification faultArray:(LOFaultArray)faultArray] when fault objects are received
 */
- (CPArray)requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext withCompletionBlock:(Function)aCompletionBlock {
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
- (CPURLRequest)urlForRequestObjectsWithFetchSpecification:(LOFFetchSpecification)fetchSpecification {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns the type for the raw row.
 */
- (CPString)typeForRawRow:(id)row objectContext:(LOObjectContext)objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns type of the object
 */
- (CPString)typeOfObject:(id)theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns the primary key attribute for the raw row of a type and for an object context.
 */
- (CPString)primaryKeyAttributeForType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns true if the attribute for the raw row is a foreign key for a type and for an object context.
 */
- (BOOL)isForeignKeyAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns to one relationship attribute that correspond to the foreign key attribute for the type
 */
- (CPString)toOneRelationshipAttributeForForeignKeyAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns foreign key attribute that correspond to the to one relationship attribute for the type
 */
- (CPString)foreignKeyAttributeForToOneRelationshipAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns the primary key for the raw row with type aType.
 */
- (CPString)primaryKeyForRawRow:(id)row forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    var primaryKeyAttribute = [self primaryKeyAttributeForType:aType objectContext:objectContext];
    return row[primaryKeyAttribute];
}

/*!
 * Returns the primary key value for an object.
 */
- (CPString)primaryKeyForObject:(id)theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Sets the primary key value for an object.
 */
- (void)setPrimaryKey:(CPString)thePrimaryKey forObject:(id)theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns a new object for the type.
 */
- (id) newObjectForType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    return [objectContext newObjectForType:aType];
}

/*!
 * Returns LOError for response and data if the backend has returned a error.
 */
- (LOError) errorForResponse:(CPHTTPURLResponse)response andData:(CPString)data fromURL:(CPString)urlString {
    return nil;
}

@end
