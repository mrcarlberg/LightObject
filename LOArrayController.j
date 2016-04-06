/*
 * LOArrayController.j
 *
 * Created by Martin Carlberg on Feb 27, 2012.
 * Copyright 2012, All rights reserved.
 */

@import <Foundation/CPObject.j>
@import <AppKit/CPArrayController.j>

@class LOInsertEvent
@class LODeleteEvent
@class LOObjectContext
@class LOFetchSpecification


@implementation LOArrayController : CPArrayController
{
    @outlet LOObjectContext objectContext @accessors;
    CPArray prepareContentBlocksToRunWhenModelIsReceived;
}

- (id)init {
    self = [super init];
    if (self) {
        prepareContentBlocksToRunWhenModelIsReceived = [];
    }
    return self;
}

- (id)initWithCoder:(CPCoder)aCoder {
    prepareContentBlocksToRunWhenModelIsReceived = [];
    self = [super initWithCoder:aCoder];
    if (self) {
    }
    return self;
}

- (void)awakeFromCib {
    // In 'prepareContent' the bindings will not be ready so blocks are added to this array and executed here.
    if (prepareContentBlocksToRunWhenModelIsReceived)
    {
        var objectStore = [objectContext objectStore];
        [prepareContentBlocksToRunWhenModelIsReceived enumerateObjectsUsingBlock:function(aBlock) {
            [objectStore addBlockToRunWhenModelIsReceived:aBlock];
        }];
        prepareContentBlocksToRunWhenModelIsReceived = nil;
    }
}

// TODO: We should advertise a 'real' binding for objectContext, not piggyback on managedObjectContext.
- (void)setManagedObjectContext:(id)aContext {
    objectContext = aContext;
}

// TODO: We should advertise a 'real' binding for objectContext, not piggyback on managedObjectContext.
- (id)managedObjectContext {
    return objectContext;
}

- (void)prepareContent {
    var entityName = [self entityName];
    if (entityName != nil) {
        [prepareContentBlocksToRunWhenModelIsReceived addObject:function() {
            [self fetch:nil];
        }];
    } else {
        [super prepareContent];
    }
}

/*!
    Fetches the objects using fetchPredicate.
    @param id sender - The sender of the message.
*/
- (@action)fetch:(id)sender {
    var entityName = [self entityName];
    if (entityName != nil) {
        var aFetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:entityName qualifier:[self fetchPredicate]];
        if ([self usesLazyFetching]) {
            [aFetchSpecification setOperator:@"lazy"];
        }
        [objectContext requestObjectsWithFetchSpecification:aFetchSpecification withCompletionHandler:function(resultArray, statusCode) {
            if (statusCode === 200)
                [self setContent:resultArray];
        }];
    }
}

/*!
    Creates and adds a new object to the receiver's content and arranged objects.

    @param id sender - The sender of the message.
*/
- (void)add:(id)sender {
    if (![self canAdd])
        return;

    var newObject = [self automaticallyPreparesContent] ? [self newObject] : [self _defaultNewObject];
    var entityName = [self entityName];

    if (entityName) newObject._loObjectType = entityName;
    [self insertAndRegisterObject:newObject atArrangedObjectIndex:nil];
}

/*!
    Creates a new object and inserts it into the receiver's content array.
    @param id sender - The sender of the message.
*/
- (@action)insert:(id)sender {
    if (![self canInsert])
        return;

    var newObject = [self automaticallyPreparesContent] ? [self newObject] : [self _defaultNewObject];
    var entityName = [self entityName];
    var lastSelectedIndex = [_selectionIndexes lastIndex];

    if (entityName) newObject._loObjectType = entityName;
    [self insertAndRegisterObject:newObject atArrangedObjectIndex:lastSelectedIndex];
}

- (id)_defaultNewObject {
    var objectClass;
    if (objectContext) {
        var objectStore = [objectContext objectStore];
        if (objectStore) {
            var entityName = [self entityName];
            var entityDescription = [objectStore entityForName:entityName];
            if (entityDescription) {
                var classname = [entityDescription externalName];
                if (classname) {
                    objectClass = CPClassFromString(classname);
                }
            }
        }
    }

    if (objectClass == nil) {
        objectClass = [self objectClass];
    }

    return [[objectClass alloc] init];
}

- (void)insertAndRegisterObject:(id)newObject atArrangedObjectIndex:(int)index {
    if (![self canInsert])
        return;

    if (index != nil && index !== CPNotFound)
        [self insertObject:newObject atArrangedObjectIndex:index];
    else
        [self addObject:newObject];

    // Ok, now we need to tell the object context that we have this new object and it is a new relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    // We check the contentArray bindings to get hold of the owner object.
    // TODO: Use model instead of bindings to find owner object if possible
    var info = [self infoForBinding:@"contentArray"];
    var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
    var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
    var lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
    var bindToObject = [info objectForKey:CPObservedObjectKey];
    var selectedOwnerObjects = [bindToObject selectedObjects];
    var registeredOwnerObjects = [CPMutableArray array];
    var selectedOwnerObjectsSize = [selectedOwnerObjects count];
    for (var i = 0; i < selectedOwnerObjectsSize; i++) {
        var selectedOwnerObject = [selectedOwnerObjects objectAtIndex:i];
        if ([selectedOwnerObject isKindOfClass:CPControllerSelectionProxy]) {
            selectedOwnerObject = [[selectedOwnerObject._controller selectedObjects] objectAtIndex:0];
        }
        if ([objectContext isObjectRegistered:selectedOwnerObject]) {
            [registeredOwnerObjects addObject:selectedOwnerObject];
            [objectContext _add:newObject toRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
        }
    }

    var insertEvent = [LOInsertEvent insertEventWithObject:newObject arrayController:self ownerObjects:[registeredOwnerObjects count] ? registeredOwnerObjects : nil ownerRelationshipKey:lastbindingKeyPath];
    [objectContext registerEvent:insertEvent];
    [objectContext _insertObject:newObject];
    if ([objectContext autoCommit]) [objectContext saveChanges];
}

- (id) unInsertObject:(id)object ownerObjects:(CPArray) ownerObjects ownerRelationshipKey:(CPString) ownerRelationshipKey {
    [self _removeObjects:[object]];
    if (ownerObjects && ownerRelationshipKey) {
        var size = [ownerObjects count];
        for (var i = 0; i < size; i++) {
            var ownerObject = [ownerObjects objectAtIndex:i];
            [objectContext _unAdd:object toRelationshipWithKey:ownerRelationshipKey forObject:ownerObject];
        }
    }
}

- (void)removeObjects:(CPArray)objectsToDelete {
    var objectsToDeleteIndexes = [CPMutableIndexSet indexSet];
    [objectsToDelete enumerateObjectsUsingBlock:function(aCandidate) {
        var anIndex = [[self arrangedObjects] indexOfObjectIdenticalTo:aCandidate];
        if (anIndex === CPNotFound) {
            [CPException raise:CPInvalidArgumentException reason:@"Can't delete object not in array controller: " + aCandidate];
        }
        [objectsToDeleteIndexes addIndex:anIndex];
    }];
    [self _removeObjects:objectsToDelete atIndexes:objectsToDeleteIndexes shouldRegisterEvent:YES];
}

- (void)_removeObjects:(CPArray)objectsToDelete {
    var objectsToDeleteIndexes = [CPMutableIndexSet indexSet];
    [objectsToDelete enumerateObjectsUsingBlock:function(aCandidate) {
        var anIndex = [[self arrangedObjects] indexOfObjectIdenticalTo:aCandidate];
        if (anIndex === CPNotFound) {
            [CPException raise:CPInvalidArgumentException reason:@"Can't delete object not in array controller: " + aCandidate];
        }
        [objectsToDeleteIndexes addIndex:anIndex];
    }];
    [self _removeObjects:objectsToDelete atIndexes:objectsToDeleteIndexes shouldRegisterEvent:NO];
}

- (void)remove:(id)sender {
    var selectedObjectsIndexes = [[self selectionIndexes] copy];
    var selectedObjects = [self selectedObjects];
    [self _removeObjects:selectedObjects atIndexes:selectedObjectsIndexes shouldRegisterEvent:YES];
}

- (void)_removeObjects:(CPArray)objectsToDelete atIndexes:(CPIndexSet)objectsToDeleteIndexes shouldRegisterEvent:(BOOL)shouldRegisterEvent {
    // Note: assumes objectsToDeleteIndexes corresponds to objectsToDelete.
    [self removeObjectsAtArrangedObjectIndexes:objectsToDeleteIndexes];
    // Ok, now we need to tell the object context that we have this removed object and it is a removed relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    var registeredOwnerObjects = [CPMutableArray array];
    var lastbindingKeyPath = nil;
    [objectsToDelete enumerateObjectsUsingBlock:function(deletedObject) {
        var info = [self infoForBinding:@"contentArray"];
        var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
        var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
        lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
        var bindToObject = [info objectForKey:CPObservedObjectKey];
        [[bindToObject selectedObjects] enumerateObjectsUsingBlock:function(selectedOwnerObject) {
            if ([objectContext isObjectRegistered:selectedOwnerObject]) {
                [registeredOwnerObjects addObject:selectedOwnerObject];
                [objectContext _delete:deletedObject withRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
            }
        }];
    }];

    if (shouldRegisterEvent) {
        var deleteEvent = [LODeleteEvent deleteEventWithObjects:objectsToDelete atArrangedObjectIndexes:objectsToDeleteIndexes arrayController:self ownerObjects:[registeredOwnerObjects count] ? registeredOwnerObjects : nil ownerRelationshipKey:lastbindingKeyPath];
        [objectContext registerEvent:deleteEvent];
        [objectContext deleteObjects: objectsToDelete]; // this will commit if auto commit is enabled
    }
}

- (id) unDeleteObjects:(id)objects atArrangedObjectIndexes:(CPIndexSet)indexSet ownerObjects:(CPArray) ownerObjects ownerRelationshipKey:(CPString) ownerRelationshipKey {
    var objectSize = [objects count];
    var index = [indexSet firstIndex];
    for (var i = 0; i < objectSize; i++) {
        var object = [objects objectAtIndex:i];
        [self insertObject:object atArrangedObjectIndex:index];
        if (ownerObjects && ownerRelationshipKey) {
            var size = [ownerObjects count];
            for (var j = 0; j < size; j++) {
                var ownerObject = [ownerObjects objectAtIndex:j];
                [objectContext _unAdd:object toRelationshipWithKey:ownerRelationshipKey forObject:ownerObject];
            }
        }
        index = [indexSet indexGreaterThanIndex:index];
    }
}

/*
- (CPArray) arrangeObjects: (CPArray) objects {
    var testArray = [[_CPKVCArray alloc] init];
    var testArrayCopy = [testArray copy];
    //CPLog.trace(@"tracing: arrangeObjects: class = " + [objects class]);
    if ([objects className] === @"_CPKVCArray") {
        debugger;
    }
    var copy = [objects copy];
    //CPLog.trace(@"tracing: arrangeObjects: " + [CPString JSONFromObject:copy]);
    [super arrangeObjects:objects];
}
*/
@end
