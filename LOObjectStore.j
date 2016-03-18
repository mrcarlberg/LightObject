/*
 * LOSimpleJSONObjectStore.j
 *
 * Created by Martin Carlberg on Mars 5, 2012.
 * Copyright 2012, All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"

@implementation LOObjectStore : CPObject {
}

/*!
 * Designated method for requesting objects.
 * Must call [objectContext objectsReceived: withFetchSpecification:] when objects are received
 */
- (void)requestObjectsWithFetchSpecification:(LOFetchSpecification)aFetchSpecification objectContext:(LOObjectContext)anObjectContext requestId:(id)aRequestId withCompletionHandler:(Function)aCompletionBlock {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Convenience method calling -requestObjectsWithFetchSpecification:objectContext:requestId:withCompletionHandler: without requestId.
 */
- (void)requestObjectsWithFetchSpecification:(LOFetchSpecification)aFetchSpecification objectContext:(LOObjectContext)anObjectContext withCompletionHandler:(Function)aCompletionBlock {
    [self requestObjectsWithFetchSpecification:aFetchSpecification objectContext:anObjectContext requestId:nil withCompletionHandler:aCompletionBlock];
}

/*!
 * Convenience method calling -requestObjectsWithFetchSpecification:objectContext:requestId:withCompletionHandler: with neither requestId nor completion handler.
 */
- (void)requestObjectsWithFetchSpecification:(LOFetchSpecification)aFetchSpecification objectContext:(LOObjectContext)anObjectContext {
    [self requestObjectsWithFetchSpecification:aFetchSpecification objectContext:anObjectContext requestId:nil withCompletionHandler:nil];
}

/*!
 * Designated method for requesting fault array.
 * Must call [objectContext faultReceived:(CPArray)objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification faultArray:(LOFaultArray)faultArray] when fault objects are received
 */
- (void)requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext requestId:(id)aRequestId withCompletionHandler:(Function)aCompletionBlock {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Convenience method calling requestFaultArray:withFetchSpecification:objectContext:requestId:withCompletionHandler: without requestId.
 */
- (void)requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext withCompletionHandler:(Function)aCompletionBlock {
    [self requestFaultArray:faultArray withFetchSpecification:fetchSpecification objectContext:objectContext requestId:nil withCompletionHandler:aCompletionBlock];
}

/*!
 * Designated method for requesting fault objects.
 * Must call [objectContext faultReceived:(CPArray)objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification faultObject:(LOFaultObject)faultObject] when fault objects are received
 */
- (void)requestFaultObjects:(CPArray)faultObjects withFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext requestId:(id)aRequestId withCompletionHandler:(Function)aCompletionBlock {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Convenience method calling -requestFaultObjects:withFetchSpecification:objectContext:requestId:withCompletionHandler: without requestId.
 */
- (void)requestFaultObjects:(CPArray)faultObjects withFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext withCompletionHandler:(Function)aCompletionBlock {
    [self requestFaultObjects:faultObjects withFetchSpecification:fetchSpecification objectContext:objectContext requestId:nil withCompletionHandler:aCompletionBlock];
}

/*!
 * Cancel all currently running requests with a specific requestId and object context.
 * A requestId argument of nil means match any request with respect to requestId, and similarly for the anObjectContext argument.
 * Thus,
 *
 *   [objectStore cancelRequestsWithRequestId:nil withObjectContext:ctx];
 *
 * cancels all requests to ctx regardless of requestId, and
 *
 *   [objectStore cancelRequestsWithRequestId:nil withObjectContext:nil];
 *
 * cancels all requests regardless of both requestId and object context.
 */
- (void)cancelRequestsWithRequestId:(id)aRequestId withObjectContext:(LOObjectContext)anObjectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * This method should save all changes to the backend.
 * The ObjectContext has a list of LOModifyRecord that contains all changes.
 */
- (void)saveChangesWithObjectContext:(LOObjectContext)objectContext withCompletionHandler:(Function)aCompletionBlock {
}

/*!
 * Must return an array with keys for all attributes for this object.
 * To many relationship keys and to one relationsship foreign key attributes should be included.
 * To one relationsship attribute should not be included.
 * Primary key should not be included.
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray)attributeKeysForObject:(id)theObject withType:(CPString)entityName {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Must return an array with keys for all to many relationship attributes for this object
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray)relationshipKeysForObject:(id)theObject withType:(CPString)entityName {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns the type of the object
 */
- (CPString)typeOfObject:(id)theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns a unique id for the object
 */
- (CPString)globalIdForObject:(id)theObject {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns globalId for entity type and primary key. Should return nil if primaryKey is nil.
 * Right now we only use the primary key as global id as we always has totaly unique primary keys.
 * TODO: This framework does propably not yet support that the global id is different from primary key.
 */
- (CPString)globalIdForObjectType:(CPString)objectType andPrimaryKey:(CPString)primaryKey {
    return primaryKey;
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
- (CPURLRequest)urlForRequestObjectsWithFetchSpecification:(LOFetchSpecification)fetchSpecification {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

/*!
 * Returns the type for the raw row.
 */
- (CPString)typeForRawRow:(id)row objectContext:(LOObjectContext)objectContext fetchSpecification:(LOFetchSpecification)fetchSpecification {
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
- (CPString)foreignKeyAttributeForToOneRelationshipAttribute:(CPString)attribute forType:(CPString)aType {
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
- (id)newObjectForType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    return [objectContext newObjectForType:aType];
}

/*!
 * Returns LOError for response and data if the backend has returned a error.
 */
- (LOError)errorForResponse:(CPHTTPURLResponse)response andData:(CPString)data fromURL:(CPString)urlString {
    return nil;
}

@end
