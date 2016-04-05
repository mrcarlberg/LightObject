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
@import "CPManagedObjectModel.j"
@import "LOContextValueTransformer.j"


LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector = @selector(objectsReceived:withConnectionDictionary:);
LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector = @selector(updateStatusReceived:withConnectionDictionary:);
//LOFaultArrayRequestedFaultReceivedForConnectionSelector = @selector(faultReceived:withConnectionDictionary:);

@implementation LOSimpleJSONObjectStore : LOObjectStore {
    CPDictionary            attributeKeysForObjectClassName;
    CPArray                 connections;        // Array of dictionary with following keys: connection, fetchSpecification, objectContext, receiveSelector
    CPManagedObjectModel    model;
}

- (id)initWithModel:(CPManagedObjectModel)aModel {
    self = [super init];
    if (self) {
        connections = [CPArray array];
        attributeKeysForObjectClassName = [CPDictionary dictionary];
        model = aModel;
    }
    return self;
}

- (id)init {
    self = [super init];
    if (self) {
        connections = [CPArray array];
        attributeKeysForObjectClassName = [CPDictionary dictionary];
    }
    return self;
}

- (id)initWithCoder:(CPCoder)aCoder {
    self = [super initWithCoder:aCoder];
    if (self) {
        connections = [CPArray array];
        attributeKeysForObjectClassName = [CPDictionary dictionary];
    }
    return self;
}

- (void)requestObjectsWithFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext requestId:(id)requestId withCompletionHandler:(Function)aCompletionBlock {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext requestId:requestId withCompletionHandler:aCompletionBlock faults:nil];
}

- (void)requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext requestId:(id)requestId withCompletionHandler:(Function)aCompletionBlock {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext requestId:requestId withCompletionHandler:aCompletionBlock faults:[faultArray]];
}

- (void)requestFaultObjects:(CPArray)faultObjects withFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext requestId:(id)aRequestId withCompletionHandler:(Function)aCompletionBlock {
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext requestId:aRequestId withCompletionHandler:aCompletionBlock faults:faultObjects];
}

/*!
    Sends request of objects based on fetchSpecification.
    aCompletionBlock is called when finished.
*/
- (void)requestObjectsWithFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext requestId:(id)requestId withCompletionHandler:(Function)aCompletionBlock faults:(id)faults {
    var request = [self urlForRequestObjectsWithFetchSpecification:fetchSpecification];
    if (fetchSpecification.requestPreProcessBlock) {
        fetchSpecification.requestPreProcessBlock(request);
    }
    [self requestObjectsWithFetchSpecification:fetchSpecification objectContext:objectContext requestId:requestId request:request withCompletionBlocks:aCompletionBlock ? [aCompletionBlock] : nil faults:faults];
}

/*!
    Sends request for objects based on request. fetchSpecification is not used and only added to connection dictionary
    completionBlocks are called when finished.
    Returns the connectionDictionary
*/
- (id)requestObjectsWithFetchSpecification:(LOFetchSpecification)fetchSpecification objectContext:(LOObjectContext)objectContext requestId:(id)requestId request:(CPURLRequest)request withCompletionBlocks:(CPArray)completionBlocks faults:(id)faults {
    var url = [[request URL] absoluteString];
    var connectionDictionary = {
        connection: [CPURLConnection connectionWithRequest:request delegate:self],
        fetchSpecification: fetchSpecification,
        objectContext: objectContext,
        request: request,
        receiveSelector: LOObjectContextRequestObjectsWithConnectionDictionaryReceivedForConnectionSelector,
        faults:faults,
        url: url,
        completionBlocks: completionBlocks,
        timestamp: [CPDate new]
    };
    if (requestId) {
        connectionDictionary.requestId = requestId;
    }
    [connections addObject:connectionDictionary];
    if (objectContext.debugMode & LOObjectContextDebugModeFetch) CPLog.trace(@"LOObjectContextDebugModeFetch: Entity: " + [fetchSpecification entityName] + @", qualifier: " + [fetchSpecification qualifier] + @", url: " + url);
    return connectionDictionary;
}

/*!
 * Overrides method in superclass. Part of informal protocol.
 */
- (void)cancelRequestsWithRequestId:(id)aRequestId withObjectContext:(LOObjectContext)anObjectContext {
    for (var i = [connections count]; i > 0; i--) {
        var idx = i - 1;
        var connectionDictionary = [connections objectAtIndex:idx];

        if (aRequestId && connectionDictionary.requestId !== aRequestId) continue;
        if (anObjectContext && connectionDictionary.objectContext !== anObjectContext) continue;

        [connectionDictionary.connection cancel];
        [connections removeObjectAtIndex:idx];
    }
}

- (void)connection:(CPURLConnection)connection didReceiveResponse:(CPHTTPURLResponse)response {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    if (!connectionDictionary) {
        [CPException raise:CPInternalInconsistencyException format:@"delegate method -" + _cmd + " called for connection but no related connectionDictionary found"];
    }
    connectionDictionary.response = response;
}

- (void)connection:(CPURLConnection)connection didReceiveData:(CPString)data {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    if (!connectionDictionary) {
        [CPException raise:CPInternalInconsistencyException format:@"delegate method -" + _cmd + " called for connection but no related connectionDictionary found"];
    }
    var receivedData = connectionDictionary.receivedData;
    if (receivedData) {
        connectionDictionary.receivedData = [receivedData stringByAppendingString:data];
    } else {
        connectionDictionary.receivedData = data;
    }
}

- (void)connectionDidFinishLoading:(CPURLConnection)connection {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    if (!connectionDictionary) {
        [CPException raise:CPInternalInconsistencyException format:@"delegate method -" + _cmd + " called for connection but no related connectionDictionary found"];
    }
    var response = connectionDictionary.response;
    var receivedData = connectionDictionary.receivedData;
    var objectContext = connectionDictionary.objectContext;
    var fromURL = connectionDictionary.url;
    var request = connectionDictionary.request;
    var error;
    var jSON = [self dataForResponse:response andData:receivedData fromURL:fromURL connection:connection error:@ref(error)];

    if (error) {
        if ([self handleErrorForResponse:response request:request andData:jSON fromURL:fromURL connection:connection error:error]) {
            [objectContext errorReceived:error withFetchSpecification:connectionDictionary.fetchSpecification result:jSON statusCode:[response statusCode] completionBlocks:connectionDictionary.completionBlocks];
        }
    } else {
        if (objectContext.debugMode & LOObjectContextDebugModeReceiveData) CPLog.trace(@"LOObjectContextDebugModeReceiveData: Url: " + connectionDictionary.url + @", data: (" + (jSON ? jSON.length : 0) + ") " + receivedData);
        [self performSelector:connectionDictionary.receiveSelector withObject:jSON withObject:connectionDictionary]
    }
    [connections removeObject:connectionDictionary];
}

- (void)connection:(CPURLConnection)connection didFailWithError:(id)error {
    var connectionDictionary = [self connectionDictionaryForConnection:connection];
    if (!connectionDictionary) {
        [CPException raise:CPInternalInconsistencyException format:@"delegate method -" + _cmd + " called for connection but no related connectionDictionary found"];
    }
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
  Method that handles errors. The default method just returns YES that tells the caller to continue.
  If this method returns NO the caller will abort and leave it up to this method to do what is needed.
  For example it can be used to redo the request if the connetion was lost for some reason.
*/
- (BOOL)handleErrorForResponse:(CPHTTPURLResponse)response request:(CPURLRequest)request andData:(CPString)data fromURL:(CPString)urlString connection:(CPURLConnection)connection error:(LOError)error {
    return YES;
}

/*!
  Transforms the received data to an object structure. The default implementation creates objects from JSON if the
  statusCode is 200.
*/
- (id)dataForResponse:(CPHTTPURLResponse)response andData:(CPString)data fromURL:(CPString)urlString connection:(CPURLConnection)connection error:(LOErrorRef)error {
    var statusCode = [response statusCode];

    if (statusCode === 200) return data != nil && [data length] > 0 ? [data objectFromJSON] : nil;

    if (error) @deref(error) = [LOError errorWithDomain:nil code:statusCode userInfo:nil];

    return data;
}

/*!
 Creates objects from JSON. If there is a relationship it is up to this method to create a LOFaultArray, LOFaultObject or the actual object.
 */
- (CPArray)_objectsFromJSON:(CPArray)jSONObjects withConnectionDictionary:(id)connectionDictionary collectAllObjectsIn:(CPDictionary)receivedObjects {
 // TODO: Add test cases for this method.
 // TODO: Split this method into smaller parts.
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
        var type = [self typeForRawRow:row objectContext:objectContext fetchSpecification:fetchSpecification];
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
            var toManyRelationshipKeys = [self relationshipKeysForObject:obj withType:type];
            var columns = [self attributeKeysForObject:obj withType:type];

            [self setPrimaryKey:uuid forObject:obj];
            var columnSize = [columns count];

            for (var j = 0; j < columnSize; j++) {
                var column = [columns objectAtIndex:j];
                var isToManyRelationship = [toManyRelationshipKeys containsObject:column];

                // Does the fetched row has this column or does the object already exists in the object context.
                // The later to nil out the value if it already exists.
                // Also we should do to many relationships even if they are not coming from the backend as we need
                // to create faults for them.
                if (row.hasOwnProperty(column) || objectFromObjectContext || isToManyRelationship) {
                    var value = row[column];
                    if (value == null) {
                        /* Force nil if either null (which is same as nil, ugh!) or undefined. */
                        value = nil;
                    }
                    if ([self isForeignKeyAttribute:column forType:type objectContext:objectContext]) {    // Handle to one relationship.
                        column = [self toOneRelationshipAttributeForForeignKeyAttribute:column forType:type objectContext:objectContext]; // Remove "_fk" at end
                        if (value) {
                            var toOne = [objectContext objectForGlobalId:value];
                            if (toOne) {
                                value = toOne;
                            } else {
                                // Add it to a list and try again after we have registered all objects.
                                [possibleToOneFaultObjects addObject:{@"object":obj, @"relationshipKey":column, @"globalId":value, @"type": type}];
                                value = nil;
                            }
                        }
                    // Handle to many relationship
                    } else if (isToManyRelationship) {
                        // as plain objects
                        if (value && [value isKindOfClass:CPArray]) {
                            // The array contains only type and primaryKey for the relationship objects.
                            // The complete relationship objects can be sent before or later in the list of all objects.
                            var relations = value;
                            value = [CPArray array];
                            var relationsSize = [relations count];
                            for (var k = 0; k < relationsSize; k++) {
                                var relationRow = [relations objectAtIndex:k];
                                var relationType = [self typeForRawRow:relationRow objectContext:objectContext fetchSpecification:fetchSpecification];
                                var relationUuid = [self primaryKeyForRawRow:relationRow forType:relationType objectContext:objectContext];
                                var relationObj = [receivedObjects objectForKey:relationUuid];
                                if (!relationObj) {
                                    // Is it already in context use it and update its values when the objects arrives
                                    var relationObj = [objectContext objectForGlobalId:relationUuid];
                                    if (!relationObj) {
                                        relationObj = [self newObjectForType:relationType objectContext:objectContext];
                                        [self setPrimaryKey:relationUuid forObject:relationObj];
                                    }

                                    if (relationObj) {
                                        [receivedObjects setObject:relationObj forKey:relationUuid];
                                    }
                                }
                                if (relationObj) {
                                    [value addObject:relationObj];
                                }
                            }
                        // Handle to many relationship as fault.
                        } else {
                            var oldValue = [obj valueForKey:column];
                            // If the old value is a fault and not populated then keep the old fault.
                            if (![oldValue isKindOfClass:[LOFaultArray class]] || [oldValue faultPopulated]) {
                                value = [[LOFaultArray alloc] initWithObjectContext:objectContext masterObject:obj relationshipKey:column];
                            } else {
                                value = oldValue;
                            }
                        }
                    } else {
                        // Ok, it is a regular value. Check if it has a transformer.
                        var typeValue = [self typeValueForAttributeKey:column withEntityNamed:type];

                        switch (typeValue) {
                            case CPDTransformableAttributeType:
                                var valueTransformer = [self valueTransformerForAttribute:column withEntityNamed:type];

                                if (valueTransformer) {
                                    if ([valueTransformer conformsToProtocol:@protocol(LOContextValueTransformer)])
                                        value = [valueTransformer reverseTransformedValue:value withContext:{object:obj, attributeKey:column}];
                                    else
                                        value = [valueTransformer reverseTransformedValue:value];
                                }

                                break;
                        }
                    }

                    // We want to set the value on the object if it is a different value.
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
                    var faultConnectionDictionary = [self connectionDictionaryForFault:fault];
                    if (faultConnectionDictionary) {
                        // Tell the objectContext that the fault is received so it can morph it to the real object.
                        // We don't send any completionBlocks as they will be called when the other fault fetch will complete.
                        [faultConnectionDictionary.objectContext faultReceived:[obj] withFetchSpecification:faultConnectionDictionary.fetchSpecification withCompletionBlocks:nil faults:[fault]];
                        // Delete the fault in the connection dictionary so when this request compleats it will be treated as a regular reqest and not a fault request
                        [faultConnectionDictionary.faults removeObject:fault];
                        if([faultConnectionDictionary.faults count] === 0)
                            delete faultConnectionDictionary.faults;
                    }
                } else {
                    // Just morph the fault to the object. No fetch is outstanding so no completionBlocks needs to be called
                    // TODO: A notification needs to be sent: LOFaultDidPopulateNotification
                    [fault morphObjectTo:obj];
                }
            }

            if (type === entityName) {
                // Add the new received object or the morphed fault to the list of received objects
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
                // To make life easier before we get a full model we try to ask the object for an entity name for the relation.
                var entityName;
                if ([possibleToOneFaultObject.object respondsToSelector:@selector(enityNameForRelationshipKey:)]) {
                    entityName = [possibleToOneFaultObject.object enityNameForRelationshipKey:possibleToOneFaultObject.relationshipKey];
                } else {
                    entityName = [self destinationEntityNameForRelationshipKey:possibleToOneFaultObject.relationshipKey withEntityNamed:possibleToOneFaultObject.type];
                }
                if (entityName != nil) {
                    toOne = [LOFaultObject faultObjectWithObjectContext:objectContext entityName:entityName primaryKey:globalId];
                    [objectContext _registerObject:toOne forGlobalId:globalId];
                    [toOneFaults setObject:toOne forKey:globalId];
                    //console.log([self className] + " " + _cmd + " Can't find object for toOne relationship '" + possibleToOneFaultObject.relationshipKey + "' (" + toOne + ") on object " + possibleToOneFaultObject.object);
                }
            }
        }
        if (toOne) {
            [possibleToOneFaultObject.object setValue:toOne forKey:possibleToOneFaultObject.relationshipKey];
        }
    }
    [objectContext setDoNotObserveValues:NO];
    return newArray;
}

- (CPValueTransformer)valueTransformerForAttribute:(CPString)attributeName withEntityNamed:(CPString)entityName {
    var attribute = [self attributeForKey:attributeName withEntityNamed:entityName];
    var userInfo = [attribute userInfo];
    // Transformer name in userInfo overrides the type value on the attribute. This will allow the attribute to have a type and a transformer
    var valueTransformerName = [userInfo objectForKey:@"valueTransformerName"] || [attribute valueTransformerName];
    var valueTransformer;

    if (valueTransformerName) {
        valueTransformer = [CPValueTransformer valueTransformerForName:valueTransformerName];

        if (!valueTransformer)
        {
            var valueTransformerClass = CPClassFromString(valueTransformerName);

            if (valueTransformerClass)
            {
                valueTransformer = [[valueTransformerClass alloc] init];
                [valueTransformerClass setValueTransformer:valueTransformer forName:valueTransformerName];
            }
        }
    }

    if (!valueTransformer) {
        CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Can't find value transformer with name '" + valueTransformerName +
            "'' for attribute '" + attributeName + "' on entity '" + entityName + "'");
    }

    return valueTransformer;
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
            var columns = [self attributeKeysForObject:obj withType:type];
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
    var aFetchSpecification = connectionDictionary.fetchSpecification;
    var allReceivedObjects;
    var newArray;

    if ([aFetchSpecification operator] === @"lazy") {
        var entityName = [aFetchSpecification entityName];
        newArray = [];
        for (var i = 0, size = jSONObjects.length; i < size; i++) {
            var fault = [LOFaultObject faultObjectWithObjectContext:objectContext entityName:entityName primaryKey:jSONObjects[i]];
            [newArray addObject:fault];
        }
        allReceivedObjects = newArray;
    } else {
        var receivedObjects = [CPDictionary dictionary]; // Collect all object with id as key
        newArray = [self _objectsFromJSON:jSONObjects withConnectionDictionary:connectionDictionary collectAllObjectsIn:receivedObjects];
        allReceivedObjects = [receivedObjects allValues];
/*        [self _registerOrReplaceObject:allReceivedObjects withConnectionDictionary:connectionDictionary];
        if (newArray.isa && [newArray isKindOfClass:CPArray]) {
            newArray = [self _arrayByReplacingNewObjects:newArray withObjectsAlreadyRegisteredInContext:objectContext];
        }*/
    }
    var faults = connectionDictionary.faults;
    if (faults) {
        [objectContext faultReceived:newArray withFetchSpecification:aFetchSpecification withCompletionBlocks:connectionDictionary.completionBlocks faults:faults];
    } else {
        [objectContext objectsReceived:newArray allReceivedObjects:allReceivedObjects withFetchSpecification:aFetchSpecification withCompletionBlocks:connectionDictionary.completionBlocks];
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

/*!
    POST object contexts modified objects as JSON data.
    aCompletionBlock is called when finished.
*/
- (void)saveChangesWithObjectContext:(LOObjectContext)objectContext withCompletionHandler:(Function)aCompletionBlock {
    var modifyDict = [self _jsonDictionaryForModifiedObjectsWithObjectContext:objectContext];
    if ([modifyDict count] > 0) {       // Only save if thera are changes
        var json = [LOJSKeyedArchiver archivedDataWithRootObject:modifyDict];
        var url = [self urlForSaveChangesWithData:json];
        var jsonString = [CPString JSONFromObject:json];
        var modifiedObjects = [objectContext modifiedObjects];
        var request = [CPURLRequest requestWithURL:url];

        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:jsonString];

        [self saveChangesWithObjectContext:objectContext request:request modifiedObjects:modifiedObjects withCompletionBlocks:aCompletionBlock ? [aCompletionBlock] : nil];
    } else if (aCompletionBlock) {
        aCompletionBlock(nil, 200);  // We have nothing to save so call the compleation block directly with a result code of 200
    }
    [super saveChangesWithObjectContext:objectContext withCompletionHandler:aCompletionBlock];
}

/*!
    Send update request. modifiedObjects is added to connection dictionary for later use (kind of userInfo)
    completionBlocks are called when finished.
    Returns the connectionDictionary
*/
- (id)saveChangesWithObjectContext:(LOObjectContext)objectContext request:(CPURLRequest)request modifiedObjects:(id)modifiedObjects withCompletionBlocks:(CPArray)completionBlocks {
    var connection = [CPURLConnection connectionWithRequest:request delegate:self];
    var connectionDictionary = {connection: connection, objectContext: objectContext, request: request, modifiedObjects: modifiedObjects, receiveSelector: LOObjectContextUpdateStatusWithConnectionDictionaryReceivedForConnectionSelector, completionBlocks: completionBlocks, timestamp: [CPDate new]};
    [connections addObject:connectionDictionary];
    if (objectContext.debugMode & LOObjectContextDebugModeSaveChanges) CPLog.trace(@"Save Changes POST Data: " + [request HTTPBody]);
    return connectionDictionary;
}

/*!
    Copies the updateDict and replaces all to many relationships dictionaries with insert dictionaries.
    If an attribute has a transformer it will be used to transform the value.
*/
- (CPMutableDictionary)_copyUpdateDictAndCreateInsertDictionariesForToManyRelationships:(CPDictionary)updateDict insertedObjectToTempIdDict:(CPDictionary)insertedObjectToTempIdDict forObject:(id)obj withObjectContext:(LOObjectContext)objectContext {
    var entityName = [self typeOfObject:obj];
    var updateDictCopy = [CPMutableDictionary dictionary];
    var updateDictKeys = [updateDict allKeys];
    var updateDictKeysSize = [updateDictKeys count];
    for (var j = 0; j < updateDictKeysSize; j++) {
        var updateDictKey = [updateDictKeys objectAtIndex:j];
        var updateDictValue = [updateDict objectForKey:updateDictKey];
        // FIXME: Use the model to check the type of the attribute. It doesn't need to be a relation if it is a CPDictionary.
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
        } else {
            // Ok, it is a regular value. Check if it has a transformer.
            var typeValue = [self typeValueForAttributeKey:updateDictKey withEntityNamed:entityName];

            switch (typeValue) {
                case CPDTransformableAttributeType:
                    var valueTransformer = [self valueTransformerForAttribute:updateDictKey withEntityNamed:entityName];

                    if (valueTransformer) {
                        if ([valueTransformer conformsToProtocol:@protocol(LOContextValueTransformer)])
                            updateDictValue = [valueTransformer transformedValue:updateDictValue withContext:{object:obj, attributeKey:updateDictKey}];
                        else
                            updateDictValue = [valueTransformer transformedValue:updateDictValue];
                    }

                    break;
            }
        }
        [updateDictCopy setObject:updateDictValue forKey:updateDictKey];
    }
    return updateDictCopy;
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
        // First create temporary ids for to many relationship inserts
        for (var i = 0; i < size; i++) {
            var objDict = [modifiedObjects objectAtIndex:i];
            var obj = [objDict object];
            var insertDict = [objDict insertDict];
            var deleteDict = [objDict deleteDict];
            if (insertDict && !deleteDict) {    // Don't do this if it is also deleted
                var primaryKey = [self primaryKeyForObject:obj];
                // Create a tmp id if primary key does not exists
                if (!primaryKey) {
                    var tmpId = [CPString stringWithFormat:@"%d", i];
                    [insertedObjectToTempIdDict setObject:tmpId forKey:[obj UID]];
                    [objDict setTmpId:tmpId];
                }
            }
        }
        // Inserts
        for (var i = 0; i < size; i++) {
            var objDict = [modifiedObjects objectAtIndex:i];
            var obj = [objDict object];
            var insertDict = [objDict insertDict];
            var deleteDict = [objDict deleteDict];
            if (insertDict && !deleteDict) {    // Don't do this if it is also deleted
                var primaryKey = [self primaryKeyForObject:obj];
                var type = [self typeOfObject:obj];
                var insertDictCopy = [self _copyUpdateDictAndCreateInsertDictionariesForToManyRelationships:insertDict insertedObjectToTempIdDict:insertedObjectToTempIdDict forObject:obj withObjectContext:objectContext];
                // Use primary key if object has it, otherwise create a tmp id
                if (primaryKey) {
                    var primaryKeyAttribute = [self primaryKeyAttributeForType:type objectContext:objectContext];
                    [insertDictCopy setObject:primaryKey forKey:primaryKeyAttribute];
                } else {
                    [insertDictCopy setObject:[objDict tmpId] forKey:@"_tmpid"];
                }
                [insertDictCopy setObject:type forKey:@"_type"];
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
                var updateDictCopy = [self _copyUpdateDictAndCreateInsertDictionariesForToManyRelationships:updateDict insertedObjectToTempIdDict:insertedObjectToTempIdDict forObject:obj withObjectContext:objectContext];
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
    var objectType = [self typeOfObject:theObject];

    if (objectType == nil) return nil;

    var uuid = [self globalIdForObjectType:objectType andPrimaryKey:[self primaryKeyForObject:theObject]];

    if (!uuid) {    // If we don't have one from the backend, create a temporary until we get one.
        uuid = objectType + theObject._UID;
    }
    return uuid;
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

- (void)addCompletionHandler:(Function)aCompletionBlock toTriggeredFault:(id <LOFault>)aFault {
    var size = [connections count];
    for (var i = 0; i < size; i++) {
        var connectionDictionary = [connections objectAtIndex:i];
        if ([connectionDictionary.faults containsObject:aFault]) {
            [connectionDictionary.completionBlocks addObject:aCompletionBlock];
        }
    }
}

@end


@implementation LOSimpleJSONObjectStore (Model) {
    JSObject entityNameToEntityCache;               // Cache with entity for entity name
    JSObject entityNameToEntityNameCache            // Cache with entity name for XCode model entity name. This is needed as XCode only allows names starting with capital letter and we can override that.
    JSObject toOneForeignKeyToAttributeCache;
    JSObject toOneAttributeToForeignKeyCache;
    JSObject attributeKeyCache;                     // Cache with all attributes
    JSObject relationshipKeyCache;                  // Cache with all to many relationship attributes
    JSObject propertyKeyCache;                      // Cache with all properties
    JSObject attributeValueTypeCache                // Cache with valueType for attribute
    JSObject relationshipDestinationEntityNameCache // Cache with destination entity name for relations
    JSObject inversRelationNameCache                // Cache with invers relation name for relations
    CPString primaryKeyCache;
}

/*!
 * Will cache to one relations to foreignKey and vice versa for each entity.
 * Will also cache primaryKey for each entity. We are not supporting composite primary keys right now.
 * The information is read from the model.

 * As XCode demand that entity names start with a capital letter we allow the name to be overridden by
 * entering a key/value pair in the user info dictionary with a 'entityName' key.
 */
- (void)_createForeignKeyAttributeCacheForEntityName:(CPString)entityName {
    var aModel = model;

    if (entityNameToEntityCache == nil) {
        var entityNames = [aModel entitiesByName];

        entityNameToEntityCache = {};
        entityNameToEntityNameCache = {};
        for (var i = 0, size = [entityNames count]; i < size; i++) {
            var aEntityName = [entityNames objectAtIndex:i],
                entity = [aModel entityWithName:aEntityName],
                userInfo = [entity userInfo],
                useEntityName = [userInfo objectForKey:@"entityName"];

            entityNameToEntityCache[useEntityName || aEntityName] = entity;
            entityNameToEntityNameCache[aEntityName] = useEntityName;
        }
    }

    if (toOneForeignKeyToAttributeCache == nil) toOneForeignKeyToAttributeCache = {};
    if (toOneAttributeToForeignKeyCache == nil) toOneAttributeToForeignKeyCache = {};
    if (primaryKeyCache == nil) primaryKeyCache = {};
    if (attributeKeyCache == nil) attributeKeyCache = {};
    if (relationshipKeyCache == nil) relationshipKeyCache = {};
    if (propertyKeyCache == nil) propertyKeyCache = {};
    if (attributeValueTypeCache == nil) attributeValueTypeCache = {};
    if (relationshipDestinationEntityNameCache == nil) relationshipDestinationEntityNameCache = {};
    if (inversRelationNameCache == nil) inversRelationNameCache = {};

    var entity = entityNameToEntityCache[entityName],
        attributesDict = [entity propertiesByName],
        entityUserInfo = [entity userInfo],
        parentEntityName = [entityUserInfo objectForKey:@"parentEntity"];

    if (entity === nil) {
        CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Can't find entity '" + entityName + @"' in model");
    }

    if (parentEntityName) {
        // If we have a parent entity in the user info add its properties. Use sub entity's property if it is a duplicate
        var parentPropertyJSDict = [self propertiesByNameForEntityNamed:parentEntityName];
        if (parentPropertyJSDict) {
            var newAttributesDict = [CPDictionary dictionaryWithJSObject:parentPropertyJSDict];
            [newAttributesDict addEntriesFromDictionary:attributesDict];
            attributesDict = newAttributesDict;
        }
    }

    var allAttributeNames = [attributesDict allKeys],
        foreignKeyCache = toOneForeignKeyToAttributeCache[entityName] = {},
        attributeCache = toOneAttributeToForeignKeyCache[entityName] = {},
        attributeKeyCacheForEntity = attributeKeyCache[entityName] = [],
        relationshipKeyCacheForEntity = relationshipKeyCache[entityName] = [],
        propertyKeyCacheForEntity = propertyKeyCache[entityName] = {},
        attributeValueTypeCacheForEntity = attributeValueTypeCache[entityName] = {},
        relationshipDestinationEntityNameCacheForEntity = relationshipDestinationEntityNameCache[entityName] = {},
        inversRelationNameCacheForEntity = inversRelationNameCache[entityName] = {};

    for (var i = 0, size = [allAttributeNames count]; i < size; i++) {
        var attributeName = [allAttributeNames objectAtIndex:i],
            attribute = [attributesDict objectForKey:attributeName];

        propertyKeyCacheForEntity[attributeName] = attribute;

        if ([attribute isKindOfClass:CPRelationshipDescription]) {
            if ([attribute isToMany]) {
                // Add to attributeKey cache if to many relationsship.
                [attributeKeyCacheForEntity addObject:attribute];
                [relationshipKeyCacheForEntity addObject:attribute];
            } else {
                // foreignKey name can be stored in the userInfo.
                var userInfo = [attribute userInfo],
                    foreignKeyName = [userInfo objectForKey:@"foreignKey"];

                if (foreignKeyName === nil) {
                    // If no userInfo information exists on the relationship just assume it ends with 'ForeignKey'
                    foreignKeyName = attributeName + @"ForeignKey";
                }

                var foreignKeyAttribute = [attributesDict objectForKey:foreignKeyName];
                // The foreignKey attribute must exist on the entity
                if (foreignKeyAttribute) {
                    foreignKeyCache[foreignKeyName] = attribute;
                    attributeCache[attributeName] = foreignKeyAttribute;
                } else {
                    CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Has no foreign key attribute (" + foreignKeyName + ") for relationship (" + attributeName + ") in model for entity:" + entityName);
                }
            }
            relationshipDestinationEntityNameCacheForEntity[attributeName] = entityNameToEntityNameCache[[attribute destinationEntityName]];
            inversRelationNameCacheForEntity[attributeName] = [attribute inversePropertyName];
        } else {
            var userInfo = [attribute userInfo],
                isAvailableIn = [[userInfo objectForKey:@"availableIn"] lowercaseString];

            // FIXME: To have an attribute in the model that is not used in the client (we are the client) we set the userInfo
            // key 'availableIn' to include the string "backend". We can have for example a comma separated list...
            // More thoughts about this is needed but this will work for now.
            if (!(([isAvailableIn rangeOfString:@"backend"] || {}).location >= 0)) {
                var isPrimaryKey = [userInfo objectForKey:@"primaryKey"];
                var transformerName = [userInfo objectForKey:@"valueTransformerName"];

                if (transformerName != nil) {
                    attributeValueTypeCacheForEntity[attributeName] = CPDTransformableAttributeType;
                } else {
                    attributeValueTypeCacheForEntity[attributeName] = [attribute typeValue];
                }

                // Check if this attribute has 'primaryKey: YES' in the userInfo
                if (isPrimaryKey) {
                    if (primaryKeyCache[entityName]) {
                        CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Attribute '" + attributeName + "' is marked as primaryKey but attribute '" + [primaryKeyCache[entityName] name] + "' ia already marked as primary key for entity '" + entityName + "'");
                    } else {
                        primaryKeyCache[entityName] = attribute;
                    }
                } else {
                    // Only add attribute to attribute key cache if it is not the primaryKey
                    [attributeKeyCacheForEntity addObject:attribute];
                }
            }
        }
    }

    // If we don't have a primary key from above try to find an attribute with the name 'primaryKey'.
    if (primaryKeyCache[entityName] == nil) {
        var primaryKeyAttribute = [attributesDict objectForKey:@"primaryKey"];

        if (primaryKeyAttribute == nil) {
            CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Can not find a primary key for entity '" + entityName + "'");
        } else {
            primaryKeyCache[entityName] = primaryKeyAttribute;
            // Now remove the attribute from the attribute key cache as we don't want the primary key in it.
            [attributeKeyCacheForEntity removeObject:primaryKeyAttribute];
        }
    }
}

/*!
 * Returns true if the attribute is a foreign key for the raw row.
 */
- (BOOL)isForeignKeyAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    if (toOneForeignKeyToAttributeCache != nil) {
        var entityCache = toOneForeignKeyToAttributeCache[aType];

        if (entityCache) {
            if ([attribute hasSuffix:@"ForeignKey"] && entityCache[attribute] == nil)
                CPLog.error(@"[" + [self className] + @" " + _cmd + @"] To one relationship is missing in model with foreign key attributes: '" + attribute + "' , for entity '" + aType + "'");
            return entityCache[attribute] != nil;
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:aType];

    return [self isForeignKeyAttribute:attribute forType:aType objectContext:objectContext];
}

/*!
 * Returns to one relationship attribute that correspond to the foreign key attribute for the raw row
 */
- (CPString)toOneRelationshipAttributeForForeignKeyAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    if (toOneForeignKeyToAttributeCache != nil) {
        var entityCache = toOneForeignKeyToAttributeCache[aType];

        if (entityCache) {
            return [entityCache[attribute] name];
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:aType];

    return [self toOneRelationshipAttributeForForeignKeyAttribute:attribute forType:aType objectContext:objectContext];
}

/*!
 * Returns foreign key attribute that correspond to the to one relationship attribute for the type
 */
- (CPString)foreignKeyAttributeForToOneRelationshipAttribute:(CPString)attribute forType:(CPString)aType {
        if (toOneAttributeToForeignKeyCache != nil) {
        var entityCache = toOneAttributeToForeignKeyCache[aType];

        if (entityCache) {
            return [entityCache[attribute] name];
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:aType];

    return [self foreignKeyAttributeForToOneRelationshipAttribute:attribute forType:aType];
}

/*!
 * Returns the primary key attribute for a type and for an object context.
 */
- (CPString)primaryKeyAttributeForType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    if (primaryKeyCache != nil) {
        var entityCache = primaryKeyCache[aType];

        if (entityCache) {
            return [entityCache name];
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:aType];

    return [self primaryKeyAttributeForType:aType objectContext:objectContext];
}

/*!
 * Returns an array with all attributes for entity with name
 */
- (CPArray)attributesForEntityNamed:(CPString)entityName {
    if (attributeKeyCache != nil) {
        var entityCache = attributeKeyCache[entityName];

        if (entityCache) {
            return entityCache;
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];

    return [self attributesForEntityNamed:entityName];
}

/*!
 * Must return an array with keys for all attributes for this object.
 * To many relationship keys and to one relationsship foreign key attributes should be included.
 * To one relationsship attribute should not be included.
 * Primary key should not be included.
 * The objectContext will observe all these attributes for changes and record them. Not if the object context is 'read only'
 */
- (CPArray)attributeKeysForObject:(id)theObject withType:(CPString)entityName {
    if (attributeKeyCache != nil) {
        var entityCache = attributeKeyCache[entityName];

        if (entityCache) {
            var attributeKeys = [entityCache valueForKey:@"name"];

            return attributeKeys;
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];
    attributeKeys = [attributeKeyCache[entityName] valueForKey:@"name"];

    return attributeKeys;
}

/*!
 * Must return an array with keys for all to many relationship attributes for this object
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray)relationshipKeysForObject:(id)theObject withType:(CPString)entityName {
    if (relationshipKeyCache != nil) {
        var entityCache = relationshipKeyCache[entityName];

        if (entityCache) {
            var relationshipKeys = [entityCache valueForKey:@"name"];

            return relationshipKeys;
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];
    relationshipKeys = [relationshipKeyCache[entityName] valueForKey:@"name"];

    return relationshipKeys;
}

/*!
 *  Return property from model based in name and entity
 */
- (CPPropertyDescription)propertyForKey:(CPString)propertyName withEntityNamed:(CPString)entityName {
    if (propertyKeyCache != nil) {
        var entityCache = propertyKeyCache[entityName];

        if (entityCache) {
            return entityCache[propertyName];
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];

    return [self propertyForKey:propertyName withEntityNamed:entityName];
}

/*!
 *  Return Javascript object with all properties. Key is property name.
 */
- (JSObject)propertiesByNameForEntityNamed:(CPString)entityName {
    if (propertyKeyCache != nil) {
        var entityCache = propertyKeyCache[entityName];

        if (entityCache) {
            return entityCache;
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];

    return [self propertiesByNameForEntityNamed:entityName];
}

/*!
 *  Return attribute from model based on name and entity
 */
- (CPAttributeDescription)attributeForKey:(CPString)propertyName withEntityNamed:(CPString)entityName {
    var property = [self propertyForKey:propertyName withEntityNamed:entityName];

    return [property isKindOfClass:CPAttributeDescription] ? property : nil;
}

- (CPString)typeValueForAttributeKey:(CPString)attributeName withEntityNamed:(CPString)entityName {
    if (attributeValueTypeCache != nil) {
        var entityCache = attributeValueTypeCache[entityName];

        if (entityCache) {
            return entityCache[attributeName];
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];

    return [self typeValueForAttributeKey:attributeName withEntityNamed:entityName];
}

- (CPString)foreignKeyAttributeForInversRelationshipWithRelationshipAttribute:(CPString)relationshipKey withEntityNamed:(CPString)entityName {
    if (relationshipDestinationEntityNameCache != nil) {
        var destinationEntityCache = relationshipDestinationEntityNameCache[entityName];
        var inversRelationNameEntityCache = inversRelationNameCache[entityName];

        if (destinationEntityCache) {
            var inversRelationName = inversRelationNameEntityCache[relationshipKey];

            if (inversRelationName !== entityName)
                CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Invers relation name '" + inversRelationName + "' is wrong. Should be '" + entityName + "'");

            var destinationEntityName = destinationEntityCache[relationshipKey];
            var oldEntityName = [relationshipKey substringToIndex:[relationshipKey length] - 1];

            if (destinationEntityName !== oldEntityName)
                CPLog.error(@"[" + [self className] + @" " + _cmd + @"] Relation '" + relationshipKey + "' gives wrong destination entity name '" + destinationEntityName + "'. Should be '" + oldEntityName + "'");

            var foreignKey = [self foreignKeyAttributeForToOneRelationshipAttribute:inversRelationName forType:destinationEntityName];

            return foreignKey;
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];

    //if (relationshipDestinationEntityNameCache[entityName])
        return [self foreignKeyAttributeForInversRelationshipWithRelationshipAttribute:relationshipKey withEntityNamed:entityName];
    //else
    //    return nil;
}

- (CPString)destinationEntityNameForRelationshipKey:(CPString)attributeName withEntityNamed:(CPString)entityName {
    if (relationshipDestinationEntityNameCache != nil) {
        var entityCache = relationshipDestinationEntityNameCache[entityName];

        if (entityCache) {
            return entityCache[attributeName];
        }
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];

    return [self destinationEntityNameForRelationshipKey:attributeName withEntityNamed:entityName];
}

- (CPEntityDescription)entityForName:(CPString)entityName {
    if (relationshipDestinationEntityNameCache != nil) {
        return entityNameToEntityCache[entityName] || nil;
    }

    [self _createForeignKeyAttributeCacheForEntityName:entityName];

    return [self entityForName:entityName];
}

@end
