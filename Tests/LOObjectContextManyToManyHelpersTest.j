@import "../LightObject.j"

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
objj_msgSend_decorate(objj_backtrace_decorator);


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

    [objectStore addFixtureObject:{@"entity": @"person", @"key": 2, @"name": @"Achilles"}];
    [objectStore addFixtureObject:{@"entity": @"person", @"key": 3, @"name": @"Penelope"}];
    [objectStore addFixtureObject:{@"entity": @"school", @"key": 200, @"name": @"University of Sparta"}];
    [objectStore addFixtureObject:{@"entity": @"school", @"key": 300, @"name": @"Troy Public School"}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 2000, @"person_fk": 2, @"school_fk": 200}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 2001, @"person_fk": 2, @"school_fk": 300}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 3000, @"person_fk": 3, @"school_fk": 300}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 3001, @"person_fk": 3, @"school_fk": 200}];

    [objectStore addFixtureRelationshipKey:@"persons_schools" forEntity:@"person"];
    [objectStore addFixtureRelationshipKey:@"persons_schools" forEntity:@"school"];
    [self requestAllObjectsForEntity:@"person"];
    [self requestAllObjectsForEntity:@"school"];
    [objectStore addFakeArrayFaultsForObjects:persons inObjectContext:objectContext];
    [objectStore addFakeArrayFaultsForObjects:schools inObjectContext:objectContext];
}

// Delegate method for LOObjectContext
- (id) newObjectForType:(CPString) aType {
    var x = [[ShallowDescriptionDictionary alloc] init];
    [x setObject:aType forKey:@"entity"];
    return x;
    //return [ShallowDescriptionDictionary dictionaryWithObject:aType forKey:@"entity"];
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
    [self assert:3 equals:[persons count] message:@"persons"];
    [self assert:3 equals:[schools count] message:@"schools"];
    // trigger faults
    var person = persons[0];
    var school = schools[0];
    [self assert:1 equals:[[person objectForKey:@"persons_schools"] count] message:@"person's schools"];
    [self assert:1 equals:[[school objectForKey:@"persons_schools"] count] message:@"school's persons"];
    var mapping1 = [[person objectForKey:@"persons_schools"] objectAtIndex:0];
    var mapping2 = [[school objectForKey:@"persons_schools"] objectAtIndex:0];
    [self assert:mapping1 equals:mapping2];
    [self assert:@"persons_school" equals:[mapping1 objectForKey:@"entity"]];
    [self assert:person equals:[mapping1 valueForKey:@"person"]];
    [self assert:school equals:[mapping1 valueForKey:@"school"]];
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
    // achilles => sparta, troy
    // penelope => troy, sparta
    var achilles = persons[1];
    var penelope = persons[2];
    
    var sparta = schools[1];
    var troy   = schools[2];

    var mappingAchillesSparta = [[achilles objectForKey:@"persons_schools"] objectAtIndex:0];
    var mappingPenelopeSparta = [[penelope objectForKey:@"persons_schools"] objectAtIndex:1];

    // verify setup (move this someplace else)
    [self assertNotNull:mappingAchillesSparta];
    [self assertNotNull:mappingPenelopeSparta];
    [self assert:achilles equals:[mappingAchillesSparta valueForKey:@"person"]];
    [self assert:sparta equals:[mappingAchillesSparta valueForKey:@"school"]];
    [self assert:penelope equals:[mappingPenelopeSparta valueForKey:@"person"]];
    [self assert:sparta equals:[mappingPenelopeSparta valueForKey:@"school"]];
    
    [objectContext delete:mappingAchillesSparta withRelationshipWithKey:@"persons_schools" between:achilles and:sparta];
    [objectContext delete:mappingPenelopeSparta withRelationshipWithKey:@"persons_schools" between:penelope and:sparta];
    [objectContext revert];

    [self assertTrue:[objectContext isObjectRegistered:mappingAchillesSparta] message:@"Achilles mapping registered"];
    [self assertTrue:[objectContext isObjectRegistered:mappingPenelopeSparta] message:@"Penelope mapping registered"];
    [self assertFalse:[objectContext hasChanges] message:@"has changes"];

    [self assertTrue:[[achilles objectForKey:@"persons_schools"] containsObject:mappingAchillesSparta] message:@"Achilles has mapping"];
    //[self assertTrue:[[penelope objectForKey:@"persons_schools"] containsObject:mappingPenelopeSparta] message:@"Penelope has mapping"];
    //[self assertTrue:[[sparta objectForKey:@"persons_schools"] containsObject:mappingAchillesSparta] message:@"school has Achilles mapping"];
    //[self assertTrue:[[sparta objectForKey:@"persons_schools"] containsObject:mappingPenelopeSparta] message:@"school has Penelope mapping"];

    //[self assert:0 equals:[[achilles objectForKey:@"persons_schools"] indexOfObject:mappingAchillesSparta] message:@"achilles sparta"];
    //[self assert:1 equals:[[penelope objectForKey:@"persons_schools"] indexOfObject:mappingPenelopeSparta] message:@"penelope sparta"];
    //[self assert:0 equals:[[sparta objectForKey:@"persons_schools"] indexOfObject:mappingAchillesSparta] message:@"sparta achilles"];
    //[self assert:1 equals:[[sparta objectForKey:@"persons_schools"] indexOfObject:mappingPenelopeSparta] message:@"sparta penelope"];
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
