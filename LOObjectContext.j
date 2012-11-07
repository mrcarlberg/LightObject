/*!
   LOObjectContext.j
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
LOObjectsKey = @"LOObjectsKey";

var LOObjectContext_classForType = 1 << 0,
    LOObjectContext_objectContext_objectsReceived_withFetchSpecification = 1 << 1,
    LOObjectContext_objectContext_didValidateProperty_withError = 1 << 2,
    LOObjectContext_objectContext_shouldSaveChanges_withObject_inserted = 1 << 3,
    LOObjectContext_objectContext_didSaveChangesWithResultAndStatus = 1 << 4;
    LOObjectContext_objectContext_errorReceived_withFetchSpecification = 1 << 5;


@implementation LOModifyRecord : CPObject {
    id              object @accessors;          // The object that is changed
    CPString        tmpId @accessors;           // Temporary id for object if LOObjectStore needs to keep track on it.
    CPDictionary    insertDict @accessors;      // A dictionary with attributes when the object is created
    CPDictionary    updateDict @accessors;      // A dictionary with attributes when the object is updated
    CPDictionary    deleteDict @accessors;      // A dictionary with attributes when the object is deleted (will allways be empty)
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
    //CPLog.trace(_cmd + @" observeValueForToOneRelationshipWithKeyPath:" + theKeyPath +  @" object:" + theObject + @" change:" + theChanges);
    [objectContext observeValueForToOneRelationshipWithKeyPath: theKeyPath ofObject:theObject change:theChanges context:theContext];
}

@end

/*!
 @ingroup LightObject
 @class LOObjectContext

     LOObjectContext represents a single "object space" or document in an application. Its primary responsibility is managing a graph of objects. This object graph is a group of related business objects that represent an internally consistent view of one object store.
 
     All objects fetched from an object store are registered in an LOObjectContext along with a global identifier (LOGlobalID)(LOGlobalID not yet implemented) that's used to uniquely identify each object to the object store. The LOObjectContext is responsible for watching for changes in its objects (using the CPKeyValueObserving protocol). A single object instance exists in one and only one LOObjectContext.

     The object context observes all changes of the object graph except toMany relations. The caller is responsible to use the add:toRelationshipWithKey:forObject: or delete:withRelationshipWithKey:forObject: method to let the object context know about changes in tomany relations.
 
     A LOArrayController can keep track of changes in tomany relations and make sure that the add:toRelationshipWithKey:forObject: or delete:withRelationshipWithKey:forObject: method is used appropriate.
 
     The framework supports "fault" and "deep fetch" for tomany relations. The backend can send a fault or an array with type and primary key values for a deep fetch. In a "deep fetch" the rows corresponding to the tomany relationship should be sent together with the fetched objects (in the same list).

     When a fetch is requested with the requestObjectsWithFetchSpecification: method the answer is later sent with the delegate method objectContext:objectsReceived:withFetchSpecification: or sent as the notification LOObjectContextReceivedObjectNotification with the fetch specification as object and result in userInfo.
 
     When a fault is triggered the notification LOFaultDidFireNotification is sent and when it is received the notification LOFaultDidPopulateNotification is sent.
    
     Right now the global id is the same as the primary key. A primary key has to be unique for all objects in the object context.

 @delegate -(void)objectContext:(LOObjectContext)anObjectContext objectsReceived:(CPArray)objects withFetchSpecification:(LOFetchSpecification)aFetchSpecification;
 Receives objects from an fetch request specified by the fetch specification.
 @param anObjectContext contains the object context
 @param objects contains the received objects
 @param aFetchSpecification contains the fetch specification

 @delegate -(void)objectContext:(LOObjectContext)anObjectContext errorReceived:(LOError)anError withFetchSpecification:(LOFetchSpecification)aFetchSpecification;
 Receives error from an fetch request specified by the fetch specification.
 @param anObjectContext contains the object context
 @param anError contains the error
 @param aFetchSpecification contains the fetch specification

 //TODO: Add more delegate methods to this documentation
 */
@implementation LOObjectContext : CPObject {
    LOToOneProxyObject  toOneProxyObject;               // Extra observer proxy for to one relation attributes
    CPDictionary        objects;                        // List of all objects in context with globalId as key
    CPArray             modifiedObjects @accessors;     // Array of LOModifyRecords with "insert", "update" and "delete" dictionaries.
    CPArray             undoEvents;                     // Array of arrays with LOUpdateEvents. Each transaction has its own array.
    CPArray             connections;                    // Array of dictionary with connection: CPURLConnection and arrayController: CPArrayController
    @outlet id          delegate;
    @outlet LOObjectStore objectStore @accessors;
    CPInteger           implementedDelegateMethods;
    BOOL                autoCommit @accessors;          // True if the context should directly save changes to object store.
    BOOL                doNotObserveValues @accessors;  // True if observeValueForKeyPath methods should ignore chnages. Used when doing revert
    BOOL                readOnly;            // True if object context is a read only context. A read only context don't listen to changes for the attributes on the objects
}

- (id)init {
    self = [super init];
    if (self) {
        toOneProxyObject = [LOToOneProxyObject toOneProxyObjectWithContext:self];
        objects = [CPDictionary dictionary];
        modifiedObjects = [CPArray array];
        connections = [CPArray array];
        autoCommit = YES;
        undoEvents = [CPArray array];
        doNotObserveValues = NO;
        readOnly = NO;
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
    
    if ([delegate respondsToSelector:@selector(classForType:)])
        implementedDelegateMethods |= LOObjectContext_classForType;
    if ([delegate respondsToSelector:@selector(objectContext:objectsReceived:withFetchSpecification:)])
        implementedDelegateMethods |= LOObjectContext_objectContext_objectsReceived_withFetchSpecification;
    if ([delegate respondsToSelector:@selector(objectContext:didValidateProperty:withError:)])
        implementedDelegateMethods |= LOObjectContext_objectContext_didValidateProperty_withError;
    if ([delegate respondsToSelector:@selector(objectContext:shouldSaveChanges:withObject:inserted:)])
        implementedDelegateMethods |= LOObjectContext_objectContext_shouldSaveChanges_withObject_inserted;
    if ([delegate respondsToSelector:@selector(objectContext:didSaveChangesWithResult:andStatus:)])
        implementedDelegateMethods |= LOObjectContext_objectContext_didSaveChangesWithResultAndStatus;
    if ([delegate respondsToSelector:@selector(objectContext:errorReceived:withFetchSpecification:)])
        implementedDelegateMethods |= LOObjectContext_objectContext_errorReceived_withFetchSpecification;
}

- (BOOL)readOnly {
    return readOnly;
}

- (void)setReadOnly:(BOOL)aValue {
    // TODO: Add or remove observers for the objects in the context. Now we can only set read only for an empty context
    if ([objects count] && aValue !== readOnly) {
        CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Can't change the Read Only state of a Object Context when there are objects registered in the context. Number of registered objects: " + [objects count]);
    } else {
        readOnly = aValue;
    }
}

/*!
 This method will create a new object. Always use this method to create a object for a object context
 */
- (id)createNewObjectForType:(CPString)type {
    return [objectStore newObjectForType:type objectContext:self];
}

/*!
 This method will ask the delegate for a class and create an object. Never use this method directly to create a new object, use the createNewObjectForType: method instead.
 */
- (id)newObjectForType:(CPString)type {
    if (implementedDelegateMethods & LOObjectContext_classForType) {
        var aClass = [delegate classForType:type];
        return [[aClass alloc] init];
    } else {
        CPLog.error(@"[" + [self className] + @" " + _cmd + @"]: Delegate must implement selector classForType: to be able to create new object of type: " + type);
    }
    return nil;
}

- (CPArray)requestObjectsWithFetchSpecification:(LOFFetchSpecification)aFetchSpecification {
    [objectStore requestObjectsWithFetchSpecification:aFetchSpecification objectContext:self withCompletionBlock:nil];
}

- (CPArray)requestObjectsWithFetchSpecification:(LOFFetchSpecification)aFetchSpecification withCompletionBlock:(Function)aCompletionBlock {
    [objectStore requestObjectsWithFetchSpecification:aFetchSpecification objectContext:self withCompletionBlock:aCompletionBlock];
}

- (CPArray)requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification) fetchSpecification withCompletionBlock:(Function)aCompletionBlock {
    [objectStore requestFaultArray:faultArray withFetchSpecification:fetchSpecification objectContext:self withCompletionBlock:aCompletionBlock];
}

- (void)objectsReceived:(CPArray) objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification withCompletionBlocks:(CPArray)completionBlocks {
    if (objectList.isa && [objectList respondsToSelector:@selector(count)]) {
        [self registerObjects:objectList];
    }
    if (completionBlocks) {
        var size = [completionBlocks count];
        for (var i = 0; i < size; i++) {
            var aCompletionBlock = [completionBlocks objectAtIndex:i];
            aCompletionBlock(objectList);
        }
    } else if (implementedDelegateMethods & LOObjectContext_objectContext_objectsReceived_withFetchSpecification) {
        [delegate objectContext:self objectsReceived:objectList withFetchSpecification:fetchSpecification];
    }
    var defaultCenter = [CPNotificationCenter defaultCenter];
    [defaultCenter postNotificationName:LOObjectContextReceivedObjectNotification object:fetchSpecification userInfo:[CPDictionary dictionaryWithObject:objectList forKey:LOObjectsKey]];
}

- (void)faultReceived:(CPArray)objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification withCompletionBlocks:(CPArray)completionBlocks faultArray:(LOFaultArray)faultArray {
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
    [faultArray setFaultPopulated:YES];
    if (completionBlocks) {
        var size = [completionBlocks count];
        for (var i = 0; i < size; i++) {
            var aCompletionBlock = [completionBlocks objectAtIndex:i];
            aCompletionBlock(array);
        }
    }
    [[CPNotificationCenter defaultCenter] postNotificationName:LOFaultDidPopulateNotification object:[faultArray masterObject] userInfo:[CPDictionary dictionaryWithObjects:[faultArray, fetchSpecification] forKeys:[LOFaultArrayKey, LOFaultFetchSpecificationKey]]];
}

- (void)errorReceived:(LOError)error withFetchSpecification:(LOFetchSpecification)fetchSpecification {
    if (implementedDelegateMethods & LOObjectContext_objectContext_errorReceived_withFetchSpecification) {
        [delegate objectContext:self errorReceived:error withFetchSpecification:fetchSpecification];
    }
}

- (void)observeValueForKeyPath:(CPString)theKeyPath ofObject:(id)theObject change:(CPDictionary)theChanges context:(id)theContext {
    if (doNotObserveValues) return;
    var newValue = [theChanges valueForKey:CPKeyValueChangeNewKey];
    var oldValue = [theChanges valueForKey:CPKeyValueChangeOldKey];
    if (newValue === oldValue) return;

    var updateEvent = [LOUpdateEvent updateEventWithObject:theObject updateDict:[[self subDictionaryForKey:@"updateDict" forObject:theObject] copy] key:theKeyPath old:oldValue new:newValue];
    [self registerEvent:updateEvent];
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
	[updateDict setObject:newValue !== nil ? newValue : [CPNull null] forKey:theKeyPath];
    //CPLog.trace(@"%@", _cmd + " " + theKeyPath +  @" object:" + theObject + @" change:" + theChanges + @" updateDict: " + [updateDict description]);

	// Simple validation handling
	if (implementedDelegateMethods & LOObjectContext_objectContext_didValidateProperty_withError && [theObject respondsToSelector:@selector(validatePropertyWithKeyPath:value:error:)]) {
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
    if (newValue === [CPNull null])
        newValue = nil;
    var newGlobalId;
    var shouldSetForeignKey;       // We don't want to set a foreign key if the master object don't have a primary key.
    if (newValue) {
        var primaryKey = [objectStore primaryKeyForObject:newValue];
        if (primaryKey) {
            shouldSetForeignKey = YES;
            newGlobalId = [self globalIdForObject:newValue];
        } else {
            shouldSetForeignKey = NO;
            newGlobalId = nil;
        }
    } else {
        shouldSetForeignKey = YES;
        newGlobalId = nil;
    }
    var oldGlobalId = [self globalIdForObject:oldValue];
    var foreignKey = [objectStore foreignKeyAttributeForToOneRelationshipAttribute:theKeyPath forType:[self typeOfObject:theObject] objectContext:self];
    var updateDict = [[self subDictionaryForKey:@"updateDict" forObject:theObject] copy];
    var updateEvent = [LOToOneRelationshipUpdateEvent updateEventWithObject:theObject updateDict:updateDict key:theKeyPath old:oldValue new:newValue foreignKey:foreignKey oldForeignValue:oldGlobalId newForeignValue:newGlobalId];
    [self registerEvent:updateEvent];
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:theObject];
    if (shouldSetForeignKey) {
        [updateDict setObject:newGlobalId ? newGlobalId : [CPNull null] forKey:foreignKey];
    }
    //CPLog.trace(@"%@", _cmd + " " + theKeyPath +  @" object:" + theObject + @" change:" + theChanges + @" updateDict: " + [updateDict description]);
    if (autoCommit) [self saveChanges];
}

- (void)unregisterObject:(id) theObject {
    var globalId = [objectStore globalIdForObject:theObject];
    var type = [self typeOfObject:theObject];
    [objects removeObjectForKey:globalId];
    if (!readOnly) {
        var attributeKeys = [objectStore attributeKeysForObject:theObject];
        var relationshipKeys = [objectStore relationshipKeysForObject:theObject];
        var attributeSize = [attributeKeys count];
        for (var i = 0; i < attributeSize; i++) {
            var attributeKey = [attributeKeys objectAtIndex:i];
            if ([objectStore isForeignKeyAttribute:attributeKey forType:type objectContext:self]) {    // Handle to one relationship
                attributeKey = [objectStore toOneRelationshipAttributeForForeignKeyAttribute:attributeKey forType:type objectContext:self]; // Remove "_fk" at end
            }
            if (![relationshipKeys containsObject:attributeKey]) { // Not when it is a relationship
                [theObject removeObserver:self forKeyPath:attributeKey];
            }
        }
    }
}

- (void)registerObject:(id) theObject {
    // TODO: Check if theObject is already registrered
    var globalId = [objectStore globalIdForObject:theObject];
    var type = [self typeOfObject:theObject];
    [objects setObject:theObject forKey:globalId];
    if (!readOnly) {
        var attributeKeys = [objectStore attributeKeysForObject:theObject];
        var relationshipKeys = [objectStore relationshipKeysForObject:theObject];
        var attributeSize = [attributeKeys count];
        for (var i = 0; i < attributeSize; i++) {
            var attributeKey = [attributeKeys objectAtIndex:i];
            if ([objectStore isForeignKeyAttribute:attributeKey forType:type objectContext:self]) {    // Handle to one relationship Make observation to proxy object and remove "_fk" from attribute key
                attributeKey = [objectStore toOneRelationshipAttributeForForeignKeyAttribute:attributeKey forType:type objectContext:self]; // Remove "_fk" at end
                [theObject addObserver:toOneProxyObject forKeyPath:attributeKey options:CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld /*| CPKeyValueObservingOptionInitial | CPKeyValueObservingOptionPrior*/ context:nil];
            } else if (![relationshipKeys containsObject:attributeKey]) { // Not when it is a to many relationship
                [theObject addObserver:self forKeyPath:attributeKey options:CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld /*| CPKeyValueObservingOptionInitial | CPKeyValueObservingOptionPrior*/ context:nil];
            }
        }
    }
}

- (void)registerObjects:(CPArray) someObjects {
    var size = [someObjects count];
    for (var i = 0; i < size; i++) {
        var object = [someObjects objectAtIndex:i];
        if (![self isObjectRegistered:object]) {
            [self registerObject:object];
        }
    }
}

/*!
    Reregister the object with toGlobalId and removes it the old global id. This method asks the object for the current global id before the reregister. The caller is responseble to set the primary key afterward if necessary.
 */
- (void)reregisterObject:(id)theObject withNewGlobalId:(CPString)toGlobalId {
    var fromGlobalId = [self globalIdForObject:theObject];
    if (fromGlobalId) {
        [objects setObject:theObject forKey:toGlobalId];
        [objects removeObjectForKey:fromGlobalId];
    }
}

/*!
    @return YES if theObject is stored by the object store and is registered in the context
    If you insert a new object to the object context this method will return NO until you send a saveChanges:
 */
- (BOOL)isObjectStored:(id) theObject {
    var globalId = [objectStore globalIdForObject:theObject];
    return [objects objectForKey:globalId] && ![self subDictionaryForKey:@"insertDict" forObject:theObject];
}

/*!
    @return YES if theObject is registered in the context
 */
- (BOOL)isObjectRegistered:(id) theObject {
    var globalId = [objectStore globalIdForObject:theObject];
    return [objects objectForKey:globalId] != nil;
}

/*!
    @return object to context
 */
- (id)objectForGlobalId:(CPString) globalId {
    return [objects objectForKey:globalId];
}

/*!
    @return global id for the Object. If it is not in the context nil is returned
 */
- (CPString)globalIdForObject:(id) theObject {
    if (theObject) {
        var globalId = [objectStore globalIdForObject:theObject];
        if ([objects objectForKey:globalId]) {
            return globalId;
        }
    }
    return nil;
}

/*!
   Returns the type of the object
 */
- (CPString)typeOfObject:(id)theObject {
    return [objectStore typeOfObject:theObject];
}

- (void)_insertObject:(id) theObject {
    var type = [self typeOfObject:theObject];
    // Just need to create the dict to mark it for insert
    [self createSubDictionaryForKey:@"insertDict" forModifyObjectDictionaryForObject:theObject];

    // Add attributes with values
    var attributeKeys = [objectStore attributeKeysForObject:theObject];
    var relationshipKeys = [objectStore relationshipKeysForObject:theObject];
    var attributeSize = [attributeKeys count];
    for (var i = 0; i < attributeSize; i++) {
        var attributeKey = [attributeKeys objectAtIndex:i];
        if ([objectStore isForeignKeyAttribute:attributeKey forType:type objectContext:self]) {    // Handle to one relationship. Make observation to proxy object and remove "_fk" from attribute key
            var toOneAttribute = [objectStore toOneRelationshipAttributeForForeignKeyAttribute:attributeKey forType:type objectContext:self]; // Remove "_fk" at end
            var value = [theObject valueForKey:toOneAttribute];
            if (value) {
                var globalId = [self globalIdForObject:value];
                if (globalId && [objectStore primaryKeyForObject:value]) {  // If the master object doesn't have a primary key don't set the foreign key
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

/*!
    Add object to context and add all non nil attributes as updated attributes
 */
- (void)insertObject:(id) theObject {
    [self _insertObject: theObject];
    var insertEvent = [LOInsertEvent insertEventWithObject:theObject arrayController:nil ownerObjects:nil ownerRelationshipKey:nil];
    [self registerEvent:insertEvent];
    if (autoCommit) [self saveChanges];
}

/*!
    Add objects to context
 */
- (void)insertObjects:(CPArray) theObjects {
    //FIXME: create delete event as in -insertObject:
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        [self _insertObject:obj];
    }
    if (autoCommit) [self saveChanges];
}

/*!
    Uninsert object to context. Used when doing undo
 */
- (void)unInsertObject:(id) theObject {
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

- (void)_deleteObject:(id) theObject {
    [self unregisterObject:theObject];
    // Just need to create the dict to mark it for delete
    var deleteDict = [self createSubDictionaryForKey:@"deleteDict" forModifyObjectDictionaryForObject:theObject];
}


/*!
    Remove object from context
 */
- (void)deleteObject:(id) theObject {
    var deleteEvent = [LODeleteEvent deleteEventWithObjects:[theObject] atArrangedObjectIndexes:nil arrayController:nil ownerObjects:nil ownerRelationshipKey:nil];
    [self registerEvent:deleteEvent];
    [self _deleteObject: theObject];
    if (autoCommit) [self saveChanges];
}

/*!
    Remove objects from context
 */
- (void)deleteObjects:(CPArray) theObjects {
    //FIXME: create delete event as in -deleteObject:
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        [self _deleteObject:obj];
    }
    if (autoCommit) [self saveChanges];
}

/*!
    Undelete object to context. Used when doing undo
 */
- (void)unDeleteObject:(id) theObject {
    [self _unDeleteObject: theObject];
    if (autoCommit) [self saveChanges];
}

- (void)_unDeleteObject:(id) theObject {
    if ([self subDictionaryForKey:@"deleteDict" forObject:theObject]) {
        [self setSubDictionary:nil forKey:@"deleteDict" forObject:theObject];
    } else {
        [self createSubDictionaryForKey:@"insertDict" forModifyObjectDictionaryForObject:theObject];
    }
    [self registerObject:theObject];
}

/*!
    Undelete objects to context. Used when doing undo
 */
- (void)unDeleteObjects:(CPArray) theObjects {
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        [self _unDeleteObject:obj];
    }
    if (autoCommit) [self saveChanges];
}

- (void)_add:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    //CPLog.trace(@"Added new object " + [newObject className] + @" to master of type " + [masterObject className] + @" for key " + relationshipKey);
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

/*
    This method will register the newObject as a new to many relationship with the attribute relationshipKey for the master object.
    This method will not register the newObject as a new object in the object context. It has to be done by the insertObject: method.
    This method will not add the newObject to the array of to many relationship objects for the master object. This has to be done by the caller.
 */
- (void)add:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    //console.log([self className] + " " + _cmd + " " + relationshipKey);
    [self _add:newObject toRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void)unAdd:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    [self _unAdd:newObject toRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void)_unAdd:(id)newObject toRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    var updateDict = [self createSubDictionaryForKey:@"updateDict" forModifyObjectDictionaryForObject:masterObject];
    var relationsShipDict = [updateDict objectForKey:relationshipKey];
    if (relationsShipDict) {
        var insertsArray = [relationsShipDict objectForKey:@"insert"];
        if (insertsArray) {
            [insertsArray removeObject:newObject];
        }
    }
}

- (void)_delete:(id)deletedObject withRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    // Right now we do nothing. A delete of the object will be sent and it is enought for one to many relations
    //CPLog.trace(@"Deleted object " + [deletedObject className] + @" for master of type " + [masterObject className] + @" for key " + relationshipKey);
}

- (void)delete:(id)deletedObject withRelationshipWithKey:(CPString)relationshipKey forObject:(id)masterObject {
    [self _delete:deletedObject withRelationshipWithKey:relationshipKey forObject:masterObject];
    if (autoCommit) [self saveChanges];
}

- (void)delete:(id)aMapping withRelationshipWithKey:(CPString)aRelationshipKey between:(id)firstObject and:(id)secondObject {
    //FIXME: raise on index==NSNotFound?
    var leftIndex = [self _findIndexOfObject:aMapping andRemoveItFromRelationshipWithKey:aRelationshipKey ofObject:firstObject];
    var rightIndex = [self _findIndexOfObject:aMapping andRemoveItFromRelationshipWithKey:aRelationshipKey ofObject:secondObject];

    var deleteEvent = [LOManyToManyRelationshipDeleteEvent deleteEventWithMapping:aMapping leftObject:firstObject key:aRelationshipKey index:leftIndex rightObject:secondObject key:aRelationshipKey index:rightIndex];
    [self registerEvent:deleteEvent];

    [self unregisterObject:aMapping];
    var deleteDict = [self createSubDictionaryForKey:@"deleteDict" forModifyObjectDictionaryForObject:aMapping];

    if (autoCommit) [self saveChanges];
}

- (int)_findIndexOfObject:(id)anObject andRemoveItFromRelationshipWithKey:(CPString)aRelationshipKey ofObject:(id)theParent
{
    var array = [theParent valueForKey:aRelationshipKey];
    var index = [array indexOfObjectIdenticalTo:anObject];
    if (index !== CPNotFound) {
        var indexSet = [CPIndexSet indexSetWithIndex:index];
        [theParent willChange:CPKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:aRelationshipKey];
        [array removeObjectAtIndex:index];
        [theParent didChange:CPKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:aRelationshipKey];
    } else if ([array isKindOfClass:[CPArray class]] && [array faultPopulated]) {
        [CPException raise:CPRangeException reason:"Can't find index of " + anObject];
    }
    return index;
}

- (void)insert:(id)aMapping withRelationshipWithKey:(CPString)aRelationshipKey between:(id)firstObject and:(id)secondObject {
    var leftIndex = [self _findInsertionIndexForObject:aMapping andInsertItIntoRelationshipWithKey:aRelationshipKey ofObject:firstObject];
    var rightIndex = [self _findInsertionIndexForObject:aMapping andInsertItIntoRelationshipWithKey:aRelationshipKey ofObject:secondObject];

    [self _insertObject:aMapping];
    [aMapping setValue:firstObject forKey:[firstObject loObjectType]];
    [aMapping setValue:secondObject forKey:[secondObject loObjectType]];

    var insertEvent = [LOManyToManyRelationshipInsertEvent insertEventWithMapping:aMapping leftObject:firstObject key:aRelationshipKey index:leftIndex  rightObject:secondObject key:aRelationshipKey index:rightIndex];
    [self registerEvent:insertEvent];
}

- (int)_findInsertionIndexForObject:(id)anObject andInsertItIntoRelationshipWithKey:(CPString)aRelationshipKey ofObject:(id)theParent
{
    var array = [theParent valueForKey:aRelationshipKey];
    var index = [array count];
    var indexSet = [CPIndexSet indexSetWithIndex:index];
    [theParent willChange:CPKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:aRelationshipKey];
    [array insertObject:anObject atIndex:index];
    [theParent didChange:CPKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:aRelationshipKey];
    return index;
}

/*!
   Returns true if the object is already stored on the server side.
 * It does not matter if the object has changes or is deleted in the object context
 */
- (BOOL)isObjectStored:(id)theObject {
    return ![self subDictionaryForKey:@"insertDict" forObject:theObject];
}

/*!
   Returns true if the object has unsaved changes in the object context.
 */
- (BOOL) isObjectModified:(id)theObject {
    var objDict = [self modifyObjectDictionaryForObject:theObject];
    if (objDict) {
        return [objDict valueForKey:@"updateDict"] || [objDict valueForKey:@"insertDict"] || [objDict valueForKey:@"deleteDict"];
    }

    return NO;
}

/*!
   Returns true if the object context has unsaved changes.
 */
- (BOOL)hasChanges {
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
   Start a new transaction. All changes will be stored separate from previus changes.
   Transaction must be ended by a saveChanges or revert call.
 */
- (void)startTransaction {
    [undoEvents addObject:[]];
}

- (void)saveChanges {
    if (implementedDelegateMethods & LOObjectContext_objectContext_shouldSaveChanges_withObject_inserted) {
        var shouldSave = YES;
        var size = [modifiedObjects count];
        for (var i = 0; i < size; i++) {
            var modifiedObject = [modifiedObjects objectAtIndex:i];
            if (![modifiedObject isEmpty]) {
                if (![modifiedObject deleteDict]) { // Don't validate if is should be deleted
                    var insertDict = [modifiedObject insertDict];
                    var changesDict = insertDict ? [insertDict mutableCopy] : [CPMutableDictionary dictionary];
                    var updateDict = [modifiedObject updateDict];
                    if (updateDict) {
                        [changesDict addEntriesFromDictionary:updateDict];
                    }
                    shouldSave = [delegate objectContext:self shouldSaveChanges:changesDict withObject:modifiedObject.object inserted:insertDict ? YES : NO];
                    if (!shouldSave) return;
                }
            }
        }
    }
	
    [objectStore saveChangesWithObjectContext:self];

    // Remove transaction
    var count = [undoEvents count];
    if (count) {
        [undoEvents removeObjectAtIndex:count - 1];
    }
    
    // Remove modifiedObjects
    [self setModifiedObjects:[CPArray array]];
}

/*!
    Should be called by the objectStore when the saveChanges are done
 */
- (void)didSaveChangesWithResult:(id)result andStatus:(int)statusCode {
    if (implementedDelegateMethods & LOObjectContext_objectContext_didSaveChangesWithResultAndStatus) {
        [delegate objectContext:self didSaveChangesWithResult:result andStatus:statusCode];
    }
}

- (void)revert {
//    [self setModifiedObjects:[CPArray array]];

    var lastUndoEvents = [undoEvents lastObject];

    if (lastUndoEvents) {
        var count = [lastUndoEvents count];
        doNotObserveValues = YES;

        while (count--) {
            var event = [lastUndoEvents objectAtIndex:count];
            [event undoForContext:self];
        }
        [undoEvents removeObject:lastUndoEvents];
        doNotObserveValues = NO;
    }
}

- (id)modifyObjectDictionaryForObject:(id) theObject {
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

- (void)removeModifyObjectDictionaryForObject:(id) theObject {
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

- (void)setSubDictionary:(CPDictionary)subDict forKey:(CPString) key forObject:(id) theObject {
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

- (CPDictionary)subDictionaryForKey:(CPString) key forObject:(id) theObject {
    var objDict = [self modifyObjectDictionaryForObject:theObject];
    if (objDict) {
        var subDict = [objDict valueForKey:key];
        if (subDict) {
            return subDict;
        }
    }
    return null;
}

- (CPDictionary)createSubDictionaryForKey:(CPString) key forModifyObjectDictionaryForObject:(id) theObject {
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

- (void)registerEvent:(LOUpdateEvent)updateEvent {
    var lastUndoEvents = [undoEvents lastObject];

    if (!lastUndoEvents) {
        lastUndoEvents = [CPArray array];
        [undoEvents addObject:lastUndoEvents];
    }

    [lastUndoEvents addObject:updateEvent];
}

- (void)triggerFault:(CPArray)faultArray withCompletionBlock:(Function)aCompletionBlock {
    if ([faultArray isKindOfClass:[LOFaultArray class]]) {
        [faultArray requestFaultWithCompletionBlock:aCompletionBlock];
    }
}

@end
