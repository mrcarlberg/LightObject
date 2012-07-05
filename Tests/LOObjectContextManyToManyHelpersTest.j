@import "../LightObject.j"

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
//objj_msgSend_decorate(objj_backtrace_decorator);


@implementation TestObjectStore : LOLocalDictionaryObjectStore {
    CPMutableDictionary fixtureEntityRelationshipKeys;
}

- (id)init {
    self = [super init];
    if (self) {
        fixtureEntityRelationshipKeys = [CPMutableDictionary dictionary];
    }
    return self;
}

- (void)addFixtureObject:(id)aJSObject {
    var object = [CPMutableDictionary dictionaryWithJSObject:aJSObject];
    var entity = [self typeOfObject:object];
    var entityArray = [[self objectFixture] objectForKey:entity];
    if (!entityArray) {
        entityArray = [CPMutableArray array];
        [[self objectFixture] setObject:entityArray forKey:entity];
    }
    [entityArray addObject:object];
}

- (void)setFixtureRelationshipKeys:(CPArray)theKeys forEntity:(CPString)anEntity {
    [fixtureEntityRelationshipKeys setObject:theKeys forKey:anEntity];
}

- (void)addFixtureRelationshipKey:(CPString)aKey forEntity:(CPString)anEntity {
    var keys = [fixtureEntityRelationshipKeys objectForKey:anEntity];
    if (!keys) {
        keys = [CPMutableArray array];
        [fixtureEntityRelationshipKeys setObject:keys forKey:anEntity];
    }
    if (![keys containsObject:aKey]) [keys addObject:aKey];
}

- (void)addFakeArrayFaultsForObjects:(CPArray)theObjects inObjectContext:(LOObjectContext)aContext {
    for (var i=0; i<theObjects.length; i++) {
        var object = theObjects[i];
        var relationshipKeys = [self relationshipKeysForObject:object];
        for (var j=0; j<relationshipKeys.length; j++) {
            var relationshipKey = relationshipKeys[j];
            var fault = [[LOFaultArray alloc] initWithObjectContext:aContext masterObject:object relationshipKey:relationshipKey];
            [object setObject:fault forKey:relationshipKey];
        }
    }
}

/*!
 * Returns a unique id for the object.
 * Overridden to use the property "key" instead of the default object UID
 * so that we can control object IDs in the tests.
 */
- (CPString)globalIdForObject:(id) theObject {
    return [theObject objectForKey:@"key"];
}

- (CPArray)relationshipKeysForObject:(id)theObject {
    var entity = [self typeOfObject:theObject];
    return [fixtureEntityRelationshipKeys objectForKey:entity] || [];
}

@end

@implementation LOObjectContextManyToManyHelpersTest : OJTestCase {
    LOObjectContext     objectContext;
    LOObjectStore       objectStore;
    CPArray             persons;
    CPArray             schools;
}

- (void)setUp()
{
    persons = nil;
    schools = nil;

    objectStore = [[TestObjectStore alloc] init];

    objectContext = [[LOObjectContext alloc] initWithDelegate:self];
    [objectContext setObjectStore:objectStore];
    [objectContext setAutoCommit:NO];

    [objectStore addFixtureObject:{@"entity": @"person", @"key": 1, @"name": @"Hector"}];
    [objectStore addFixtureObject:{@"entity": @"school", @"key": 100, @"name": @"School 1"}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 1000, @"person_fk": 1, @"school_fk": 100}];
    [objectStore addFixtureRelationshipKey:@"persons_schools" forEntity:@"person"];
    [objectStore addFixtureRelationshipKey:@"persons_schools" forEntity:@"school"];
    [self requestAllObjectsForEntity:@"person"];
    [self requestAllObjectsForEntity:@"school"];
    [objectStore addFakeArrayFaultsForObjects:persons inObjectContext:objectContext];
    [objectStore addFakeArrayFaultsForObjects:schools inObjectContext:objectContext];
}

// Delegate method for LOObjectContext
- (id) newObjectForType:(CPString) aType {
    return [CPMutableDictionary dictionaryWithObject:aType forKey:@"entity"];
}

// Delegate method for LOObjectContext
- (void) objectsReceived:(CPArray)theObjects forObjectContext:(LOObjectContext)anObjectContext withFetchSpecification:aFetchSpecification {
    if (aFetchSpecification.entityName === @"person") {
        persons = theObjects;
    } else if (aFetchSpecification.entityName === @"school") {
        schools = theObjects;
    }
}    

- (void)requestAllObjectsForEntity:(CPString)anEntity {
    var fs = [LOFetchSpecification fetchSpecificationForEntityNamed:anEntity];
    [objectContext requestObjectsWithFetchSpecification:fs];
}

- (void)testFaultingManyToManyWorks {
    [self assert:1 equals:[persons count] message:@"persons"];
    [self assert:1 equals:[schools count] message:@"schools"];
    // trigger faults
    var person = persons[0];
    var school = schools[0];
    [self assert:1 equals:[[person objectForKey:@"persons_schools"] count] message:@"person's schools"];
    [self assert:1 equals:[[school objectForKey:@"persons_schools"] count] message:@"school's persons"];
    var mapping1 = [[person objectForKey:@"persons_schools"] objectAtIndex:0];
    var mapping2 = [[person objectForKey:@"persons_schools"] objectAtIndex:0];
    [self assert:mapping1 equals:mapping2];
    [self assert:@"persons_school" equals:[mapping1 objectForKey:@"entity"]];
}

- (void)testDeleteUpdatesRelationships {
    var person = persons[0];
    var school = schools[0];
    var mapping = [[person objectForKey:@"persons_schools"] objectAtIndex:0];

    [objectContext delete:mapping withRelationshipWithKey:@"persons_schools" between:person and:school];

    [self assert:[] equals:[person objectForKey:@"persons_schools"] message:@"person's schools"];
    [self assert:[] equals:[school objectForKey:@"persons_schools"] message:@"school's persons"];
}

- (void)testDeleteCreatesModifyRecord {
    var person = persons[0];
    var school = schools[0];
    var mapping = [[person objectForKey:@"persons_schools"] objectAtIndex:0];

    [objectContext delete:mapping withRelationshipWithKey:@"persons_schools" between:person and:school];

    var record = [[objectContext modifiedObjects] objectAtIndex:0];
    [self assert:mapping equals:[record object]];
    [self assert:1 equals:[[objectContext modifiedObjects] count]];
    [self assertNotNull:[record deleteDict] message:@"deletion marker"];
    [self assertNull:[record updateDict] message:@"update dict"];
    [self assertNull:[record insertDict] message:@"insert dict"];
    [self assertFalse:[objectContext isObjectRegistered:mapping] message:@"mapping registered"];
}

- (void)testRevertDeletion {
    var person = persons[0];
    var school = schools[0];
    var mapping = [[person objectForKey:@"persons_schools"] objectAtIndex:0];

    [objectContext delete:mapping withRelationshipWithKey:@"persons_schools" between:person and:school];
    [objectContext revert];

    [self assertTrue:[objectContext isObjectRegistered:mapping] message:@"mapping registered"];
    [self assertFalse:[objectContext hasChanges] message:@"has changes"];

    [self assertTrue:[[person objectForKey:@"persons_schools"] containsObject:mapping] message:@"person has mapping"];
    [self assertTrue:[[school objectForKey:@"persons_schools"] containsObject:mapping] message:@"school has mapping"];

    // todo: verify index
}

- (void)assert:(id)anObject notBound:(CPString)aBinding
{
    //TODO: move to category
    var bindingInfo = [anObject infoForBinding:aBinding];
    if (!bindingInfo) return;
    [self fail:@"expected no binding '" + aBinding + "' but found " + bindingInfo];
}

- (void)assert:(id)anObject bound:(CPString)aBinding toObject:(id)expectedObservedObject withKeyPath:(CPString)expectedObservedKeyPath
{
    //TODO: move to category
    var bindingInfo = [anObject infoForBinding:aBinding];
    [self assertNotNull:bindingInfo message:@"expected binding '" + aBinding + "' of " + anObject + " to " + expectedObservedObject];
    [self assert:expectedObservedKeyPath equals:[bindingInfo objectForKey:CPObservedKeyPathKey]];
    [self assert:expectedObservedObject same:[bindingInfo objectForKey:CPObservedObjectKey]];
}

- (void)assertThrows:(Function)zeroArgClosure name:(CPString)expectedName reason:(CPString)expectedReason
{
    //TODO: move to category
    var expected = nil;
    try {
        zeroArgClosure();
    } catch (anException) {
        expected = anException;
    }
    if (!expected) [self fail:@"didn't throw " + expectedName];
    [self assert:expectedName equals:[expected name]];
    [self assert:expectedReason equals:[expected reason]];
}

@end
