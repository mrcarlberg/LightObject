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

LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector = @selector(objectsReceived:withConnectionDictionary:);
LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector = @selector(updateStatusReceived:withConnectionDictionary:);
LOFaultArrayRequestedFaultReceivedForConnectionSelector = @selector(faultReceived:withConnectionDictionary:);

var ConfigBaseUrl = nil;

@implementation LOFaultArray : CPMutableArray {
    LOObjectContext objectContext @accessors;
    id              masterObject @accessors;
    CPString        relationshipKey @accessors;
    BOOL            faultFired;
    CPArray         array;
}
/*
+ (id)alloc {
    CPLog.trace(@"tracing: LOFaultArray.alloc:");
    var array = [];
    
    array.isa = self;
    
    var ivars = class_copyIvarList(self),
    count = ivars.length;
    
    while (count--)
        array[ivar_getName(ivars[count])] = nil;
    
    return array;
}
*/
- (id) initWithObjectContext:(CPObjectContext) anObjectContext masterObject:(id) aMasterObject relationshipKey:(CPString) aRelationshipKey {
//    CPLog.trace(@"tracing: LOFaultArray.init:");
    self = [super init];
    if (self) {
        faultFired = NO;
        objectContext = anObjectContext;
        masterObject = aMasterObject;
        relationshipKey = aRelationshipKey;
        array = [CPArray array];
    }
    return self;
}

- (id)initWithArray:(CPArray)anArray {
//    CPLog.trace(@"tracing: LOFaultArray.initWithArray: count = " + [anArray count]);
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithArray:anArray];
    }
    return self;
}

- (id)initWithArray:(CPArray)anArray copyItems:(BOOL)shouldCopyItems {
//    CPLog.trace(@"tracing: LOFaultArray.initWithArray:copyItems:");
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithArray:anArray copyItems:shouldCopyItems];
    }
    return self;
}
/*
- (id)initWithObjects:(id)anObject, ... {
    CPLog.trace(@"tracing: LOFaultArray.initWithObjects:...");
    self = [super initWithObjects:anObject];
    if (self) {
    }
    return self;
}
*/
- (id)initWithObjects:(id)objects count:(unsigned)aCount {
//    CPLog.trace(@"tracing: LOFaultArray.initWithObjects:count:");
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithObjects:objects count:aCount];
    }
    return self;
}

- (id)initWithCapacity:(unsigned)aCapacity {
//    CPLog.trace(@"tracing: LOFaultArray.initWithCapacity:");
    return [super initWithCapacity:aCapacity];
}

- (id)copy {
    var copy = [super copy];
    copy.objectContext = self.objectContext;
    copy.masterObject = self.masterObject;
    copy.relationshipKey = self.relationshipKey;
    copy.faultFired = self.faultFired;
    copy.array = [array copy];
    return copy;
}

- (int)count {
//    CPLog.trace(@"tracing: (" + [masterObject loObjectType] + @", " + masterObject._UID + @", " + relationshipKey + @") LOFaultArray.count:" + [array count]);
//    debugger;
    if (!faultFired) {
        [self requestFault];
        faultFired = YES;
    }
    return [array count];
}

- (id) objectAtIndex:(int) anIndex {
//    CPLog.trace(@"tracing: (" + [masterObject loObjectType] + @", " + masterObject._UID + @", " + relationshipKey + @") LOFaultArray.objectAtIndex:" + anIndex);
    if (!faultFired) {
        [self requestFault];
        faultFired = YES;
    }
    return [array objectAtIndex:anIndex];
}

- (void)addObject:(id)anObject {
//    CPLog.trace(@"tracing: LOFaultArray.addObject:");
    [array addObject:anObject];
}

- (void)insertObject:(id)anObject atIndex:(int)anIndex {
    [array insertObject:anObject atIndex:anIndex];
}

- (void)replaceObjectAtIndex:(int)anIndex withObject:(id)anObject {
    [array replaceObjectAtIndex:anIndex withObject:anObject];
}

- (void)removeLastObject {
    [array removeLastObject];
}

- (void)removeObjectAtIndex:(int)anIndex {
    [array removeObjectAtIndex:anIndex];
}

- (void)addObserver:(id)observer forKeyPath:(CPString)aKeyPath options:(unsigned)options context:(id)context {
    CPLog.trace([self className] + @" " + _cmd + @" Begin");
    [array addObserver:observer forKeyPath:aKeyPath options:options context:context];
    CPLog.trace([self className] + @" " + _cmd + @" End");
}

- (void)removeObserver:(id)observer forKeyPath:(CPString)aKeyPath {
    [array removeObserver:observer forKeyPath:aKeyPath];
}

- (void)sortUsingFunction:(Function)aFunction context:(id)aContext {
    [array sortUsingFunction:aFunction context:aContext];
}

- (void) requestFault {
    if (!baseURL) throw new Error(_cmd + @" Has no baseURL to use");
    var objectStore = [objectContext objectStore];
    var entityName = [relationshipKey substringToIndex:[relationshipKey length] - 1];
    var fs = [LOFetchSpecification fetchSpecificationForEnityName:entityName];
    var request = [CPURLRequest requestWithURL:baseURL + @"/martin|/" + entityName + @"/" + [objectStore typeOfObject:masterObject] + @"_fk=" + [objectStore globalIdForObject:masterObject]];
    [request setHTTPMethod:@"GET"];
    receivedData = nil;
    var connection = [CPURLConnection connectionWithRequest:request delegate:objectStore];
    [objectStore.connections addObject:{connection: connection, fetchSpecification: fs, objectContext: objectContext, receiveSelector: LOFaultArrayRequestedFaultReceivedForConnectionSelector, faultArray:self}];
    CPLog.trace(@"tracing: requestFault: " + [masterObject loObjectType] + @", " + relationshipKey);
}

@end

@implementation LOSimpleJSONObjectStore : LOObjectStore {
    CPString        baseURL;
    CPDictionary    attributeKeysForObjectClassName;
    CPArray         connections;        // Array of dictionary with following keys: connection, fetchSpecification, objectContext, receiveSelector
}

+ (void)initialize {
    if (self !== [LOSimpleJSONObjectStore class]) return;
    var mainBundle = [CPBundle mainBundle];
    var bundleURL = [mainBundle bundleURL];
    var rootURL = [[[bundleURL absoluteString] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    var configURL = rootURL + @"/Config/Config";
//    CPLog.trace(_cmd + @" configURL = " + configURL);
    var answer = [CPURLConnection sendSynchronousRequest:[CPURLRequest requestWithURL:[CPURL URLWithString:configURL]] returningResponse:nil];
//    CPLog.trace(_cmd + @" answer = " + [answer rawString]);
    if (answer) {
        ConfigBaseUrl = [answer rawString];
    }
}

- (id)init {
    self = [super init];
    if (self) {
        if (ConfigBaseUrl) {
            baseURL = ConfigBaseUrl;
        }
        connections = [CPArray array];
        attributeKeysForObjectClassName = [CPDictionary dictionary];
    }
    return self;
}

- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
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
    receivedData = nil;
    var connection = [CPURLConnection connectionWithRequest:request delegate:self];
    [connections addObject:{connection: connection, fetchSpecification: fetchSpecification, objectContext: objectContext, receiveSelector: LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector}];
    CPLog.trace(@"tracing: requestObjectsWithFetchSpecification: " + entityName + @", url = " + url);
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
        CPLog.trace(@"tracing: LOF objectsReceived: " + receivedData);
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

- (CPArray) _objectsFromJSON:(CPArray) jSONObjects withConnectionDictionary:(id)connectionDictionary collectAllObjectsIn:(CPDictionary) receivedObjects {
    if (![jSONObjects isKindOfClass:CPArray])
        return jSONObjects;
    var objectContext = connectionDictionary.objectContext;
    var fetchSpecification = connectionDictionary.fetchSpecification;
    var entityName = fetchSpecification.entityName;
//    var receivedObjects = [CPDictionary dictionary]; // Collect all object with id as key
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
                    if (Object.prototype.toString.call( value ) === '[object Object]') {
                        value = [[LOFaultArray alloc] initWithObjectContext:objectContext masterObject:obj relationshipKey:column];
                    } else if ([value isKindOfClass:CPArray]) {
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
    return newArray;
}

- (void) _registerOrReplaceObject:(CPArray) theObjects withConnectionDictionary:(id)connectionDictionary{
    var objectContext = connectionDictionary.objectContext;
    var size = [theObjects count];
    for (var i = 0; i < size; i++) {
        var obj = [theObjects objectAtIndex:i];
        if ([objectContext isObjectRegistered:obj]) {   // If we already got the object transfer all attributes to the old object
            CPLog.trace(@"tracing: _registerOrReplaceObject: Object already in objectContext: " + obj);
            var oldObject = [objectContext objectForGlobalId:[self globalIdForObject:obj]];
            var columns = [self _attributeKeysForObject:obj];
            var columnSize = [columns count];
            for (var j = 0; j < columnSize; j++) {
                var columnKey = [columns objectAtIndex:j];
                var newValue = [obj valueForKey:columnKey];
                var oldValue = [oldObject valueForKey:columnKey];
                if (newValue !== oldValue) {
                    [oldObject setValue:newValue forKey:columnKey];
                }
            }
        } else {                                        // If it is new just register it.
            [objectContext registerObject:obj];
        }
    }
}

- (void) faultReceived:(CPArray) jSONObjects withConnectionDictionary:(id)connectionDictionary {
    var objectContext = connectionDictionary.objectContext;
    var faultArray = connectionDictionary.faultArray;
    var receivedObjects = [CPDictionary dictionary]; // Collect all object with id as key
    var newArray = [self _objectsFromJSON:jSONObjects withConnectionDictionary:connectionDictionary collectAllObjectsIn:receivedObjects];
    var receivedObjectList = [receivedObjects allValues];
    [self _registerOrReplaceObject:receivedObjectList withConnectionDictionary:connectionDictionary];
    var masterObject = [faultArray masterObject];
    var relationshipKey = [faultArray relationshipKey];
    var array = [masterObject valueForKey:relationshipKey];
    [masterObject willChangeValueForKey:relationshipKey];
//    [array removeAllObjects];
//    [masterObject setValue:newArray forKey:relationshipKey];
    [array addObjectsFromArray:newArray];
    [masterObject didChangeValueForKey:relationshipKey];
}

- (void) objectsReceived:(CPArray) jSONObjects withConnectionDictionary:(id)connectionDictionary {
    var objectContext = connectionDictionary.objectContext;
    var receivedObjects = [CPDictionary dictionary]; // Collect all object with id as key
    var newArray = [self _objectsFromJSON:jSONObjects withConnectionDictionary:connectionDictionary collectAllObjectsIn:receivedObjects];
    var receivedObjectList = [receivedObjects allValues];
    [self _registerOrReplaceObject:receivedObjectList withConnectionDictionary:connectionDictionary];
    [objectContext objectsReceived:newArray withFetchSpecification:connectionDictionary.fetchSpecification];
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
    var relationshipKeys = [self _relationshipKeysForObject:theObject];
    if (relationshipKeys) {
        return relationshipKeys;
    } else {
        return [];
    }
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
    var attributeKeys = [self _attributeKeysForObject:theObject];
    if (attributeKeys) {
        return attributeKeys;
    } else {
        return [self _createAttributeKeysFromRow:nil forObject:theObject];
    }
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
        }
        for (var key in row) {
            [attributeKeysSet setObject:key];
        }
    }
    return [attributeKeysSet allValues];
}

@end
