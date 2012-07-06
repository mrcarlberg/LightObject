/*
 * Created by Martin Carlberg on Juli 18, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectStore.j"


@implementation LOLocalDictionaryObjectStore : LOObjectStore {
    CPMutableDictionary     objectFixture @accessors;
}

- (id)init {
    self = [super init];
    if (self) {
        objectFixture = [CPMutableDictionary dictionary];
    }
    return self;
}

- (CPArray) _fetchAndFilterObjects:(LOFFetchSpecification) fetchSpecification  objectContext:(LOObjectContext)objectContext {
    //print(_cmd + " entity:" + [fetchSpecification entityName] + " oper: " + [fetchSpecification operator] + " qualifier:" + [fetchSpecification qualifier]);
    var fixtureObjects = [objectFixture objectForKey:[fetchSpecification entityName]];
    var predicate = [fetchSpecification qualifier];
    if (predicate) {
        fixtureObjects = [fixtureObjects filteredArrayUsingPredicate:predicate];
    }

    var objects = [];
    var registeredObjects = [CPMutableDictionary dictionary];

    var possibleToOneFaultObjects =[CPMutableArray array];

    for (var i=0; i<[fixtureObjects count]; i++) {
        var object = [fixtureObjects objectAtIndex:i];

        var objectUuid = [object valueForKey:@"key"];
        var objectType = [objectContext typeOfObject:object];
        var newObject = [registeredObjects objectForKey:objectUuid];
        if (!newObject) {
            var newObject = [objectContext newObjectForType:objectType];
            if (newObject) {
                [newObject setValue:objectUuid forKey:@"key"];
                [registeredObjects setObject:newObject forKey:objectUuid];
            }
        }
        if (!newObject) continue;

        [self _populateNewObject:newObject fromReceivedObject:object notePossibleToOneFaults:possibleToOneFaultObjects objectContext:objectContext];
        [objects addObject:newObject];
    }

    [self _tryResolvePossibleToOneFaults:possibleToOneFaultObjects withAlreadyRegisteredObjects:registeredObjects];

    return objects;
}

- (void)_populateNewObject:(id)newObject fromReceivedObject:(id)theReceivedObject notePossibleToOneFaults:(CPMutableArray)thePossibleToOneFaults objectContext:(LOObjectContext)anObjectContext {
    var attributeKeys = [self attributeKeysForObject:newObject];
    //print(_cmd + " processing attribute keys of new object: " + [attributeKeys description]);
    for (var j=0; j<[attributeKeys count]; j++) {
        var key = [attributeKeys objectAtIndex:j];
        var value = [theReceivedObject valueForKey:key];
        if ([key hasSuffix:@"_fk"]) {    // Handle to one relationship
            key = [key substringToIndex:[key length] - 3]; // Remove "_fk" at end
            if (value) {
                var toOne = [anObjectContext objectForGlobalId:value];
                if (toOne) {
                    value = toOne;
                } else {
                    // Add it to a list and try again after we have registered all objects.
                    // FIXME: should set newObject, right?
                    [thePossibleToOneFaults addObject:{@"object":newObject , @"relationshipKey":key , @"globalId":value}];
                    value = nil;
                }
            }
        }
        [newObject setValue:value forKey:key];
    }
}

- (void)_tryResolvePossibleToOneFaults:(CPArray)theCandidates withAlreadyRegisteredObjects:(CPDictionary)theRegisteredObjects {
    var size = [theCandidates count];
    for (var i = 0; i < size; i++) {
        var aCandidate = [theCandidates objectAtIndex:i];
        var toOne = [theRegisteredObjects objectForKey:aCandidate.globalId];
        if (toOne) {
            [aCandidate.object setValue:toOne forKey:aCandidate.relationshipKey];
        } else {
            //console.log([self className] + " " + _cmd + " Can't find object for toOne relationship '" + aCandidate.relationshipKey + "' (" + toOne + ") on object " + aCandidate.object);
            //print([self className] + " " + _cmd + " Can't find object for toOne relationship '" + aCandidate.relationshipKey + "' (" + toOne + ") on object " + aCandidate.object);
        }
    }
}

/*!
 * Must call [objectContext objectsReceived: withFetchSpecification:] when objects are received
 */
- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    var objects = [self _fetchAndFilterObjects:fetchSpecification objectContext:objectContext];
    [objectContext objectsReceived:objects withFetchSpecification:fetchSpecification];
}

/*!
 * Must call [objectContext faultReceived:(CPArray)objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification faultArray:(LOFaultArray)faultArray] when fault objects are received
 */
- (CPArray) requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    var objects = [self _fetchAndFilterObjects:fetchSpecification objectContext:objectContext];
    [objectContext faultReceived:objects withFetchSpecification:fetchSpecification faultArray:faultArray];
}

/*!
 * This method should save all changes to the backend.
 * The ObjectContext has a list of LOModifyRecord that contains all changes.
 * Must call [objectContext saveChangesDidComplete] when done
 */
- (void) saveChangesWithObjectContext:(LOObjectContext) objectContext {
    [objectContext saveChangesDidComplete];
}

/*!
 * Must return an array with keys for all attributes for this object.
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray) attributeKeysForObject:(id) theObject {
    return [theObject allKeys];
}

/*!
 * Returns the type of the object
 */
- (CPString) typeOfObject:(id) theObject {
    return [theObject objectForKey:@"entity"];
}

/*!
 * Returns a unique id for the object
 */
- (CPString) globalIdForObject:(id) theObject {
    return [theObject UID];
}

@end
