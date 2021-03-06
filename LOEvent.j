/*
 * Created by Martin Carlberg on Jun 14, 2012.
 * Copyright 2012, All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOObjectContext.j"
@import "LOArrayController.j"
@import "LOFaultArray.j"


@implementation LOEvent : CPObject {
    id              object;
    CPArray         objects;
}

- (id)initWithObject:(id) anObject {
    self = [super init];
    if (self) {
        object = anObject;
    }
    return self;
}

- (id)initWithObjects:(CPArray)someObjects {
    self = [super init];
    if (self) {
        objects = someObjects;
    }
    return self;
}

// I send in objectContext but I plan to remove it in this method. But first I have to refactor and use the LOEvents instead of LOModifyRecords
- (void) undoForContext:(LOObjectContext)objectContext {
    _CPRaiseInvalidAbstractInvocation(self, _cmd);
}

@end


@implementation LOInsertEvent : LOEvent {
    LOArrayController       arrayController;
    CPArray                 ownerObjects;
    CPString                ownerRelationshipKey;
}

+ (LOInsertEvent) insertEventWithObject:(id) anObject arrayController:(LOArrayController) anArrayController ownerObjects:(CPArray) someOwnerObjects ownerRelationshipKey:(CPString) anOwnerRelationshipKey {
    return [[LOInsertEvent alloc] initWithObject:anObject arrayController:anArrayController ownerObjects:someOwnerObjects ownerRelationshipKey:anOwnerRelationshipKey];
}

- (id)initWithObject:(id) anObject arrayController:(LOArrayController) anArrayController ownerObjects:(CPArray) someOwnerObjects ownerRelationshipKey:(CPString) anOwnerRelationshipKey {
    self = [super initWithObject:anObject];
    if (self) {
        arrayController = anArrayController;
        ownerObjects = someOwnerObjects;
        ownerRelationshipKey = anOwnerRelationshipKey;
    }
    return self;
}

- (void) undoForContext:(LOObjectContext)objectContext {
    [arrayController unInsertObject:object ownerObjects:ownerObjects ownerRelationshipKey:ownerRelationshipKey];
    [objectContext unInsertObject:object];      // Do this last so if autoCommit is true the changes will be saved.
//    [objectContext setSubDictionary: insertDict forKey:@"insertDict" forObject:object];
}

@end


@implementation LODeleteEvent : LOEvent {
    CPIndexSet              indexes;
    LOArrayController       arrayController;
    CPArray                 ownerObjects;
    CPString                ownerRelationshipKey;
}

+ (LODeleteEvent) deleteEventWithObjects:(CPArray)someObjects atArrangedObjectIndexes:(CPIndexSet)someIndexes arrayController:(LOArrayController) anArrayController ownerObjects:(CPArray)someOwnerObjects ownerRelationshipKey:(CPString)anOwnerRelationshipKey {
    return [[LODeleteEvent alloc] initWithObjects:someObjects atArrangedObjectIndexes:someIndexes arrayController:anArrayController ownerObjects:someOwnerObjects ownerRelationshipKey:anOwnerRelationshipKey];
}

- (id)initWithObjects:(CPArray)someObjects atArrangedObjectIndexes:(CPIndexSet)someIndexes arrayController:(LOArrayController)anArrayController ownerObjects:(CPArray)someOwnerObjects ownerRelationshipKey:(CPString)anOwnerRelationshipKey {
    self = [super initWithObjects:someObjects];
    if (self) {
        indexes = someIndexes;
        arrayController = anArrayController;
        ownerObjects = someOwnerObjects;
        ownerRelationshipKey = anOwnerRelationshipKey;
    }
    return self;
}

- (void) undoForContext:(LOObjectContext)objectContext {
    [arrayController unDeleteObjects:objects atArrangedObjectIndexes:indexes ownerObjects:ownerObjects ownerRelationshipKey:ownerRelationshipKey];
    [objectContext unDeleteObjects:objects];
//    [objectContext setSubDictionary: null forKey:@"deleteDict" forObject:object];
}

@end


@implementation LOUpdateEvent : LOEvent {
    CPDictionary    updateDict;
    CPString        dictType;
    CPString        attributeKey;
    id              oldValue;
    id              newValue;
}

+ (LOUpdateEvent)updateEventWithObject:(id) anObject updateDict:(CPDictionary) anUpdateDict dictType:(CPString)aDictType key:(CPString) aKey old:(id) anOldValue new:(id) aNewValue {
    return [[LOUpdateEvent alloc] initWithObject:anObject updateDict:anUpdateDict dictType:aDictType key:aKey old:anOldValue new:aNewValue];
}

- (id)initWithObject:(id)anObject updateDict:(CPDictionary)anUpdateDict dictType:(CPString)aDictType key:(CPString) aKey old:(id) anOldValue new:(id) aNewValue {
    self = [super initWithObject:anObject];
    if (self) {
        updateDict = [anUpdateDict copy];
        dictType = aDictType;
        attributeKey = aKey;
        oldValue = anOldValue;
        newValue = aNewValue;
    }
    return self;
}

- (void)undoForContext:(LOObjectContext)objectContext {
    [object setValue:oldValue forKey:attributeKey];
    [objectContext setSubDictionary: updateDict forKey:dictType forObject:object];
}

@end


@implementation LOToOneRelationshipUpdateEvent : LOUpdateEvent {
    CPString        foreignKey;
    id              oldForeignValue;
    id              newForeignValue;
}

+ (LOToOneRelationshipUpdateEvent)updateEventWithObject:(id)anObject updateDict:(CPDictionary)anUpdateDict dictType:(CPString)aDictType key:(CPString)aKey old:(id)anOldValue new:(id)aNewValue foreignKey:(CPString)aForeignKey oldForeignValue:(id)anOldForeignValue newForeignValue:(id)aNewForeignValue {
    return [[LOToOneRelationshipUpdateEvent alloc] initWithObject:anObject updateDict:anUpdateDict dictType:aDictType key:aKey old:anOldValue new:aNewValue foreignKey:aForeignKey oldForeignValue:anOldForeignValue newForeignValue:aNewForeignValue];
}

- (id)initWithObject:(id)anObject updateDict:(CPDictionary)anUpdateDict dictType:(CPString)aDictType key:(CPString)aKey old:(id)anOldValue new:(id)aNewValue foreignKey:(CPString)aForeignKey oldForeignValue:(id)anOldForeignValue newForeignValue:(id)aNewForeignValue {
    self = [super initWithObject:anObject updateDict:anUpdateDict dictType:aDictType key:aKey old:anOldValue new:aNewValue];
    if (self) {
        foreignKey = aForeignKey;
        oldForeignValue = anOldForeignValue;
        newForeignValue = aNewForeignValue;
    }
    return self;
}

- (void)undoForContext:(LOObjectContext)objectContext {
    [super undoForContext:objectContext];
    // The to-one relationship is recorded in the context under the 'real' foreign key (the
    // attribute ending in '_fk'). This is done in LOUpdateEvent already, so this class
    // is currently unnecessary. We'll leave it here though, in the event that we're to
    // implement bidirectional relationships.
    //[object setValue:oldForeignValue forKey:foreignKey];
}

@end


@implementation LOManyToManyRelationshipDeleteEvent : LOEvent {
    id        mapping;
    id        leftObject;
    id        rightObject;
    CPString  leftRelationshipKey;
    CPString  rightRelationshipKey;
    int       leftIndex;
    int       rightIndex;
}

+ (LOManyToManyRelationshipDeleteEvent) deleteEventWithMapping:(id)aMapping leftObject:(id)aLeftObject key:(CPString)aLeftKey index:(int)aLeftIndex rightObject:(id)aRightObject key:(CPString)aRightKey index:(int)aRightIndex {
    return [[LOManyToManyRelationshipDeleteEvent alloc] initWithMapping:aMapping leftObject:aLeftObject key:aLeftKey index:aLeftIndex rightObject:aRightObject key:aRightKey index:aRightIndex];
}

- (id)initWithMapping:(id)aMapping leftObject:(id)aLeftObject key:(CPString)aLeftKey index:(int)aLeftIndex rightObject:(id)aRightObject key:(CPString)aRightKey index:(int)aRightIndex {
    self = [super init];
    if (self) {
        mapping             = aMapping;

        leftObject          = aLeftObject;
        leftRelationshipKey = aLeftKey;
        leftIndex           = aLeftIndex;

        rightObject          = aRightObject;
        rightRelationshipKey = aRightKey;
        rightIndex           = aRightIndex;
    }
    return self;
}

- (void) undoForContext:(LOObjectContext)objectContext {
    [objectContext unDeleteObject:mapping];

    [self _insertObject:mapping atIndex:leftIndex ofRelationshipWithKey:leftRelationshipKey ofObject:leftObject];
    [self _insertObject:mapping atIndex:rightIndex ofRelationshipWithKey:rightRelationshipKey ofObject:rightObject];
}

- (void) _insertObject:(id)anObject atIndex:(int)anIndex ofRelationshipWithKey:(CPString)aRelationshipKey ofObject:(id)theParent
{
    var array = [theParent valueForKey:aRelationshipKey];
    if (anIndex === CPNotFound && [array isKindOfClass:[LOFaultArray class]] && [array faultPopulated])
        anIndex = [array count];    // The index is CPNotFound if the fault array was not populated when the delete was done. Now it is populated and we just add the object last.
    if (anIndex !== CPNotFound) {
        var indexSet = [CPIndexSet indexSetWithIndex:anIndex];
        [theParent willChange:CPKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:aRelationshipKey];
        [array insertObject:anObject atIndex:anIndex];
        [theParent didChange:CPKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:aRelationshipKey];
    }
}

@end

@implementation LOManyToManyRelationshipInsertEvent : LOEvent {
    id        mapping;
    id        leftObject;
    id        rightObject;
    CPString  leftRelationshipKey;
    CPString  rightRelationshipKey;
    int       leftIndex;
    int       rightIndex;
}

+ (LOManyToManyRelationshipInsertEvent) insertEventWithMapping:(id)aMapping leftObject:(id)aLeftObject key:(CPString)aLeftKey index:(int)aLeftIndex rightObject:(id)aRightObject key:(CPString)aRightKey index:(int)aRightIndex {
    return [[LOManyToManyRelationshipInsertEvent alloc] initWithMapping:aMapping leftObject:aLeftObject key:aLeftKey index:aLeftIndex rightObject:aRightObject key:aRightKey index:aRightIndex];
}

- (id)initWithMapping:(id)aMapping leftObject:(id)aLeftObject key:(CPString)aLeftKey index:(int)aLeftIndex rightObject:(id)aRightObject key:(CPString)aRightKey index:(int)aRightIndex {
    self = [super init];
    if (self) {
        mapping             = aMapping;

        leftObject          = aLeftObject;
        leftRelationshipKey = aLeftKey;
        leftIndex           = aLeftIndex;

        rightObject          = aRightObject;
        rightRelationshipKey = aRightKey;
        rightIndex           = aRightIndex;
    }
    return self;
}

- (void) undoForContext:(LOObjectContext)objectContext {
    [objectContext unInsertObject:mapping];

    [self _removeObject:mapping atIndex:leftIndex ofRelationshipWithKey:leftRelationshipKey ofObject:leftObject];
    [self _removeObject:mapping atIndex:rightIndex ofRelationshipWithKey:rightRelationshipKey ofObject:rightObject];
}

- (void) _removeObject:(id)anObject atIndex:(int)anIndex ofRelationshipWithKey:(CPString)aRelationshipKey ofObject:(id)theParent
{
    var array = [theParent valueForKey:aRelationshipKey];
    var idx = [array indexOfObjectIdenticalTo:mapping];
    if (idx !== anIndex) {
        throw [CPException raise:CPInternalInconsistencyException reason:@"Recorded index " + anIndex + " not equal to real index " + idx];
    }
    var indexSet = [CPIndexSet indexSetWithIndex:anIndex];
    [theParent willChange:CPKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:aRelationshipKey];
    [array removeObjectAtIndex:anIndex];
    [theParent didChange:CPKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:aRelationshipKey];
}

@end
