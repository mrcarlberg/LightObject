/*
 * LOObjectContext.j
 *
 * Created by Martin Carlberg on Feb 23, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectStore.j"
@import "LOSimpleJSONObjectStore.j"

LOObjectContextReceivedObjectNotification = @"LOObjectContextReceivedObjectNotification";

var LOObjectContext_newObjectForType = 1 << 0,
    LOObjectContext_objectsReceived_forObjectContext_withFetchSpecification = 1 << 1;

@implementation LOModifyRecord : CPObject {
    id              object @accessors;          // The object that is changed
    CPString        tmpId @accessors;           // Temporary id for object if LOObjectStore needs to keep track on it.
    CPDictionary    insertDict @accessors;      // A dictionary with attributes when the object is created (will usually be empty)
    CPDictionary    updateDict @accessors;      // A dictionary with attributes when the object is updated
    CPDictionary    deleteDict @accessors;      // A dictionary with attributes when the object is deleted (will usually be empty)
}

+ (LOModifyRecord) modifyRecordWithObject:(id) theObject {
    return [[LOModifyRecord alloc] initWithObject:theObject];
}

- (id)initWithObject:(id) theObject {
    self = [super init];
    if (self) {
        object = theObject;
    }
    return self;
}

@end

@implementation LOToOneProxyObject : CPObject {
    LOObjectContext objectContext;
}

+ (LOToOneProxyObject) toOneProxyObjectWithContext:(LOObjectContext) anObjectContext {
    return [[LOToOneProxyObject alloc] initWithContext:anObjectContext];
}

- (id)initWithContext:(LOObjectContext) anObjectContext {
    self = [super init];
    if (self) {
        objectContext = anObjectContext;
    }
    return self;
}

- (void)observeValueForKeyPath:(CPString)theKeyPath ofObject:(id)theObject change:(CPDictionary)theChanges context:(id)theContext {
    CPLog.trace(_cmd + @" observeValueForToOneRelationshipWithKeyPath:" + theKeyPath +  @" object:" + theObject + @" change:" + theChanges);
    [objectContext observeValueForToOneRelationshipWithKeyPath: theKeyPath ofObject:theObject change:theChanges context:theContext];
}

@end

@implementation LOObjectContext : CPObject {
    LOToOneProxyObject  toOneProxyObject;
    CPString            receivedData;
    CPDictionary        objects;                    // List of all objects in context with globalId as key
    CPArray             modifiedObjects @accessors; // Array of LOModifyRecords with "insert", "update" and "delete" dictionaries.
    CPArray             connections;                // Array of dictionary with connection: CPURLConnection and arrayController: CPArrayController
    @outlet id          delegate;
    @outlet LOObjectStore objectStore @accessors;
    CPInteger           implementedDelegateMethods;
    BOOL                autoCommit @accessors;
}

- (id)init {
    self = [super init];
    if (self) {
        toOneProxyObject = [LOToOneProxyObject toOneProxyObjectWithContext:self];
        objects = [CPDictionary dictionary];
        modifiedObjects = [CPArray array];
        connections = [CPArray array];
        autoCommit = true;
    }
    return self;
}

- (id)initWithDelegate:(id) aDelegate {
    self = [self init];
    if (self) {
        [self setDelegate:aDelegate];
    }
    return self;
}

- (void)setDelegate:(id)aDelegate {
    if (delegate === aDelegate)
        return;
    delegate = aDelegate;
    implementedDelegateMethods = 0;
    
    if ([delegate respondsToSelector:@selector(newObjectForType:)]) {
        implementedDelegateMethods |= LOObjectContext_newObjectForType;
    } else {
        CPLog.error(@"[LOObjectContext setDelegate]: Delegate must implement selector newObjectForType:");
    }
    if ([delegate respondsToSelector:@selector(objectsReceived:forObjectContext:withFetchSpecification:)])
        implementedDelegateMethods |= LOObjectContext_objectsReceived_forObjectContext_withFetchSpecification;
}

- (id) newObjectForType:(CPString) type {
    if (implementedDelegateMethods & LOObjectContext_newObjectForType) {
        var obj = [delegate newObjectForType:type];
        return obj;
    }
    return nil;
}

- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification) fetchSpecification {
    [objectStore requestObjectsWithFetchSpecification:fetchSpecification objectContext:self];
}

- (void) objectsReceived:(CPArray) objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification {
    if (implementedDelegateMethods & LOObjectContext_objectsReceived_forObjectContext_withFetchSpecification) {
        [delegate objectsReceived:objectList forObjectContext:self withFetchSpecification:fetchSpecification];
    }
    var defaultCenter = [CPNotificationCenter defaultCenter];
    [defaultCenter postNotificationName:LOObjectContextReceivedObjectNotification object:fetchSpecification userInfo:[CPDictionary dictionaryWithObject:objectList forKey:@"objects"]];
}

- (void)observeValueForKeyPath:(CPString)theKeyPath ofObject:(id)theObject change:(CPDictionary)theChanges context:(id)theContext {
    CPLog.trace(@"tracing: LOF observeValueForKeyPath:" + theKeyPath +  @" object:" + theObject + @" change:" + theChanges);
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
    [updateDict setObject:[theChanges valueForKey:CPKeyValueChangeNewKey] forKey:theKeyPath];
    if (autoCommit) [self saveChanges];
}

- (void)observeValueForToOneRelationshipWithKeyPath:(CPString)theKeyPath ofObject:(id)theObject change:(CPDictionary)theChanges context:(id)theContext {
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
    [updateDict setObject:[objectStore globalIdForObject:[theChanges valueForKey:CPKeyValueChangeNewKey]] forKey:theKeyPath + @"_fk"];
    if (autoCommit) [self saveChanges];
}

- (void) unregisterObject:(id) theObject {
    var globalId = [objectStore globalIdForObject:theObject];
    [objects removeObjectForKey:globalId];
    var attributeKeys = [objectStore attributeKeysForObject:theObject];
    var relationshipKeys = [objectStore relationshipKeysForObject:theObject];
    var attributeSize = [attributeKeys count];
    for (var i = 0; i < attributeSize; i++) {
        var attributeKey = [attributeKeys objectAtIndex:i];
        if (![relationshipKeys containsObject:attributeKey]) { // Not when it is a relationship
            [theObject removeObserver:self forKeyPath:attributeKey];
        }
    }
}

- (void) registerObject:(id) theObject {
    // TODO: Check if theObject is already registrered
    var globalId = [objectStore globalIdForObject:theObject];
    [objects setObject:theObject forKey:globalId];
    var attributeKeys = [objectStore attributeKeysForObject:theObject];
    var relationshipKeys = [objectStore relationshipKeysForObject:theObject];
    var attributeSize = [attributeKeys count];
    for (var i = 0; i < attributeSize; i++) {
        var attributeKey = [attributeKeys objectAtIndex:i];
        if ([attributeKey hasSuffix:@"_fk"]) {      // Handle to one relationship. Make observation to proxy object and remove "_fk" from attribute key
            [theObject addObserver:toOneProxyObject forKeyPath:[attributeKey substringToIndex:[attributeKey length] - 3] options:CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld /*| CPKeyValueObservingOptionInitial | CPKeyValueObservingOptionPrior*/ context:nil];
        } else if (![relationshipKeys containsObject:attributeKey]) { // Not when it is a to many relationship
            [theObject addObserver:self forKeyPath:attributeKey options:CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld /*| CPKeyValueObservingOptionInitial | CPKeyValueObservingOptionPrior*/ context:nil];
        }
    }
}

- (void) reregisterObject:(id) theObject fromGlobalId:(CPString) fromGlobalId toGlobalId:(CPString) toGlobalId {
    [objects setObject:theObject forKey:toGlobalId];
    [objects removeObjectForKey:fromGlobalId];
}

- (BOOL) isObjectRegistered:(id) theObject {
    var globalId = [objectStore globalIdForObject:theObject];
    return [objects objectForKey:globalId] != nil;
}

/*
 *  @return object to context
 */
- (id) objectForGlobalId:(CPString) globalId {
    return [objects objectForKey:globalId];
}

- (void) _insertObject:(id) theObject {
    [self createSubDictionaryForKey:@"insertDict" forModifyObjectDictionaryForObject:theObject]
//    [modifiedObjects addObject:[CPDictionary dictionaryWithJSObject:{"__object": theObject, "insert":{}} recursively:YES]];
    [self registerObject:theObject];
}

/*
 *  Add object to context
 */
- (void) insertObject:(id) theObject {
    [self _insertObject: theObject];
    if (autoCommit) [self saveChanges];
}

/*
 *  Add objects to context
 */
- (void) insertObjects:(CPArray) theObjects {
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        [self _insertObject:obj];
    }
    if (autoCommit) [self saveChanges];
}

- (void) _deleteObject:(id) theObject {
    [self unregisterObject:theObject];
    // Just need to create the dict to mark it for delete
    var deleteDict = [self createSubDictionaryForKey:@"deleteDict" forModifyObjectDictionaryForObject:theObject];
}


/*
 *  Remove object from context
 */
- (void) deleteObject:(id) theObject {
    [self _deleteObject: theObject];
    if (autoCommit) [self saveChanges];
}

/*
 *  Remove objects from context
 */
- (void) deleteObjects:(CPArray) theObjects {
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        [self _deleteObject:obj];
    }
    if (autoCommit) [self saveChanges];
}

- (void) _add:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    CPLog.trace(@"Added new object " + [newObject className] + @" to master of type " + [masterObject className] + @" for key " + relationshipKey);
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:masterObject];
    var relationsShipDict = [updateDict objectForKey:relationshipKey];
    if (!relationsShipDict) {
        relationsShipDict = [CPDictionary dictionary];
        [updateDict setObject:relationsShipDict forKey:relationshipKey];
    }
    var insertsArray = [relationsShipDict objectForKey:@"insert"];
    if (!insertsArray) {
        insertsArray = [CPArray array];
        [relationsShipDict setObject:insertsArray forKey:@"insert"];
    }
    [insertsArray addObject:newObject];
}

- (void) add:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    [self _add:newObject toRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void) _delete:(id)deletedObject withRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    // Right now we do nothing. A delete of the object will be sent and it is enought for one to many relations
    CPLog.trace(@"Deleted object " + [deletedObject className] + @" for master of type " + [masterObject className] + @" for key " + relationshipKey);
}

- (void) delete:(id)deletedObject withRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    [self _delete:deletedObject withRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void) saveChanges {
    [objectStore saveChangesWithObjectContext:self];
}

- (void) revert {
    [self setModifiedObjects:[CPArray array]];
    // TODO: must do something smart here
}

- (id) modifyObjectDictionaryForObject:(id) theObject {
    var size = [modifiedObjects count];
    for (var i = 0; i < size; i++) {
        var objDict = [modifiedObjects objectAtIndex:i];
        var obj = [objDict valueForKey:@"object"];
        if (obj === theObject) {
            return objDict;
        }
    }
    return nil;
}

- (CPDictionary) createSubDictionaryForKey:(CPString) key forModifyObjectDictionaryForObject:(id) theObject {
    var objDict = [self modifyObjectDictionaryForObject:theObject];
    if (!objDict) {
        objDict = [LOModifyRecord modifyRecordWithObject:theObject];
        [modifiedObjects addObject:objDict];
    }
    var subDict = [objDict valueForKey:key];
    if (!subDict) {
        subDict = [CPDictionary dictionary];
        [objDict setValue:subDict forKey:key];
    }
    return subDict;
}

@end
