/*
 * LOSimpleJSONObjectStore.j
 *
 * Created by Martin Carlberg on Mars 5, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectContext.j"
@import "LOObjectStore.j"
@import "LOFaultArray.j"

LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector = @selector(objectsReceived:withConnectionDictionary:);
LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector = @selector(updateStatusReceived:withConnectionDictionary:);
LOFaultArrayRequestedFaultReceivedForConnectionSelector = @selector(faultReceived:withConnectionDictionary:);

@implementation LOSimpleJSONObjectStore : LOObjectStore {
    CPDictionary    attributeKeysForObjectClassName;
    CPArray         connections;        // Array of dictionary with following keys: connection, fetchSpecification, objectContext, receiveSelector
}

- (id)init {
    self = [super init];
    if (self) {
        connections = [CPArray array];
        attributeKeysForObjectClassName = [CPDictionary dictionary];
    }
    return self;
}

- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext faultArray:nil];
}

- (CPArray) requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification)fetchSpecification objectContext:(LOObjectContext) objectContext {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext faultArray:faultArray];
}

- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext faultArray:(LOFaultArray)faultArray {
    var url = [self urlForRequestObjectsWithFetchSpecification:fetchSpecification];
    var request = [CPURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    var connection = [CPURLConnection connectionWithRequest:request delegate:self];
    [connections addObject:{connection: connection, fetchSpecification: fetchSpecification, objectContext: objectContext, receiveSelector: LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector, faultArray:faultArray}];
    if (!url) debugger;
    CPLog.trace(@"tracing: requestObjectsWithFetchSpecification: " + [fetchSpecification entityName] + @", url: " + url);
}

- (void)connection:(CPURLConnection)connection didReceiveResponse:(CPHTTPURLResponse)response {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    connectionDictionary.statusCode = [response statusCode];
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
    var receivedData = connectionDictionary.receivedData;
    if (receivedData && [receivedData length] > 0) {
//        CPLog.trace(@"tracing: LOF objectsReceived: " + receivedData);
        var jSON = [receivedData objectFromJSON];
        [self performSelector:connectionDictionary.receiveSelector withObject:jSON withObject:connectionDictionary]
        [connections removeObject:connectionDictionary];
    } else {
//        [errorText setObjectValue:@"F√•r ej kontakt med Boplats"];
    }
}

- (void)connection:(CPURLConnection)connection didFailWithError:(id)error {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    [connections removeObject:connectionDictionary];
    CPLog.error(@"CPURLConnection didFailWithError: " + error);
}

- (id) connectionDictionaryForConnection:(CPURLConnection) connection {
    var size = [connections count];
    for (i = 0; i < size; i++) {
        var connectionDictionary = [connections objectAtIndex:i];
        if (connection === connectionDictionary.connection) {
            return connectionDictionary;
        }
    }
    return nil;
}

/*!
 Creates objects from JSON. If there is a relationship it is up to this method to create a LOFaultArray, LOFaultObject or the actual object.
 */
- (CPArray) _objectsFromJSON:(CPArray)jSONObjects withConnectionDictionary:(id)connectionDictionary collectAllObjectsIn:(CPDictionary)receivedObjects {
    if (!jSONObjects.isa || ![jSONObjects isKindOfClass:CPArray])
        return jSONObjects;
    var objectContext = connectionDictionary.objectContext;
    var fetchSpecification = connectionDictionary.fetchSpecification;
    var entityName = fetchSpecification.entityName;
    var possibleToOneFaultObjects =[CPMutableArray array];
    var newArray = [CPArray array];
    var size = [jSONObjects count];
    [objectContext setDoNotObserveValues:YES];
    for (i = 0; i < size; i++) {
        var row = jSONObjects[i];
        var type = [self typeForRawRow:row objectContext:objectContext];
        var uuid = [self primaryKeyForRawRow:row forType:type objectContext:objectContext];
        var obj = [receivedObjects objectForKey:uuid];
        if (!obj) {
            obj = [objectContext objectForGlobalId:uuid];
            if (!obj) {
                obj = [self newObjectForType:type objectContext:objectContext];
            }
            if (obj) {
                [receivedObjects setObject:obj forKey:uuid];
            }
        }
        if (obj) {
            var columns = [self _attributeKeysForObject:obj];
            if (!columns) {
                columns = [self _createAttributeKeysFromRow:row forObject:obj];
            }
            [obj setUuid:uuid];
            var columnSize = [columns count];
            for (var j = 0; j < columnSize; j++) {
                var column = [columns objectAtIndex:j];
                if (row.hasOwnProperty(column)) {
                    var value = row[column];
//                    CPLog.trace(@"tracing: " + column + @" value: " + value);
//                    CPLog.trace(@"tracing: " + column + @" value class: " + [value className]);
                    if ([self isForeignKeyAttribute:column forType:type objectContext:objectContext]) {    // Handle to one relationship.
                        column = [self toOneRelationshipAttributeForForeignKeyAttribute:column forType:type objectContext:objectContext]; // Remove "_fk" at end
                        if (value) {
                            var toOne = [objectContext objectForGlobalId:value];
                            if (toOne) {
                                value = toOne;
                            } else {
                                // Add it to a list and try again after we have registered all objects.
                                [possibleToOneFaultObjects addObject:{@"object":obj , @"relationshipKey":column , @"globalId":value}];
                                value = nil;//[[LOFaultObject alloc] init];
                            }
                        }
                    } else if (Object.prototype.toString.call( value ) === '[object Object]') { // Handle to many relationship as fault. Backend sends a JSON dictionary. We don't care what it is.
                        value = [[LOFaultArray alloc] initWithObjectContext:objectContext masterObject:obj relationshipKey:column];
                    } else if ([value isKindOfClass:CPArray]) { // Handle to many relationship as plain objects
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
                                    [relationObj setUuid:relationUuid];
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
            if (type === entityName) {
                [newArray addObject:obj];
            }
        }
    }
    [objectContext setDoNotObserveValues:NO];
    // Try again to find to one relationship objects. They might been registered now
    var size = [possibleToOneFaultObjects count];
    for (var i = 0; i < size; i++) {
        var possibleToOneFaultObject = [possibleToOneFaultObjects objectAtIndex:i];
        //var toOne = [objectContext objectForGlobalId:possibleToOneFaultObject.globalId];
        var toOne = [receivedObjects objectForKey:possibleToOneFaultObject.globalId];
        if (toOne) {
            [possibleToOneFaultObject.object setValue:toOne forKey:possibleToOneFaultObject.relationshipKey];
        } else {
            console.log([self className] + " " + _cmd + " Can't find object for toOne relationship '" + possibleToOneFaultObject.relationshipKey + "' (" + toOne + ") on object " + possibleToOneFaultObject.object);
        }
    }
    return newArray;
}

- (void) _registerOrReplaceObject:(CPArray) theObjects withConnectionDictionary:(id)connectionDictionary{
    var objectContext = connectionDictionary.objectContext;
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        var type = [self typeOfObject:obj];
        if ([objectContext isObjectRegistered:obj]) {   // If we already got the object transfer all attributes to the old object
            CPLog.trace(@"tracing: _registerOrReplaceObject: Object already in objectContext: " + obj);
            [objectContext setDoNotObserveValues:YES];
            var oldObject = [objectContext objectForGlobalId:[self globalIdForObject:obj]];
            var columns = [self _attributeKeysForObject:obj];
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

- (void) objectsReceived:(CPArray) jSONObjects withConnectionDictionary:(id)connectionDictionary {
    var objectContext = connectionDictionary.objectContext;
    var receivedObjects = [CPDictionary dictionary]; // Collect all object with id as key
    var newArray = [self _objectsFromJSON:jSONObjects withConnectionDictionary:connectionDictionary collectAllObjectsIn:receivedObjects];
/*    var receivedObjectList = [receivedObjects allValues];
    [self _registerOrReplaceObject:receivedObjectList withConnectionDictionary:connectionDictionary];
    if (newArray.isa && [newArray isKindOfClass:CPArray]) {
        newArray = [self _arrayByReplacingNewObjects:newArray withObjectsAlreadyRegisteredInContext:objectContext];
    }
*/    var faultArray = connectionDictionary.faultArray;
    if (faultArray) {
        [objectContext faultReceived:newArray withFetchSpecification:connectionDictionary.fetchSpecification faultArray:faultArray];
    } else {
        [objectContext objectsReceived:newArray withFetchSpecification:connectionDictionary.fetchSpecification];
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

- (void) updateStatusReceived:(CPArray) jSONObjects withConnectionDictionary:(id)connectionDictionary {
    CPLog.trace(@"tracing: LOF update Status: " + [CPString JSONFromObject:jSONObjects]);
    var objectContext = connectionDictionary.objectContext;
    var modifiedObjects = connectionDictionary.modifiedObjects;
    var size = [modifiedObjects count];
    if (jSONObjects.insertedIds) {  // Update objects temp id to real uuid if server return these.
        for (var i = 0; i < size; i++) {
            var objDict = [modifiedObjects objectAtIndex:i];
            var obj = [objDict object];
            var insertDict = [objDict insertDict];
            if (insertDict) {
                var tmpId = [CPString stringWithFormat:@"%d", i];
                var uuid = jSONObjects.insertedIds[tmpId];
                [objectContext reregisterObject:obj fromGlobalId:[self globalIdForObject:obj] toGlobalId:uuid];
                [obj setUuid:uuid];
            }
        }
    }
    [objectContext didSaveChangesWithResult:jSONObjects andStatus:connectionDictionary.statusCode];
}

- (void) saveChangesWithObjectContext:(LOObjectContext) objectContext {
    var modifyDict = [self _jsonDictionaryForModifiedObjectsWithObjectContext:objectContext];
    if ([modifyDict count] > 0) {       // Only save if thera are changes
        var json = [LOJSKeyedArchiver archivedDataWithRootObject:modifyDict];
        var url = [self urlForSaveChangesWithData:json];
        var jsonText = [CPString JSONFromObject:json];
        CPLog.trace(@"POST Data: " + jsonText);
        var request = [CPURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:jsonText];
        var connection = [CPURLConnection connectionWithRequest:request delegate:self];
        var modifiedObjects = [objectContext modifiedObjects];
        [connections addObject:{connection: connection, objectContext: objectContext, modifiedObjects: modifiedObjects, receiveSelector: LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector}];
    }
    [super saveChangesWithObjectContext:objectContext];
}

- (CPMutableDictionary) _jsonDictionaryForModifiedObjectsWithObjectContext:(LOObjectContext) objectContext {
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
                tmpId = [CPString stringWithFormat:@"%d", i];
                [insertedObjectToTempIdDict setObject:tmpId forKey:obj._UID];
                [objDict setTmpId:tmpId];
                var insertDictCopy = [insertDict copy];
                [insertDictCopy setObject:[self typeOfObject:obj] forKey:@"_type"];
                [insertDictCopy setObject:tmpId forKey:@"_tmpid"];
                [insertArray addObject:insertDictCopy];
            }
        }
        for (var i = 0; i < size; i++) {
            var objDict = [modifiedObjects objectAtIndex:i];
            var obj = [objDict object];
            var type = [self typeOfObject:obj];
            var primaryKeyAttribute = [self primaryKeyAtrributeForType:type];
            var insertDict = [objDict insertDict];
            var deleteDict = [objDict deleteDict];
            var updateDict = [objDict updateDict];
            if (updateDict && !(deleteDict && insertDict)) { // Don't do this if it is both inserted and deleted
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
                            var insertedRelationshipObjectTempId = [insertedObjectToTempIdDict objectForKey:insertedRelationshipObject._UID];
                            if (!insertedRelationshipObjectTempId) {
                                CPLog.error([self className] + @"." + _cmd + @": Can't get temp. id for object " + insertedRelationshipObject + " on relationship " + updateDictKey);
                            }
                            [insertedRelationshipArray addObject:[CPDictionary dictionaryWithObject:insertedRelationshipObjectTempId forKey:@"_tmpid"]];
                        }
                        updateDictValue = [CPDictionary dictionaryWithObject:insertedRelationshipArray forKey:@"inserts"];
                    }
                    [updateDictCopy setObject:updateDictValue forKey:updateDictKey];
                }
                [updateDictCopy setObject:type forKey:@"_type"];
                var uuid = [obj uuid];
                if (uuid) {
                    [updateDictCopy setObject:uuid forKey:primaryKeyAttribute];
                } else {
                    [updateDictCopy setObject:[objDict tmpId] forKey:@"_tmpid"];
                }
                [updateArray addObject:updateDictCopy];
            }
            if (deleteDict && !insertDict) {    // Don't do this if it is also inserted
                var deleteDictCopy = [deleteDict mutableCopy];
                [deleteDictCopy setObject:type forKey:@"_type"];
                var uuid = [obj uuid];
                if (uuid) {
                    [deleteDictCopy setObject:uuid forKey:primaryKeyAttribute];
                } else {
                    [deleteDictCopy setObject:[objDict tmpId] forKey:@"_tmpid"];
                }
                [deleteArray addObject:deleteDictCopy];
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

- (CPString) globalIdForObject:(id) theObject {
    if ([theObject respondsToSelector:@selector(uuid)]) {
        var uuid = [theObject uuid];
        if (!uuid) {    // If we don't have one from the backend, create a temporary until we get one.
            uuid = [self typeOfObject:theObject] + theObject._UID;
        }
        return uuid;
    }
    return nil;
}

- (CPArray) relationshipKeysForObject:(id) theObject {
    return [self _relationshipKeysForObject:theObject] || [];
}

- (CPArray) _relationshipKeysForObject:(id) theObject {
    var theObjectClass = [theObject class];
    if ([theObjectClass respondsToSelector:@selector(relationshipKeys)]) {
        return [theObjectClass relationshipKeys];
    } else {
        return null;
    }
}

- (CPArray) attributeKeysForObject:(id) theObject {
    return [self _attributeKeysForObject:theObject] || [self _createAttributeKeysFromRow:nil forObject:theObject];
}

- (CPArray) _attributeKeysForObject:(id) theObject {
    var theObjectClass = [theObject class];
    if ([theObjectClass respondsToSelector:@selector(attributeKeys)]) {
        return [theObjectClass attributeKeys];
    } else {
        return null;
    }
}

- (CPArray) _createAttributeKeysFromRow:(id) row forObject: theObject {
    var className = [theObject className];
    var attributeKeysSet = [attributeKeysForObjectClassName objectForKey:className];
    if (row) {
        if (!attributeKeysSet) {
            attributeKeysSet = [CPSet set];
            [attributeKeysForObjectClassName setOBject:attributeKeysSet forKey:className];
        }
        for (var key in row) {
            [attributeKeysSet setObject:key];
        }
    }
    return [attributeKeysSet allValues];
}

@end
