
@implementation OJTestCase (LOAdditions)

- (void)assertSomething:(id)object {
    [self assertSomething:object message:nil];
}

- (void)assertSomething:(id)object message:(CPString)aMessage {
    if (object === null || object === undefined)
        [self fail:(aMessage ? aMessage + " " : "") + @"expected something but got " + object];
}

- (void)assertJSON:(JSON)actual equals:(JSON)expected {
    [self assertJSON:actual equals:expected message:nil];
}

- (void)assertJSON:(JSON)actual equals:(JSON)expected message:(CPString)aMessage {
    [self assertJSON:actual matches:expected message:aMessage];
    var extraneousKeys = [CPArray array];
    for (var key in actual) {
        if (expected[key]) continue;
        [extraneousKeys addObject:key];
    }
    if ([extraneousKeys count] > 0) {
        var msgPrefix = "";
        if (aMessage) msgPrefix = aMessage + " ";
        [self fail:msgPrefix + @"Unexpected keys " + extraneousKeys];
    }
}

- (void)assertJSON:(JSON)actual matches:(JSON)expected {
    [self assertJSON:actual matches:expected message:nil];
}

- (void)assertJSON:(JSON)actual matches:(JSON)expected message:(CPString)aMessage {
    var msgPrefix = "";
    if (aMessage) msgPrefix = aMessage + " ";

    for (var expectedKey in expected) {
        [self assertTrue:actual[expectedKey] message:msgPrefix + "missing key '" + expectedKey + "'"];
        var expectedValue = expected[expectedKey];
        var actualValue = actual[expectedKey];

        // I hate this, the argument order is backwards. The method now reads
        //    "assert that <expected value> equals <actual value>",
        // but that doesn't make sense. I want to say
        //    "assert that <actual value> equals <expected value>".
        if (expectedValue.isa && actualValue.isa)
            [self assert:expectedValue equals:actualValue message:msgPrefix + expectedKey];

        else if (expectedValue.isa || actualValue.isa)
            [self fail:msgPrefix + expectedKey + " expected " + stringValueOf(expectedValue) + " but got " + stringValueOf(actualValue)];

        else if (typeof expectedValue == "object" && typeof actualValue == "object")
            [self assertJSON:actualValue matches:expectedValue message:msgPrefix + expectedKey];

        else
            [self assert:expectedValue same:actualValue message:msgPrefix + expectedKey]
    }
}

function stringValueOf(obj) {
    if (obj && obj.isa)
        var result = [obj description];
    else
        var result = obj;

    return result;
}

- (void)assertObject:(id)actual matchesKeyValues:(JSON)expected {
    [self assertObject:actual matchesKeyValues:expected message:nil];
}

- (void)assertObject:(id)actual matchesKeyValues:(JSON)expected message:(CPString)aMessage {
    var msgPrefix = "";
    if (aMessage) msgPrefix = aMessage + " ";

    for (var expectedKey in expected) {
        var expectedValue = expected[expectedKey];
        var actualValue = [actual valueForKey:expectedKey];
        [self assert:expectedValue equals:actualValue message:msgPrefix + expectedKey];
    }
}

- (void)assertObjects:(CPArray)actualObjects matchesKeyValues:(CPArray)expectedKeyValues {
    [self assertObjects:actualObjects matchesKeyValues:expectedKeyValues message:nil];
}

- (void)assertObjects:(CPArray)actualObjects matchesKeyValues:(CPArray)expectedKeyValues message:(CPString)aMessage {
    var msgPrefix = "";
    if (aMessage) msgPrefix = aMessage + " ";

    [self assert:[expectedKeyValues count] equals:[actualObjects count] message:msgPrefix + "count"];
    for (var i=0; i<[actualObjects count]; i++) {
        var actual = [actualObjects objectAtIndex:i];
        var expected = [expectedKeyValues objectAtIndex:i];
        [self assertObject:actual matchesKeyValues:expected message:msgPrefix + "index " + i];
    }
}

- (void)assertThrows:(Function)zeroArgClosure name:(CPString)expectedName reason:(CPString)expectedReason {
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
