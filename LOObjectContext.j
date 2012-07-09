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
@import "LOEvent.j"
@import "LOError.j"

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

- (BOOL) isEmpty {
    return !insertDict && !updateDict && !deleteDict;
}

- (CPString)description {
    return [CPString stringWithFormat:@"<LOModifyRecord insertDict: %@ updateDict: %@ deleteDict: %@>", insertDict, updateDict, deleteDict];
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
    CPDictionary        objects;                        // List of all objects in context with globalId as key
    CPArray             modifiedObjects @accessors;     // Array of LOModifyRecords with "insert", "update" and "delete" dictionaries.
    CPArray             undoEvents;                     // Array of arrays with LOUpdateEvents. Each transaction has its own array.
    CPArray             connections;                    // Array of dictionary with connection: CPURLConnection and arrayController: CPArrayController
    @outlet id          delegate;
    @outlet LOObjectStore objectStore @accessors;
    CPInteger           implementedDelegateMethods;
    BOOL                autoCommit @accessors;          // True if the context should directly save changes to object store.
    BOOL                doNotObserveValues @accessors;  // True if observeValueForKeyPath methods should ignore chnages. Used when doing revert
}

- (id)init {
    self = [super init];
    if (self) {
        toOneProxyObject = [LOToOneProxyObject toOneProxyObjectWithContext:self];
        objects = [CPDictionary dictionary];
        modifiedObjects = [CPArray array];
        connections = [CPArray array];
        autoCommit = true;
        undoEvents = [CPArray array];
        doNotObserveValues = false;
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

- (CPArray) requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification) fetchSpecification {
    [objectStore requestFaultArray:faultArray withFetchSpecification:fetchSpecification objectContext:self];
}

- (void) objectsReceived:(CPArray) objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification {
    if (objectList.isa && [objectList respondsToSelector:@selector(count)]) {
        [self registerObjects:objectList];
    }
    if (implementedDelegateMethods & LOObjectContext_objectsReceived_forObjectContext_withFetchSpecification) {
        [delegate objectsReceived:objectList forObjectContext:self withFetchSpecification:fetchSpecification];
    }
    var defaultCenter = [CPNotificationCenter defaultCenter];
    [defaultCenter postNotificationName:LOObjectContextReceivedObjectNotification object:fetchSpecification userInfo:[CPDictionary dictionaryWithObject:objectList forKey:@"objects"]];
}

- (void) faultReceived:(CPArray) objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification faultArray:(LOFaultArray)faultArray {
    [self registerObjects:objectList];
    var masterObject = [faultArray masterObject];
    var relationshipKey = [faultArray relationshipKey];
    var array = [masterObject valueForKey:relationshipKey];
//    print(_cmd + " masterObject: " + masterObject + " relationshipKey: " + relationshipKey);
    [masterObject willChangeValueForKey:relationshipKey];
    //    [array removeAllObjects];
    //    [masterObject setValue:newArray forKey:relationshipKey];
    [array addObjectsFromArray:objectList];
    [masterObject didChangeValueForKey:relationshipKey];
}

- (void)observeValueForKeyPath:(CPString)theKeyPath ofObject:(id)theObject change:(CPDictionary)theChanges context:(id)theContext {
    if (doNotObserveValues) return;
    var newValue = [theChanges valueForKey:CPKeyValueChangeNewKey];
    var oldValue = [theChanges valueForKey:CPKeyValueChangeOldKey];
    if (newValue === oldValue) return;

    var updateEvent = [LOUpdateEvent updateEventWithObject:theObject updateDict:[[self subDictionaryForKey:@"updateDict" forObject:theObject] copy] key:theKeyPath old:oldValue new:newValue];
    [self registerEvent:updateEvent];
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
    [updateDict setObject:newValue ? newValue : [CPNull null] forKey:theKeyPath];

    //console.log(_cmd + " " + theKeyPath +  @" object:" + theObject + @" change:" + theChanges + @" updateDict: " + [updateDict description]);

	// Simple validation handling
	if (delegate && [delegate respondsToSelector:@selector(objectContext:didValidateProperty:withError:)] && [theObject respondsToSelector:@selector(validatePropertyWithKeyPath:value:error:)]) {
    	var validationError = [theObject validatePropertyWithKeyPath:theKeyPath value:theChanges error:validationError];
		if ([validationError domain] === [LOError LOObjectValidationDomainString]) {
			[delegate objectContext:self didValidateProperty:theKeyPath withError:validationError];
		}
	}

    if (autoCommit) [self saveChanges];
}

- (void)observeValueForToOneRelationshipWithKeyPath:(CPString)theKeyPath ofObject:(id)theObject change:(CPDictionary)theChanges context:(id)theContext {
    if (doNotObserveValues) return;
    var newValue = [theChanges valueForKey:CPKeyValueChangeNewKey];
    var oldValue = [theChanges valueForKey:CPKeyValueChangeOldKey];
    if (newValue === oldValue) return;
    var newGlobalId = [self globalIdForObject:newValue];
    var oldGlobalId = [self globalIdForObject:oldValue];
    var foreignKey = theKeyPath + @"_fk";
    var updateDict = [[self subDictionaryForKey:@"updateDict" forObject:theObject] copy];
    var updateEvent = [LOToOneRelationshipUpdateEvent updateEventWithObject:theObject updateDict:updateDict key:theKeyPath old:oldValue new:newValue foreignKey:foreignKey oldForeignValue:oldGlobalId newForeignValue:newGlobalId];
    [self registerEvent:updateEvent];
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
    [updateDict setObject:newGlobalId ? newGlobalId : [CPNull null] forKey:foreignKey];
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
        if ([attributeKey hasSuffix:@"_fk"]) {    // Handle to one relationship
            attributeKey = [attributeKey substringToIndex:[attributeKey length] - 3]; // Remove "_fk" at end
        }
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

- (void) registerObjects:(CPArray) someObjects {
    var size = [someObjects count];
    for (var i = 0; i < size; i++) {
        var object = [someObjects objectAtIndex:i];
        if (![self isObjectRegistered:object]) {
            [self registerObject:object];
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

/*
 *  @return global id for the Object. If it is not in the context nil is returned
 */
- (CPString) globalIdForObject:(id) theObject {
    if (theObject) {
        var globalId = [objectStore globalIdForObject:theObject];
        if ([objects objectForKey:globalId]) {
            return globalId;
        }
    }
    return nil;
}

/*!
 * Returns the type of the object
 */
- (CPString) typeOfObject:(id)theObject {
    return [objectStore typeOfObject:theObject];
}

- (void) _insertObjectWithAttributes:(id) theObject {
    // Just need to create the dict to mark it for insert
    [self createSubDictionaryForKey:@"insertDict" forModifyObjectDictionaryForObject:theObject];

    // Add attributes with values
    var attributeKeys = [objectStore attributeKeysForObject:theObject];
    var relationshipKeys = [objectStore relationshipKeysForObject:theObject];
    var attributeSize = [attributeKeys count];
    for (var i = 0; i < attributeSize; i++) {
        var attributeKey = [attributeKeys objectAtIndex:i];
        if ([attributeKey hasSuffix:@"_fk"]) {      // Handle to one relationship. Make observation to proxy object and remove "_fk" from attribute key
            var value = [theObject valueForKey:[attributeKey substringToIndex:[attributeKey length] - 3]];
            if (value) {
                var globalId = [self globalIdForObject:value];
                if (globalId) {
                    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
                    [updateDict setObject:globalId forKey:attributeKey];
                }
            }
        } else if (![relationshipKeys containsObject:attributeKey]) { // Not when it is a to many relationship
            var value = [theObject valueForKey:attributeKey];
            if (value) {
                var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
                [updateDict setObject:value forKey:attributeKey];
            }
        }
    }
    [self registerObject:theObject];
}

/*
 *  Add object to context and add all non nil attributes as updated attributes
 */
- (void) insertObjectWithAttributes:(id) theObject {
    [self _insertObjectWithAttributes: theObject];
    var insertEvent = [LOInsertEvent insertEventWithObject:theObject arrayController:nil ownerObjects:nil ownerRelationshipKey:nil];
    [self registerEvent:insertEvent];
    if (autoCommit) [self saveChanges];
}

- (void) _insertObject:(id) theObject {
    // Just need to create the dict to mark it for insert
    [self createSubDictionaryForKey:@"insertDict" forModifyObjectDictionaryForObject:theObject];
    [self registerObject:theObject];
}

/*
 *  Add object to context
 */
- (void) insertObject:(id) theObject {
    [self _insertObject: theObject];
    var insertEvent = [LOInsertEvent insertEventWithObject:theObject arrayController:nil ownerObjects:nil ownerRelationshipKey:nil];
    [self registerEvent:insertEvent];
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

/*
 *  Uninsert object to context. Used when doing undo
 */
- (void) unInsertObject:(id) theObject {
    [self _unInsertObject: theObject];
    if (autoCommit) [self saveChanges];
}

- (void) _unInsertObject:(id) theObject {
    if ([self subDictionaryForKey:@"insertDict" forObject:theObject]) {
        [self setSubDictionary:nil forKey:@"insertDict" forObject:theObject];
    } else {
        [self createSubDictionaryForKey:@"deleteDict" forModifyObjectDictionaryForObject:theObject];
    }
    [self setSubDictionary:nil forKey:@"updateDict" forObject:theObject];
    [self unregisterObject:theObject];
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
    var deleteEvent = [LODeleteEvent deleteEventWithObjects:[theObject] atArrangedObjectIndexes:nil arrayController:nil ownerObjects:nil ownerRelationshipKey:nil];
    [self registerEvent:deleteEvent];
    [self _deleteObject: theObject];
    if (autoCommit) [self saveChanges];
}

/*
 *  Remove objects from context
 */
- (void) deleteObjects:(CPArray) theObjects {
    //FIXME: create delete event as in -deleteObject:
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        [self _deleteObject:obj];
    }
    if (autoCommit) [self saveChanges];
}

/*
 *  Undelete object to context. Used when doing undo
 */
- (void) unDeleteObject:(id) theObject {
    [self _unDeleteObject: theObject];
    if (autoCommit) [self saveChanges];
}

- (void) _unDeleteObject:(id) theObject {
    if ([self subDictionaryForKey:@"deleteDict" forObject:theObject]) {
        [self setSubDictionary:nil forKey:@"deleteDict" forObject:theObject];
    } else {
        [self createSubDictionaryForKey:@"insertDict" forModifyObjectDictionaryForObject:theObject];
    }
    [self registerObject:theObject];
}

/*
 *  Undelete objects to context. Used when doing undo
 */
- (void) unDeleteObjects:(CPArray) theObjects {
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        [self _unDeleteObject:obj];
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
    console.log([self className] + " " + _cmd + " " + relationshipKey);
    [self _add:newObject toRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void) unAdd:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    console.log([self className] + " " + _cmd + " " + relationshipKey);
    [self _unAdd:newObject toRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void) _unAdd:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    console.log([self className] + " " + _cmd + " " + relationshipKey);
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:masterObject];
    var relationsShipDict = [updateDict objectForKey:relationshipKey];
    if (relationsShipDict) {
        var insertsArray = [relationsShipDict objectForKey:@"insert"];
        if (insertsArray) {
            [insertsArray deleteObject:newObject];
        }
    }
}

- (void) _delete:(id)deletedObject withRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    // Right now we do nothing. A delete of the object will be sent and it is enought for one to many relations
    CPLog.trace(@"Deleted object " + [deletedObject className] + @" for master of type " + [masterObject className] + @" for key " + relationshipKey);
}

- (void) delete:(id)deletedObject withRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    [self _delete:deletedObject withRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void) delete:(id)aMapping withRelationshipWithKey:(CPString)aRelationshipKey between:(id)firstObject and:(id)secondObject {
    //FIXME: raise on index==NSNotFound?
    var leftIndex = [self _findIndexOfObject:aMapping andRemoveItFromRelationshipWithKey:aRelationshipKey ofObject:firstObject];
    var rightIndex = [self _findIndexOfObject:aMapping andRemoveItFromRelationshipWithKey:aRelationshipKey ofObject:secondObject];

    var deleteEvent = [LOManyToManyRelationshipDeleteEvent deleteEventWithMapping:aMapping leftObject:firstObject key:aRelationshipKey index:leftIndex rightObject:secondObject key:aRelationshipKey index:rightIndex];
    [self registerEvent:deleteEvent];

    [self unregisterObject:aMapping];
    var deleteDict = [self createSubDictionaryForKey:@"deleteDict" forModifyObjectDictionaryForObject:aMapping];

    if (autoCommit) [self saveChanges];
}

- (int) _findIndexOfObject:(id)anObject andRemoveItFromRelationshipWithKey:(CPString)aRelationshipKey ofObject:(id)theParent
{
    var array = [theParent valueForKey:aRelationshipKey];
    var index = [array indexOfObjectIdenticalTo:anObject];
    var indexSet = [CPIndexSet indexSetWithIndex:index];
    [theParent willChange:CPKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:aRelationshipKey];
    [array removeObjectAtIndex:index];
    [theParent didChange:CPKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:aRelationshipKey];
    return index;
}

- (void) insert:(id)aMapping withRelationshipWithKey:(CPString)aRelationshipKey between:(id)firstObject and:(id)secondObject {
    var array = [firstObject valueForKey:aRelationshipKey];
    var leftIndex = [array count];
    [array addObject:aMapping];

    array = [secondObject valueForKey:aRelationshipKey];
    var rightIndex = [array count];
    [array addObject:aMapping];

    [self _insertObject:aMapping];
    [aMapping setValue:firstObject forKey:[firstObject loObjectType]];
    [aMapping setValue:secondObject forKey:[secondObject loObjectType]];

    var insertEvent = [LOManyToManyRelationshipInsertEvent insertEventWithMapping:aMapping leftObject:firstObject key:aRelationshipKey index:leftIndex  rightObject:secondObject key:aRelationshipKey index:rightIndex];
    [self registerEvent:insertEvent];
}

- (BOOL) isObjectStored:(id)theObject {
    return ![self subDictionaryForKey:@"insertDict" forObject:theObject];
}

- (BOOL) isObjectModified:(id)theObject {
    var objDict = [self modifyObjectDictionaryForObject:theObject];
    if (objDict) {
        return [objDict valueForKey:@"updateDict"] || [objDict valueForKey:@"insertDict"] || [objDict valueForKey:@"deleteDict"];
    }

    return NO;
}

- (BOOL) hasChanges {
    var size = [modifiedObjects count];
    for (var i = 0; i < size; i++) {
        var modifiedObject = [modifiedObjects objectAtIndex:i];
        if (![modifiedObject isEmpty]) {
            return true;
        }
    }
    return false;
}

/*!
 * Start a new transaction. All changes will be stored separate from previus changes.
 * Transaction must be ended by a saveChanges or revert call.
 */
- (void) startTransaction {
    [undoEvents addObject:[]];
}

- (void) saveChanges {
	var shouldSave = YES;
	
	var size = [modifiedObjects count];
    for (var i = 0; i < size; i++) {
        var modifiedObject = [modifiedObjects objectAtIndex:i];
        if (![modifiedObject isEmpty]) {
			if ((delegate && [delegate respondsToSelector:@selector(objectContext:shouldSaveChanges:withObject:)])) {
				var objDict = [self modifyObjectDictionaryForObject:theObject];
				shouldSave = [delegate objectContext:self shouldSaveChanges:objDict withObject:modifiedObject];
				if (!shouldSave) return;
			}
        }
    }
	
    [objectStore saveChangesWithObjectContext:self];

    // Remove transaction
    var count = [undoEvents count];
    if (count) {
        [undoEvents removeObjectAtIndex:count - 1];
    }
}

/*!
 *  Should be called by the objectStore when the saveChanges are done
 */
- (void) saveChangesDidComplete {
    [self setModifiedObjects:[CPArray array]];
}

- (void) revert {
//    [self setModifiedObjects:[CPArray array]];

    var lastUndoEvents = [undoEvents lastObject];

    if (lastUndoEvents) {
        var count = [lastUndoEvents count];
        doNotObserveValues = true;

        while (count--) {
            var event = [lastUndoEvents objectAtIndex:count];
            [event undoForContext:self];
        }
        [undoEvents removeObject:lastUndoEvents];
        doNotObserveValues = false;
    }
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

- (void) removeModifyObjectDictionaryForObject:(id) theObject {
    var size = [modifiedObjects count];
    for (var i = 0; i < size; i++) {
        var objDict = [modifiedObjects objectAtIndex:i];
        var obj = [objDict valueForKey:@"object"];

        if (obj === theObject) {
            [modifiedObjects removeObjectAtIndex:i];
            break;
        }
    }
}

- (void) setSubDictionary:(CPDictionary)subDict forKey:(CPString) key forObject:(id) theObject {
    var objDict = [self modifyObjectDictionaryForObject:theObject];
    if (!objDict) {
        if (!subDict) return;       // Bail out if we should set it to nil and we don't have any
        objDict = [LOModifyRecord modifyRecordWithObject:theObject];
        [modifiedObjects addObject:objDict];
    }
    [objDict setValue:subDict forKey:key];
    if ([objDict isEmpty]) {
        [modifiedObjects removeObject:objDict];
    }
}

- (CPDictionary) subDictionaryForKey:(CPString) key forObject:(id) theObject {
    var objDict = [self modifyObjectDictionaryForObject:theObject];
    if (objDict) {
        var subDict = [objDict valueForKey:key];
        if (subDict) {
            return subDict;
        }
    }
    return null;
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

- (void) registerEvent:(LOUpdateEvent)updateEvent {
    var lastUndoEvents = [undoEvents lastObject];

    if (!lastUndoEvents) {
        lastUndoEvents = [CPArray array];
        [undoEvents addObject:lastUndoEvents];
    }

    [lastUndoEvents addObject:updateEvent];
}

@end
