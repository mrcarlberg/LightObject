/*
 * LOSimpleJSONObjectStore.j
 *
 * Created by Martin Carlberg on Mars 5, 2012.
 * Copyright 2012, All rights reserved.
 */

@import <Foundation/CPObject.j>
@import <Foundation/CPURLConnection.j>
@import <Foundation/CPURLRequest.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectContext.j"
@import "LOObjectStore.j"
@import "LOFaultArray.j"
@import "LOFaultObject.j"

LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector = @selector(objectsReceived:withConnectionDictionary:);
LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector = @selector(updateStatusReceived:withConnectionDictionary:);
LOFaultArrayRequestedFaultReceivedForConnectionSelector = @selector(faultReceived:withConnectionDictionary:);

@implementation LOSimpleJSONObjectStore : LOObjectStore {
    CPDictionary    attributeKeysForObjectClassName;
    CPArray         connections;        // Array of dictionary with following keys: connection, fetchSpecification, objectContext, receiveSelector
    CPDictionary    faultObjectRequests;
}

- (id)init {
    self = [super init];
    if (self) {
        connections = [CPArray array];
        attributeKeysForObjectClassName = [CPDictionary dictionary];
        faultObjectRequests = [CPMutableDictionary dictionary];
    }
    return self;
}

- (CPArray)requestObjectsWithFetchSpecification:(LOFFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext withCompletionBlock:(Function)aCompletionBlock {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext withCompletionBlock:aCompletionBlock fault:nil];
}

- (CPArray)requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext withCompletionBlock:(Function)aCompletionBlock {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext withCompletionBlock:aCompletionBlock fault:faultArray];
}

- (CPArray)requestFaultObject:(LOFaultObject)faultObject withFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext withCompletionBlock:(Function)aCompletionBlock {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext withCompletionBlock:aCompletionBlock fault:faultObject];
}

- (void)requestFaultObject:(LOFaultObject)aFaultObject withCompletionBlock:(Function)aCompletionBlock {
    var faultObjectRequestsForEntity = [faultObjectRequests objectForKey:aFaultObject.entityName];
    if (!faultObjectRequestsForEntity) {
        faultObjectRequestsForEntity = [];
        [faultObjectRequests setObject:faultObjectRequestsForEntity forKey:aFaultObject.entityName];
    }
    var objectStore = [objectContext objectStore];
    var primaryKeyAttribute = [objectStore primaryKeyAttributeForType:aFaultObject.entityName objectContext:objectContext];
    var qualifier = [CPComparisonPredicate predicateWithLeftExpression:[CPExpression expressionForKeyPath:primaryKeyAttribute]
                                                       rightExpression:[CPExpression expressionForConstantValue:aFaultObject.primaryKey]
                                                              modifier:CPDirectPredicateModifier
                                                                  type:CPEqualToPredicateOperatorType
                                                               options:0];
    fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:aFaultObject.entityName qualifier:qualifier];
    [objectContext requestFaultObject:self withFetchSpecification:fetchSpecification withCompletionBlock:aCompletionBlock];
    [[CPNotificationCenter defaultCenter] postNotificationName:LOFaultDidFireNotification object:aFaultObject userInfo:[CPDictionary dictionaryWithObjects:[fetchSpecification] forKeys:[LOFaultFetchSpecificationKey]]];

}
- (CPArray)requestObjectsWithFetchSpecification:(LOFFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext withCompletionBlock:(Function)aCompletionBlock faults:(id)faults {
    var request = [self urlForRequestObjectsWithFetchSpecification:fetchSpecification];
    if (fetchSpecification.requestPreProcessBlock) {
        fetchSpecification.requestPreProcessBlock(request);
    }
    var url = [[request URL] absoluteString];
    var connection = [CPURLConnection connectionWithRequest:request delegate:self];
    [connections addObject:{connection: connection, fetchSpecification: fetchSpecification, objectContext: objectContext, receiveSelector: LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector, faults:faults, url: url, completionBlocks: aCompletionBlock ? [aCompletionBlock] : nil}];
    if (objectContext.debugMode & LOObjectContextDebugModeFetch) CPLog.trace(@"LOObjectContextDebugModeFetch: Entity: " + [fetchSpecification entityName] + @", url: " + url);
}

- (void)connection:(CPURLConnection)connection didReceiveResponse:(CPHTTPURLResponse)response {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    connectionDictionary.response = response;
}

- (void)connection:(CPURLConnection)connection didReceiveData:(CPString)data {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    var receivedData = connectionDictionary.receivedData;
    if (receivedData) {
        connectionDictionary.receivedData = [receivedData stringByAppendingString:data];
    } else {
        connectionDictionary.receivedData = data;
    }
}

- (void)connectionDidFinishLoading:(CPURLConnection)connection {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    var response = connectionDictionary.response;
    var receivedData = connectionDictionary.receivedData;
    var error = [self errorForResponse:response andData:receivedData fromURL:connectionDictionary.url];
    var objectContext = connectionDictionary.objectContext;
    var jSON = receivedData ? [receivedData objectFromJSON] : nil;

    if (error) {
        [objectContext errorReceived:error withFetchSpecification:connectionDictionary.fetchSpecification result:jSON statusCode:[response statusCode] completionBlocks:connectionDictionary.completionBlocks];
    } else {
        if (objectContext.debugMode & LOObjectContextDebugModeReceiveData) CPLog.trace(@"LOObjectContextDebugModeReceiveData: Url: " + connectionDictionary.url + @", data: (" + (jSON ? jSON.length : 0) + ") " + receivedData);
        [self performSelector:connectionDictionary.receiveSelector withObject:jSON withObject:connectionDictionary]
    }
    [connections removeObject:connectionDictionary];
}

- (void)connection:(CPURLConnection)connection didFailWithError:(id)error {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    [connections removeObject:connectionDictionary];
    CPLog.error(@"CPURLConnection didFailWithError: " + error);
}

- (id)connectionDictionaryForConnection:(CPURLConnection)connection {
    for (var i = 0, size = [connections count]; i < size; i++) {
        var connectionDictionary = [connections objectAtIndex:i];
        if (connection === connectionDictionary.connection) {
            return connectionDictionary;
        }
    }
    return nil;
}

- (id)connectionDictionaryForFault:(id <LOFault>)fault {
    for (var i = 0, size = [connections count]; i < size; i++) {
        var connectionDictionary = [connections objectAtIndex:i];
        if ([connectionDictionary.faults containsObject:fault]) {
            return connectionDictionary;
        }
    }
    return nil;
}

/*!
 Creates objects from JSON. If there is a relationship it is up to this method to create a LOFaultArray, LOFaultObject or the actual object.
 */
- (CPArray)_objectsFromJSON:(CPArray)jSONObjects withConnectionDictionary:(id)connectionDictionary collectAllObjectsIn:(CPDictionary)receivedObjects {
    if (!jSONObjects.isa || ![jSONObjects isKindOfClass:CPArray])
        return jSONObjects;
    var objectContext = connectionDictionary.objectContext;
    var fetchSpecification = connectionDictionary.fetchSpecification;
    var entityName = fetchSpecification.entityName;
    var possibleToOneFaultObjects =[CPMutableArray array];
    var newArray = [CPMutableArray array];
    var size = [jSONObjects count];
    [objectContext setDoNotObserveValues:YES];
    for (var i = 0; i < size; i++) {
        var row = jSONObjects[i];
        var type = [self typeForRawRow:row objectContext:objectContext];
        var uuid = [self primaryKeyForRawRow:row forType:type objectContext:objectContext];
        var objectFromObjectContext;    // Keep track if the object is already in the objectContext
        var obj = [receivedObjects objectForKey:uuid];
        var fault = nil;
        if (obj) {
            objectFromObjectContext = [objectContext objectForGlobalId:uuid noFaults:connectionDictionary.fault];
        } else {
            obj = [objectContext objectForGlobalId:uuid];
            var isFault = [obj conformsToProtocol:@protocol(LOFault)];
            // If this is a fetch for a fault we want a new object. Also if we didn't find any in the object context
            if ((connectionDictionary.faults && isFault) || !obj) {
                obj = nil;
                objectFromObjectContext = NO;
            } else {
                // Now we have an object but if it is a fault we should first create a new object and then morph the fault to this object.
                // If the object already exists in the object context we set objectFromObjectContext so attributes that are not included in the
                // answer can be set to nil below.
                objectFromObjectContext = YES;
                if (isFault)
                    fault = obj;
            }

            // Create a new object if we don't have it or the one we found is a fault that we should later morph to.
            if(!obj || fault) {
                obj = [self newObjectForType:type objectContext:objectContext];
            }

            // Put the object or the fault that we should morph in the receivedObjects dictionary
            if (obj) {
                [receivedObjects setObject:fault || obj forKey:uuid];
            }
        }
        if (obj) {
            var relationshipKeys = [self relationshipKeysForObject:obj];
            var columns = [self attributeKeysForObject:obj];

            [self setPrimaryKey:uuid forObject:obj];
            var columnSize = [columns count];

            for (var j = 0; j < columnSize; j++) {
                var column = [columns objectAtIndex:j];

                // Does the fetched row has this column or does the object already exists in the object context. The later to nil out the value if it already exists.
                if (row.hasOwnProperty(column) || objectFromObjectContext) {
                    var value = row[column];
                    if (value == null) {
                        /* Force nil if either null (which is same as nil, ugh!) or undefined. */
                        value = nil;
                    }
//                    CPLog.trace(@"tracing: " + column + @" value: " + value);
//                    CPLog.trace(@"tracing: " + column + @": " + value + (value && value.isa ? @", value class: " + [value className] : ""));
                    if ([self isForeignKeyAttribute:column forType:type objectContext:objectContext]) {    // Handle to one relationship.
                        column = [self toOneRelationshipAttributeForForeignKeyAttribute:column forType:type objectContext:objectContext]; // Remove "_fk" at end
                        if (value) {
                            var toOne = [objectContext objectForGlobalId:value];
                            if (toOne) {
                                value = toOne;
                            } else {
                                // Add it to a list and try again after we have registered all objects.
                                [possibleToOneFaultObjects addObject:{@"object":obj, @"relationshipKey":column, @"globalId":value}];
                                value = nil;
                            }
                        }
                    } else if (value && Object.prototype.toString.call( value ) === '[object Object]' && Object.keys(value).length === 1 && value._fault != null) { // Handle to many relationship as fault. Backend sends a JSON dictionary. We don't care what it is.
                        value = [[LOFaultArray alloc] initWithObjectContext:objectContext masterObject:obj relationshipKey:column];
                    } else if (value && [relationshipKeys containsObject:column] && [value isKindOfClass:CPArray]) { // Handle to many relationship as plain objects
                        // The array contains only type and primaryKey for the relationship objects.
                        // The complete relationship objects can be sent before or later in the list of all objects.
                        var relations = value;
                        value = [CPArray array];
                        var relationsSize = [relations count];
                        for (var k = 0; k < relationsSize; k++) {
                            var relationRow = [relations objectAtIndex:k];
                            var relationType = [self typeForRawRow:relationRow objectContext:objectContext];
                            var relationUuid = [self primaryKeyForRawRow:relationRow forType:relationType objectContext:objectContext];
                            var relationObj = [receivedObjects objectForKey:relationUuid];
                            if (!relationObj) {
                                relationObj = [self newObjectForType:relationType objectContext:objectContext];
                                if (relationObj) {
                                    [self setPrimaryKey:relationUuid forObject:relationObj];
                                    [receivedObjects setObject:relationObj forKey:relationUuid];
                                }
                            }
                            if (relationObj) {
                                [value addObject:relationObj];
                            }
                        }
                    }
                    if (value !== [obj valueForKey:column]) {
                        [obj setValue:value forKey:column];
                        // FIXME: Clean up posible changes in object context if a new value has been set
                    }
                }
            }

            // If we already has the fault registered in the object context, morph it to the received object
            if (fault) {
                // If there is a fetch outstanding for the fault we have to take care of it.
                if (fault.faultFired && !fault.faultPopulated) {
                    var connectionDictionary = [self connectionDictionaryForFault:fault];
                    if (connectionDictionary) {
                        var faultDidPopulateNotificationUserInfo = [CPDictionary dictionaryWithObjects:[connectionDictionary.fetchSpecification] forKeys:[LOFaultFetchSpecificationKey]];
                        [fault morphObjectTo:obj callCompletionBlocks:/*connectionDictionary.completionBlocks*/nil postNotificationWithObject:self andUserInfo:faultDidPopulateNotificationUserInfo];
                        // Delete the fault in the connection dictionary so when this request complets it will be treated as a regular reqest and not a fault request
                        [connectionDictionary.faults removeObject:fault];
                        if([connectionDictionary.faults count] === 0)
                            delete connectionDictionary.faults;
                    }
                } else {
                    [fault morphObjectTo:obj];
                }
            }

            if (type === entityName) {
                // Add the morphed fault or the new received object to the list of received objects
                [newArray addObject:fault || obj];
            }
        }
    }
    // Try again to find to one relationship objects. They might been registered now
    var size = [possibleToOneFaultObjects count];
    var toOneFaults = [CPMutableDictionary dictionary];
    for (var i = 0; i < size; i++) {
        var possibleToOneFaultObject = [possibleToOneFaultObjects objectAtIndex:i];
        //var toOne = [objectContext objectForGlobalId:possibleToOneFaultObject.globalId];
        var globalId = possibleToOneFaultObject.globalId;
        var toOne = [receivedObjects objectForKey:globalId];
        if (!toOne) {
            toOne = [toOneFaults objectForKey:globalId];
            if (!toOne) {
                // This is hard coded. Uses relationshipKey as entityName. We can change this when we have a full database model.
                toOne = [LOFaultObject faultObjectWithObjectContext:objectContext entityName:possibleToOneFaultObject.relationshipKey primaryKey:globalId];
                [objectContext _registerObject:toOne forGlobalId:globalId];
                [toOneFaults setObject:toOne forKey:globalId];
                //console.log([self className] + " " + _cmd + " Can't find object for toOne relationship '" + possibleToOneFaultObject.relationshipKey + "' (" + toOne + ") on object " + possibleToOneFaultObject.object);
            }
        }
        [possibleToOneFaultObject.object setValue:toOne forKey:possibleToOneFaultObject.relationshipKey];
    }
    [objectContext setDoNotObserveValues:NO];
    return newArray;
}

- (void) _registerOrReplaceObject:(CPArray) theObjects withConnectionDictionary:(id)connectionDictionary{
    var objectContext = connectionDictionary.objectContext;
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        var type = [self typeOfObject:obj];
        if ([objectContext isObjectRegistered:obj]) {   // If we already got the object transfer all attributes to the old object
            //CPLog.trace(@"tracing: _registerOrReplaceObject: Object already in objectContext: " + obj);
            [objectContext setDoNotObserveValues:YES];
            var oldObject = [objectContext objectForGlobalId:[self globalIdForObject:obj]];
            var columns = [self attributeKeysForObject:obj];
            var columnSize = [columns count];
            for (var j = 0; j < columnSize; j++) {
                var columnKey = [columns objectAtIndex:j];
                if ([self isForeignKeyAttribute:columnKey forType:type objectContext:objectContext]) {    // Handle to one relationship.
                    columnKey = [self toOneRelationshipAttributeForForeignKeyAttribute:columnKey forType:type objectContext:objectContext]; // Remove "_fk" at end
                }
                var newValue = [obj valueForKey:columnKey];
                var oldValue = [oldObject valueForKey:columnKey];
                if (newValue !== oldValue) {
                    [oldObject setValue:newValue forKey:columnKey];
                }
            }
            [objectContext setDoNotObserveValues:NO];
        }
    }
}

- (void) objectsReceived:(CPArray)jSONObjects withConnectionDictionary:(id)connectionDictionary {
    var objectContext = connectionDictionary.objectContext;
    var receivedObjects = [CPDictionary dictionary]; // Collect all object with id as key
    var newArray = [self _objectsFromJSON:jSONObjects withConnectionDictionary:connectionDictionary collectAllObjectsIn:receivedObjects];
/*    var receivedObjectList = [receivedObjects allValues];
    [self _registerOrReplaceObject:receivedObjectList withConnectionDictionary:connectionDictionary];
    if (newArray.isa && [newArray isKindOfClass:CPArray]) {
        newArray = [self _arrayByReplacingNewObjects:newArray withObjectsAlreadyRegisteredInContext:objectContext];
    }
*/    var faults = connectionDictionary.faults;
    if (faults) {
        [objectContext faultReceived:newArray withFetchSpecification:connectionDictionary.fetchSpecification withCompletionBlocks:connectionDictionary.completionBlocks faults:faults];
    } else {
        [objectContext objectsReceived:newArray allReceivedObjects:[receivedObjects allValues] withFetchSpecification:connectionDictionary.fetchSpecification withCompletionBlocks:connectionDictionary.completionBlocks];
    }
}

- (CPArray)_arrayByReplacingNewObjects:(CPArray)newObjects withObjectsAlreadyRegisteredInContext:(LOObjectContext)anObjectContext {
    var result = [CPMutableArray array];

    var newObjectsCount = [newObjects count];
    for (var i = 0; i < newObjectsCount; i++) {
        var anObject = [newObjects objectAtIndex:i];
        if ([anObjectContext isObjectRegistered:anObject]) {
            anObject = [anObjectContext objectForGlobalId:[self globalIdForObject:anObject]];
        }
        [result addObject:anObject];
    }

    return result;
}

- (void)updateStatusReceived:(CPArray)jSONObjects withConnectionDictionary:(id)connectionDictionary {
    //CPLog.trace(@"tracing: LOF update Status: " + [CPString JSONFromObject:jSONObjects]);
    var objectContext = connectionDictionary.objectContext;
    var modifiedObjects = connectionDictionary.modifiedObjects;
    var size = [modifiedObjects count];
    if (jSONObjects && jSONObjects.insertedIds) {  // Update objects temp id to real uuid if server return these.
        for (var i = 0; i < size; i++) {
            var objDict = [modifiedObjects objectAtIndex:i];
            var obj = [objDict object];
            var insertDict = [objDict insertDict];
            if (insertDict) {
                var tmpId = [CPString stringWithFormat:@"%d", i];
                var uuid = jSONObjects.insertedIds[tmpId];
                [objectContext reregisterObject:obj withNewGlobalId:uuid];
                [self setPrimaryKey:uuid forObject:obj];
            }
        }
    }
    var completionBlocks = connectionDictionary.completionBlocks;
    [objectContext didSaveChangesWithResult:jSONObjects andStatus:[connectionDictionary.response statusCode] withCompletionBlocks:completionBlocks];
}

- (void)saveChangesWithObjectContext:(LOObjectContext)objectContext withCompletionBlock:(Function)aCompletionBlock {
    var modifyDict = [self _jsonDictionaryForModifiedObjectsWithObjectContext:objectContext];
    if ([modifyDict count] > 0) {       // Only save if thera are changes
        var json = [LOJSKeyedArchiver archivedDataWithRootObject:modifyDict];
        var url = [self urlForSaveChangesWithData:json];
        var jsonText = [CPString JSONFromObject:json];
	    // DEBUG: Uncoment to see posted data
        if (objectContext.debugMode & LOObjectContextDebugModeSaveChanges) CPLog.trace(@"Save Changes POST Data: " + jsonText);
        var request = [CPURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:jsonText];
        var connection = [CPURLConnection connectionWithRequest:request delegate:self];
        var modifiedObjects = [objectContext modifiedObjects];
        [connections addObject:{connection: connection, objectContext: objectContext, modifiedObjects: modifiedObjects, receiveSelector: LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector, completionBlocks: aCompletionBlock ? [aCompletionBlock] : nil}];
    }
    [super saveChangesWithObjectContext:objectContext withCompletionBlock:aCompletionBlock];
}

- (CPMutableDictionary)_jsonDictionaryForModifiedObjectsWithObjectContext:(LOObjectContext)objectContext {
    var modifyDict = [CPMutableDictionary dictionary];
    var modifiedObjects = [objectContext modifiedObjects];
    var size = [modifiedObjects count];
    if (size > 0) {
        var insertArray = [CPMutableArray array];
        var updateArray = [CPMutableArray array];
        var deleteArray = [CPMutableArray array];
        var insertedObjectToTempIdDict = [CPMutableDictionary dictionary];
        for (var i = 0; i < size; i++) {
            var objDict = [modifiedObjects objectAtIndex:i];
            var obj = [objDict object];
            var insertDict = [objDict insertDict];
            var deleteDict = [objDict deleteDict];
            if (insertDict && !deleteDict) {    // Don't do this if it is also deleted
                var primaryKey = [self primaryKeyForObject:obj];
                var insertDictCopy = [insertDict copy];
                // Use primary key if object has it, otherwise create a tmp id
                if (primaryKey) {
                    var type = [self typeOfObject:obj];
                    var primaryKeyAttribute = [self primaryKeyAttributeForType:type objectContext:objectContext];
                    [insertDictCopy setObject:primaryKey forKey:primaryKeyAttribute];
                } else {
                    var tmpId = [CPString stringWithFormat:@"%d", i];
                    [insertedObjectToTempIdDict setObject:tmpId forKey:[obj UID]];
                    [objDict setTmpId:tmpId];
                    [insertDictCopy setObject:tmpId forKey:@"_tmpid"];
                }
                [insertDictCopy setObject:[self typeOfObject:obj] forKey:@"_type"];
                [insertArray addObject:insertDictCopy];
            }
        }
        for (var i = 0; i < size; i++) {
            var objDict = [modifiedObjects objectAtIndex:i];
            var obj = [objDict object];
            var type = [self typeOfObject:obj];
            var primaryKeyAttribute = [self primaryKeyAttributeForType:type objectContext:objectContext];
            var insertDict = [objDict insertDict];
            var deleteDict = [objDict deleteDict];
            var updateDict = [objDict updateDict];
            if (updateDict && !deleteDict) { // Don't do this if it is deleted
                var updateDictCopy = [CPMutableDictionary dictionary];
                var updateDictKeys = [updateDict allKeys];
                var updateDictKeysSize = [updateDictKeys count];
                for (var j = 0; j < updateDictKeysSize; j++) {
                    var updateDictKey = [updateDictKeys objectAtIndex:j];
                    var updateDictValue = [updateDict objectForKey:updateDictKey];
                    if ([updateDictValue isKindOfClass:CPDictionary]) {
                        var insertedRelationshipArray = [CPArray array];
                        var insertedRelationshipObjects = [updateDictValue objectForKey:@"insert"];
                        var insertedRelationshipObjectsSize = [insertedRelationshipObjects count];
                        for (var k = 0; k < insertedRelationshipObjectsSize; k++) {
                            var insertedRelationshipObject = [insertedRelationshipObjects objectAtIndex:k];
                            var insertedRelationshipObjectPrimaryKey = [self primaryKeyForObject:insertedRelationshipObject];
                            // Use primary key if object has it, otherwise use the created tmp id
                            if (insertedRelationshipObjectPrimaryKey) {
                                var insertedRelationshipObjectType = [self typeOfObject:insertedRelationshipObject];
                                var insertedRelationshipObjectPrimaryKeyAttribute = [self primaryKeyAttributeForType:insertedRelationshipObjectType objectContext:objectContext];
                                [insertedRelationshipArray addObject:[CPDictionary dictionaryWithObject:insertedRelationshipObjectPrimaryKey forKey:insertedRelationshipObjectPrimaryKeyAttribute]];
                            } else {
                                var insertedRelationshipObjectTempId = [insertedObjectToTempIdDict objectForKey:insertedRelationshipObject._UID];
                                if (!insertedRelationshipObjectTempId) {
                                    CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Can't get primary key or temp. id for object " + insertedRelationshipObject + " on relationship " + updateDictKey);
                                }
                                [insertedRelationshipArray addObject:[CPDictionary dictionaryWithObject:insertedRelationshipObjectTempId forKey:@"_tmpid"]];
                            }
                        }
                        updateDictValue = [CPDictionary dictionaryWithObject:insertedRelationshipArray forKey:@"inserts"];
                    }
                    [updateDictCopy setObject:updateDictValue forKey:updateDictKey];
                }
                [updateDictCopy setObject:type forKey:@"_type"];
                var uuid = [self primaryKeyForObject:obj];
                if (uuid) {
                    [updateDictCopy setObject:uuid forKey:primaryKeyAttribute];
                } else {
                    [updateDictCopy setObject:[objDict tmpId] forKey:@"_tmpid"];
                }
                [updateArray addObject:updateDictCopy];
            }
            if (deleteDict && !insertDict) {    // Don't delete if it is also inserted, just skip it
                var deleteDictCopy = [deleteDict mutableCopy];
                [deleteDictCopy setObject:type forKey:@"_type"];
                var uuid = [self primaryKeyForObject:obj];
                if (uuid) {
                    [deleteDictCopy setObject:uuid forKey:primaryKeyAttribute];
                    [deleteArray addObject:deleteDictCopy];
                } else {
                    var tmpId = [objDict tmpId];
                    if (tmpId) {
                        [deleteDictCopy setObject:tmpId forKey:@"_tmpid"];
                        [deleteArray addObject:deleteDictCopy];
                    } else {
                        CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Has no primary key or tmpId for object:" + obj + " objDict: " + [objDict description]);
                    }
                }
            }
        }
        if ([insertArray count] > 0) {
            [modifyDict setObject:insertArray forKey:@"inserts"];
        }
        if ([updateArray count] > 0) {
            [modifyDict setObject:updateArray forKey:@"updates"];
        }
        if ([deleteArray count] > 0) {
            [modifyDict setObject:deleteArray forKey:@"deletes"];
        }
    }
    return modifyDict;
}

- (CPString)globalIdForObject:(id)theObject {
    //CPLog.trace(@"[" + [self className] + @" " + _cmd + @"] theObject:" + [theObject description]);
    if ([theObject respondsToSelector:@selector(uuid)]) {
        var objectType = [self typeOfObject:theObject];
        var uuid = [self globalIdForObjectType:objectType andPrimaryKey:[self primaryKeyForObject:theObject]];

        if (!uuid) {    // If we don't have one from the backend, create a temporary until we get one.
            uuid = objectType + theObject._UID;
        }
        return uuid;
    }
    return nil;
}

- (CPArray)relationshipKeysForObject:(id)theObject {
    return [theObject respondsToSelector:@selector(relationshipKeys)] ? [theObject relationshipKeys] : [];
}


- (CPArray)attributeKeysForObject:(id)theObject {
    return [theObject respondsToSelector:@selector(attributeKeys)] ? [theObject attributeKeys] : [self _createAttributeKeysFromRow:nil forObject:theObject];
}

- (CPArray) _createAttributeKeysFromRow:(id) row forObject: theObject {
    var className = [theObject className];
    var attributeKeysSet = [attributeKeysForObjectClassName objectForKey:className];
    if (row) {
        if (!attributeKeysSet) {
            attributeKeysSet = [CPSet set];
            [attributeKeysForObjectClassName setObject:attributeKeysSet forKey:className];
        }
        for (var key in row) {
            [attributeKeysSet setObject:key];
        }
    }
    return [attributeKeysSet allValues];
}

- (void)addCompletionBlock:(Function)aCompletionBlock toTriggeredFault:(id <LOFault>)aFault {
    var size = [connections count];
    for (var i = 0; i < size; i++) {
        var connectionDictionary = [connections objectAtIndex:i];
        if ([connectionDictionary.faults containsObject:aFault]) {
            [connectionDictionary.completionBlocks addObject:aCompletionBlock];
        }
    }
}

@end
