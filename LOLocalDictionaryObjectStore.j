/*
 * Created by Martin Carlberg on Juli 18, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectStore.j"


@implementation LOFaultArray (UnCircularArrayAdditionsXX)
- (BOOL)isEqualToArray:(id)anArray history:(CPArray)history
{
    //print("self: " + [self className] + " " + [self UID] + " other: " + [anArray className] + " " + [anArray UID] + " history: " + [history description]);
    var arr = anArray;
    if (anArray && [anArray isKindOfClass:[LOFaultArray class]])
        arr = [anArray array];
    return [array isEqualToArray:arr history:history];
}
@end


@implementation CPArray (UnCircularArrayAdditions)
- (BOOL)isEqualToArray:(id)anArray history:(CPArray)history
{
    if (self === anArray)
        return YES;

    if (![anArray isKindOfClass:CPArray])
        return NO;

    var count = [self count],
        otherCount = [anArray count];

    //print("self: " + [self className] + " " + [self UID] + " other: " + [anArray className] + " " + [anArray UID] + " history: " + [history description]);

    if (anArray === nil || count !== otherCount)
        return NO;

    var index = 0;

    for (; index < count; ++index)
    {
        var lhsObject = [self objectAtIndex:index],
            rhsObject = [anArray objectAtIndex:index];

        // If they're not equal, and either doesn't have an isa, or they're !isEqual (not isEqual)
        if (lhsObject === rhsObject) continue;

        if ([history containsObject:[lhsObject UID]] || [history containsObject:[rhsObject UID]])
            return NO;

        if (lhsObject && lhsObject.isa && rhsObject && rhsObject.isa) {
            if ([lhsObject isKindOfClass:[CPDictionary class]] && [rhsObject isKindOfClass:[CPDictionary class]]) {
                var x = [lhsObject isEqualToDictionary:rhsObject history:[history arrayByAddingObjectsFromArray:[[lhsObject UID], [rhsObject UID]]]];
                if (x == -1) return -1;
                if (x == YES) continue;
            }

            if ([lhsObject isKindOfClass:[CPArray class]] && [rhsObject isKindOfClass:[CPArray class]]) {
                var x = [lhsObject isEqualToArray:rhsObject history:[history arrayByAddingObjectsFromArray:[[lhsObject UID], [rhsObject UID]]]];
                if (x == -1) return -1;
                if (x == YES) continue;
            }

            //print("self: " + [self className] + " " + [self UID] + " left: " + [lhsObject className] + " " + [lhsObject UID] + " right: " + [rhsObject className] + " " + [rhsObject UID]);

            if ([lhsObject respondsToSelector:@selector(isEqual:)] && [lhsObject isEqual:rhsObject])
                continue;
        }
        
        return NO;
    }

    return YES;
}
@end


@implementation ShallowDescriptionDictionary : CPMutableDictionary {
}
- (CPString)description
{
    var string = "{\n\t",
        keys = _keys,
        index = 0,
        count = _count;

    for (; index < count; ++index)
    {
        var key = keys[index],
            value = valueForKey(key);

        string += key + " = \"" + value + "\"\n\t";
    }

    return string + "}";
}

- (BOOL)isEqualToDictionary:(CPDictionary)aDictionary
{
    if (self === aDictionary)
        return YES;

    var count = [self count];

    if (count !== [aDictionary count])
        return NO;

    var index = count;

    //print("self: " + [self className] + " " + [self UID] + " other: " + [aDictionary className] + " " + [aDictionary UID]);

    while (index--)
    {
        var currentKey = _keys[index],
            lhsObject = _buckets[currentKey],
            rhsObject = aDictionary._buckets[currentKey];

        if (lhsObject === rhsObject)
            continue;

        if (lhsObject && lhsObject.isa && rhsObject && rhsObject.isa && [lhsObject isKindOfClass:[CPDictionary class]] && [rhsObject isKindOfClass:[CPDictionary class]]) {
            var x = [lhsObject isEqualToDictionary:rhsObject history:[[lhsObject UID], [rhsObject UID]]];
            if (x == YES) continue;
            if (x == NO) return NO;
            if (x == -1) return NO;
        }

        //print("self: " + [self className] + " " + [self UID] + " left: " + [lhsObject className] + " " + [lhsObject UID] + " right: " + [rhsObject className] + " " + [rhsObject UID]);

        if (lhsObject && lhsObject.isa && rhsObject && rhsObject.isa && [lhsObject respondsToSelector:@selector(isEqual:)] && [lhsObject isEqual:rhsObject])
            continue;

        return NO;
    }

    return YES;
}

- (BOOL)isEqualToDictionary:(CPDictionary)aDictionary history:(CPArray)history
{
    if (self === aDictionary)
        return YES;

    var count = [self count];

    if (count !== [aDictionary count])
        return NO;

    var index = count;

    //print("+self: " + [self className] + " " + [self UID] + " other: " + [aDictionary className] + " " + [aDictionary UID] + " history: " + [history description]);

    while (index--)
    {
        var currentKey = _keys[index],
            lhsObject = _buckets[currentKey],
            rhsObject = aDictionary._buckets[currentKey];

        if (lhsObject === rhsObject)
            continue;

        if ([history containsObject:[lhsObject UID]] || [history containsObject:[rhsObject UID]])
            return NO;

        if (lhsObject && lhsObject.isa && rhsObject && rhsObject.isa) {
            if ([lhsObject isKindOfClass:[CPDictionary class]] && [rhsObject isKindOfClass:[CPDictionary class]]) {
                var x = [lhsObject isEqualToDictionary:rhsObject history:[history arrayByAddingObjectsFromArray:[[lhsObject UID], [rhsObject UID]]]];
                if (x == -1) return -1;
                if (x == YES) continue;
            }

            if ([lhsObject isKindOfClass:[CPArray class]] && [rhsObject isKindOfClass:[CPArray class]]) {
                var x = [lhsObject isEqualToArray:rhsObject history:[history arrayByAddingObjectsFromArray:[[lhsObject UID], [rhsObject UID]]]];
                if (x == -1) return -1;
                if (x == YES) continue;
            }

            //print("+self: " + [self className] + " " + [self UID] + " left: " + [lhsObject className] + " " + [lhsObject UID] + " right: " + [rhsObject className] + " " + [rhsObject UID]);

            if ([lhsObject respondsToSelector:@selector(isEqual:)] && [lhsObject isEqual:rhsObject])
                continue;
        }

        return NO;
    }

    return YES;
}
@end


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
        var newObject = [ShallowDescriptionDictionary dictionary];
        var attributeKeys = [self attributeKeysForObject:object];
        for (var j=0; j<[attributeKeys count]; j++) {
            var key = [attributeKeys objectAtIndex:j];
            var value = [object valueForKey:key];
            if ([key hasSuffix:@"_fk"]) {    // Handle to one relationship
                key = [key substringToIndex:[key length] - 3]; // Remove "_fk" at end
                if (value) {
                    var toOne = [objectContext objectForGlobalId:value];
                    if (toOne) {
                        value = toOne;
                    } else {
                        // Add it to a list and try again after we have registered all objects.
                        [possibleToOneFaultObjects addObject:{@"object":object , @"relationshipKey":key , @"globalId":value}];
                        value = nil;
                    }
                }
            }
            [newObject setValue:value forKey:key];
        }
        [objects addObject:newObject];
        [registeredObjects setObject:newObject forKey:[self globalIdForObject:newObject]];
    }

    var size = [possibleToOneFaultObjects count];
    for (var i = 0; i < size; i++) {
        var possibleToOneFaultObject = [possibleToOneFaultObjects objectAtIndex:i];
        var toOne = [registeredObjects objectForKey:possibleToOneFaultObject.globalId];
        if (toOne) {
            [possibleToOneFaultObject.object setValue:toOne forKey:possibleToOneFaultObject.relationshipKey];
        } else {
            //console.log([self className] + " " + _cmd + " Can't find object for toOne relationship '" + possibleToOneFaultObject.relationshipKey + "' (" + toOne + ") on object " + possibleToOneFaultObject.object);
            //print([self className] + " " + _cmd + " Can't find object for toOne relationship '" + possibleToOneFaultObject.relationshipKey + "' (" + toOne + ") on object " + possibleToOneFaultObject.object);
        }
    }

    return objects;
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
