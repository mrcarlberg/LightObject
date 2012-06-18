/*
 * LOArrayController.j
 *
 * Created by Martin Carlberg on Feb 27, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>

@implementation LOArrayController : CPArrayController
{
    @outlet LOObjectContext objectContext;
}

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)insert:(id)sender {
    console.log([self className] + " " + _cmd);
    if (![self canInsert])
        return;
    
    var newObject = [self automaticallyPreparesContent] ? [self newObject] : [self _defaultNewObject];
    [self addObject:newObject];
    // Ok, now we need to tell the object context that we have this new object and it is a new relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    var info = [self infoForBinding:@"contentArray"];
    var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
    var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
    var lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
    var bindToObject = [info objectForKey:CPObservedObjectKey];
    var selectedOwnerObjects = [bindToObject selectedObjects];
    var selectedOwnerObjectsSize = [selectedOwnerObjects count];
    var registeredOwnerObjects = [CPMutableArray array];
    for (var i = 0; i < selectedOwnerObjectsSize; i++) {
        var selectedOwnerObject = [selectedOwnerObjects objectAtIndex:i];
        if ([objectContext isObjectRegistered:selectedOwnerObject]) {
            [registeredOwnerObjects addObject:selectedOwnerObject];
            [objectContext _add:newObject toRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
        }
    }
    [objectContext insertObject:newObject]; // Do this last so if autoCommit is on it will trigger saveChanges

    var insertEvent = [LOInsertEvent insertEventWithObject:newObject arrayController:self ownerObjects:[registeredOwnerObjects count] ? registeredOwnerObjects : nil ownerRelationshipKey:lastbindingKeyPath];
    [objectContext registerEvent:insertEvent forObject:newObject];
}

- (id) unInsertObject:(id)object ownerObjects:(CPArray) ownerObjects ownerRelationshipKey:(CPString) ownerRelationshipKey {
    console.log([self className] + " " + _cmd);
    [self removeObjects:[object]];
    if (ownerObjects && ownerRelationshipKey) {
        var size = [ownerObjects count];
        for (var i = 0; i < size; i++) {
            var ownerObject = [ownerObjects objectAtIndex:i];
            [objectContext _unAdd:object toRelationshipWithKey:ownerRelationshipKey forObject:ownerObject];
        }
    }
}

- (void)remove:(id)sender {
    console.log([self className] + " " + _cmd);
    var selectedObjects = [self selectedObjects];
    [self removeObjectsAtArrangedObjectIndexes:_selectionIndexes];
    // Ok, now we need to tell the object context that we have this removed object and it is a removed relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    var selectedObjectsSize = [selectedObjects count];
    for (var i = 0; i < selectedObjectsSize; i ++) {
        var deletedObject = [selectedObjects objectAtIndex:i];
        var info = [self infoForBinding:@"contentArray"];
        var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
        var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
        var lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
        var bindToObject = [info objectForKey:CPObservedObjectKey];
        var selectedOwnerObjects = [bindToObject selectedObjects];
        var selectedOwnerObjectsSize = [selectedOwnerObjects count];
        for (var j = 0; j < selectedOwnerObjectsSize; j++) {
            var selectedOwnerObject = [selectedOwnerObjects objectAtIndex:j];
            if ([objectContext isObjectRegistered:selectedOwnerObject]) {
                [objectContext _delete:deletedObject withRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
            }
        }
    }
    [objectContext deleteObjects: selectedObjects]; // Do this last so if autoCommit is on it will trigger saveChanges

    var deleteEvent = [LODeleteEvent deleteEventWithObject:theObject];
    [self registerEvent:deleteEvent forObject:theObject];
}
/*
- (CPArray) arrangeObjects: (CPArray) objects {
    var testArray = [[_CPKVCArray alloc] init];
    var testArrayCopy = [testArray copy];
    CPLog.trace(@"tracing: arrangeObjects: class = " + [objects class]);
    if ([objects className] === @"_CPKVCArray") {
        debugger;
    }
    var copy = [objects copy];
    CPLog.trace(@"tracing: arrangeObjects: " + [CPString JSONFromObject:copy]);
    [super arrangeObjects:objects];
}
*/
@end