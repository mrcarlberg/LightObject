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
@import "ConfigManager.j"

LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector = @selector(objectsReceived:withConnectionDictionary:);
LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector = @selector(updateStatusReceived:withConnectionDictionary:);
LOFaultArrayRequestedFaultReceivedForConnectionSelector = @selector(faultReceived:withConnectionDictionary:);

@implementation LOSimpleJSONObjectStore : LOObjectStore {
    CPString        baseURL @accessors;
    CPDictionary    attributeKeysForObjectClassName;
    CPArray         connections;        // Array of dictionary with following keys: connection, fetchSpecification, objectContext, receiveSelector
}
/*
+ (void)initialize {
    if (self !== [LOSimpleJSONObjectStore class]) return;
    var mainBundle = [CPBundle mainBundle];
    var bundleURL = [mainBundle bundleURL];
    var rootURL = [[[bundleURL absoluteString] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    var configURL = rootURL + @"/Config/Config";
    CPLog.trace(_cmd + @" configURL: " + configURL);
    var answer = [CPURLConnection sendSynchronousRequest:[CPURLRequest requestWithURL:[CPURL URLWithString:configURL]] returningResponse:nil];
//    CPLog.trace(_cmd + @" answer = " + [answer rawString]);
    if (answer) {
        ConfigBaseUrl = [answer rawString];
    }
}*/

- (id)init {
    self = [super init];
    if (self) {
        var configBaseUrl = [[ConfigManager sharedInstance] configBaseUrl];
        CPLog.trace(_cmd + " configBaseUrl: " + configBaseUrl);
        if (configBaseUrl) {
            baseURL = configBaseUrl;
        }
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
    if (!baseURL) throw new Error(_cmd + @" Has no baseURL to use");
    var entityName = [fetchSpecification entityName];
    var url = baseURL + @"/martin|/" + entityName;
    if ([fetchSpecification operator]) {
        url = url + @"/" + [fetchSpecification operator];
    }
    if ([fetchSpecification qualifier]) {
        var qualiferString = [[fetchSpecification qualifier] predicateFormat];
        var qualiferItems = [qualiferString componentsSeparatedByString:@"=="];
        var qualiferAttribute = [[qualiferItems objectAtIndex:0] stringByTrimmingWhitespace];
        var searchString = [[qualiferItems lastObject] stringByTrimmingWhitespace];
        var searchStringLength = [searchString length];
        if (searchStringLength >= 2) {
            searchString = [searchString substringWithRange:CPMakeRange(1, searchStringLength - 2)]
        }
        url = url + @"/" + qualiferAttribute + @"=" + searchString;
    }
    var request = [CPURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    var connection = [CPURLConnection connectionWithRequest:request delegate:self];
    [connections addObject:{connection: connection, fetchSpecification: fetchSpecification, objectContext: objectContext, receiveSelector: LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector, faultArray:faultArray}];
    CPLog.trace(@"tracing: requestObjectsWithFetchSpecification: " + entityName + @", url: " + url);
}

- (void)connection:(CPURLConnection)connection didReceiveResponse:(CPHTTPURLResponse)response {
    //    alert(@"tracing: didReceiveResponse");
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
    //    debugger;
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
- (CPArray) _objectsFromJSON:(CPArray) jSONObjects withConnectionDictionary:(id)connectionDictionary collectAllObjectsIn:(CPDictionary) receivedObjects {
    if (!jSONObjects.isa || ![jSONObjects isKindOfClass:CPArray])
        return jSONObjects;
    var objectContext = connectionDictionary.objectContext;
    var fetchSpecification = connectionDictionary.fetchSpecification;
    var entityName = fetchSpecification.entityName;
//    var receivedObjects = [CPDictionary dictionary]; // Collect all object with id as key
    var possibleToOneFaultObjects =[CPMutableArray array];
    var newArray = [CPArray array];
    var size = [jSONObjects count];
    for (i = 0; i < size; i++) {
        var row = jSONObjects[i];
        var type = row["_type"];
        var uuid = row["u_pk"];
        var obj = [receivedObjects objectForKey:uuid];
        if (!obj) {
            obj = [objectContext newObjectForType:type];
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
                    if ([column hasSuffix:@"_fk"]) {    // Handle to one relationship
                        column = [column substringToIndex:[column length] - 3]; // Remove "_fk" at end
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
                    } else if (Object.prototype.toString.call( value ) === '[object Object]') { // Handle to many relationship as fault. Backend sends a JSON dictionary. We don't care whats in it.
                        value = [[LOFaultArray alloc] initWithObjectContext:objectContext masterObject:obj relationshipKey:column];
                    } else if ([value isKindOfClass:CPArray]) { // Handle to many relationship as plain objects
                        var relations = value;
                        value = [CPArray array];
                        var relationsSize = [relations count];
                        for (var k = 0; k < relationsSize; k++) {
                            var relationRow = [relations objectAtIndex:k];
                            var relationType = relationRow["_type"];
                            var relationUuid = relationRow["u_pk"];
                            var relationObj = [receivedObjects objectForKey:relationUuid];
                            if (!relationObj) {
                                relationObj = [objectContext newObjectForType:relationType];
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
                    [obj setValue:value forKey:column];
                }
            }
            if (type === entityName) {
                [newArray addObject:obj];
            }
        }
    }
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
        if ([objectContext isObjectRegistered:obj]) {   // If we already got the object transfer all attributes to the old object
            CPLog.trace(@"tracing: _registerOrReplaceObject: Object already in objectContext: " + obj);
            [objectContext setDoNotObserveValues:YES];
            var oldObject = [objectContext objectForGlobalId:[self globalIdForObject:obj]];
            var columns = [self _attributeKeysForObject:obj];
            var columnSize = [columns count];
            for (var j = 0; j < columnSize; j++) {
                var columnKey = [columns objectAtIndex:j];
                if ([columnKey hasSuffix:@"_fk"]) {      // Handle to one relationship. Make observation to proxy object and remove "_fk" from attribute key
                    columnKey = [columnKey substringToIndex:[columnKey length] - 3];
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
    // FIXME: Possible bug here?
    /* _objectsFromJSON:withConnectionDictionary:connectionDictionary: always creates all-new instances.
       All instances created will be found in the passed in dictionary receivedObjects; all instances
       matching the entity of the fetch spec will be returned from the method (stored locally in newArray here).
       However, all objects in receivedObjects is processed in _registerOrReplaceObject:withConnectionDictionary:.
       This method makes sure that each object already registered in the context (an 'old object')
       that matches an instance in receivedObjects (the 'new object')
       is updated with the values of that matching object.
       Again, 'old object' is updated with the values of 'new object'.
       This of course includes the objects in newArray, i.e. the objects matching the fetch spec entity.
       Now, newArray is sent unaltered to objectContext's objectsReceived:withFetchSpecification:.
       I believe this means that any delegate of or listener to the object context will receive
       a list of duplicates of objects already registered in the context.
       We should update newArray so that new objects are substituted with their already registered counterpars,
       should there be any.
     */
    var newArray = [self _objectsFromJSON:jSONObjects withConnectionDictionary:connectionDictionary collectAllObjectsIn:receivedObjects];
    var receivedObjectList = [receivedObjects allValues];
    [self _registerOrReplaceObject:receivedObjectList withConnectionDictionary:connectionDictionary];
    var faultArray = connectionDictionary.faultArray;
    if (faultArray) {
        [objectContext faultReceived:newArray withFetchSpecification:connectionDictionary.fetchSpecification faultArray:faultArray];
    } else {
        [objectContext objectsReceived:newArray withFetchSpecification:connectionDictionary.fetchSpecification];
    }
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
}

- (void) saveChangesWithObjectContext:(LOObjectContext) objectContext {
    var modifyDict = [self _jsonDictionaryForModifiedObjectsWithObjectContext:objectContext];
    if ([modifyDict count] > 0) {       // Only save if thera are changes
        if (!baseURL) throw new Error(_cmd + @" Has no baseURL to use");
        [modifyDict setObject:@"martin|" forKey:@"sessionKey"];
        var json = [LOJSKeyedArchiver archivedDataWithRootObject:modifyDict];
        var jsonText = [CPString JSONFromObject:json];
        CPLog.trace(@"POST Data: " + jsonText);
        var request = [CPURLRequest requestWithURL:baseURL + @"/modify"];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:jsonText];
        receivedData = nil;
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
            if (insertDict) {
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
            var updateDict = [objDict updateDict];
            if (updateDict) {
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
                [updateDictCopy setObject:[self typeOfObject:obj] forKey:@"_type"];
                var uuid = [obj uuid];
                if (uuid) {
                    [updateDictCopy setObject:uuid forKey:@"u_pk"];
                } else {
                    [updateDictCopy setObject:[objDict tmpId] forKey:@"_tmpid"];
                }
                [updateArray addObject:updateDictCopy];
            }
            var deleteDict = [objDict valueForKey:@"deleteDict"];
            if (deleteDict) {
                var deleteDictCopy = [deleteDict mutableCopy];
                [deleteDictCopy setObject:[self typeOfObject:obj] forKey:@"_type"];
                var uuid = [obj uuid];
                if (uuid) {
                    [deleteDictCopy setObject:uuid forKey:@"u_pk"];
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

- (CPString) typeOfObject:(id) theObject {
    return [theObject loObjectType]
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
