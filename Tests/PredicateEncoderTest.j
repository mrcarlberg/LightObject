@import "../LOJSONFormatSupport.j"
@import "OJTestCase+LOAdditions.j"

// TODO: test encode throws on subpred count != 1 for NOT compound

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
//objj_msgSend_decorate(objj_backtrace_decorator);

@implementation PredicateEncoderTest : OJTestCase {
}

- (void)testKeyPathExpression {
    var expr = [CPExpression expressionForKeyPath:@"some.path"];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"keyPath"];
    [self assert:json.value equals:@"some.path"];
}

- (void)testKeyPathExpressionThrowsOnNothing {
    [self assertThrows:function() { [[CPExpression expressionForKeyPath:undefined] LOJSONFormat]; } name:LOJSONUnsupportedExpressionValueException reason:@"Key path expression must not be undefined"];
    [self assertThrows:function() { [[CPExpression expressionForKeyPath:nil] LOJSONFormat]; } name:LOJSONUnsupportedExpressionValueException reason:@"Key path expression must not be null"];
    [self assertThrows:function() { [[CPExpression expressionForKeyPath:@""] LOJSONFormat]; } name:LOJSONUnsupportedExpressionValueException reason:@"Key path expression must not be empty"];
}

- (void)testConstantValueExpressionThrowsOnUndefined {
    [self assertThrows:function() { [[CPExpression expressionForConstantValue:undefined] LOJSONFormat]; } name:LOJSONUnsupportedExpressionValueException reason:@"Unsupported type 'undefined' for constant value expression"];
}

- (void)testNullConstantValueExpression {
    var expr = [CPExpression expressionForConstantValue:nil];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"null"];
    [self assert:json.value equals:null];
}

- (void)testStringConstantValueExpression {
    var expr = [CPExpression expressionForConstantValue:@"some string"];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"string"];
    [self assert:json.value equals:@"some string"];
}

- (void)testStringConstantValueExpressionWithEmptyString {
    var expr = [CPExpression expressionForConstantValue:@""];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"string"];
    [self assert:json.value equals:@""];
}

- (void)testNumberConstantValueExpression {
    var expr = [CPExpression expressionForConstantValue:3.13];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"number"];
    [self assert:json.value equals:3.13];
}

- (void)testNumberConstantValueExpressionWithZero {
    var expr = [CPExpression expressionForConstantValue:0];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"number"];
    [self assert:json.value equals:0];
}

- (void)testBooleanConstantValueExpression {
    var expr = [CPExpression expressionForConstantValue:true];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"bool"];
    [self assert:json.value equals:true];
}

- (void)testDateConstantValueExpression {
    var expr = [CPExpression expressionForConstantValue:[CPDate dateWithTimeIntervalSinceReferenceDate:1234.0]];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"datetime"];
    [self assert:json.value equals:1234.0];
}

- (void)testAggregateExpression {
    var expr = [CPExpression expressionForAggregate:[ [CPExpression expressionForConstantValue:1], [CPExpression expressionForConstantValue:@"two"] ]];
    var json = [expr LOJSONFormat];
    [self assert:@"array" equals:json.type];
    [self assertJSON:json.value equals:[{type:@"number",value:1},{type:@"string",value:@"two"}]];
}

- (void)testAggregateExpressionCoercesConstantValues {
    var expr = [CPExpression expressionForAggregate:[1, @"two"]];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"array"];
    [self assertJSON:json.value equals:[{type:@"number",value:1},{type:@"string",value:@"two"}]];
}

- (void)testArrayConstantValueExpressionHandledAsAggregate {
    var expr = [CPExpression expressionForConstantValue:[1, @"two"]];
    var json = [expr LOJSONFormat];
    [self assert:json.type equals:@"array"];
    [self assertJSON:json.value equals:[{type:@"number",value:1},{type:@"string",value:@"two"}]];
}

- (void)testAggregateExpressionThrowsOnUnknownType {
    var f = function() {
        var expr = [CPExpression expressionForAggregate:@[ [[CPObject alloc] init] ] ];
        [expr LOJSONFormat];
    };
    [self assertThrows:f name:LOJSONUnsupportedExpressionValueException reason:@"Unsupported value of aggregate expression: Unsupported type 'object' for constant value expression"];
}

- (void)testConstantValueExpressionThrowsOnUnknownType {
    var f = function() {
        var expr = [CPExpression expressionForConstantValue:[[CPObject alloc] init]];
        var json = [expr LOJSONFormat];
    }
    [self assertThrows:f name:LOJSONUnsupportedExpressionValueException reason:@"Unsupported type 'object' for constant value expression"];
}

- (void)testExpressionThrowsOnUnsupportedExpressionType {
    var f = function() {
        [[[CPExpression alloc] initWithExpressionType:-999] LOJSONFormat];
    }
    [self assertThrows:f name:LOJSONUnsupportedExpressionTypeException reason:@"Unsupported expression type '-999'"];
}

- (void)testComparisonPredicateWithConstantString {
    var predicate = [CPPredicate predicateWithFormat:@"k = 's'"];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json equals:{"o": "==", "l": "k", "lt": "keyPath", "r": "s", "rt": "string"}];
}

- (void)testComparisonPredicateWithConstantNumber {
    var predicate = [CPPredicate predicateWithFormat:@"k = 3.13"];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json equals:{"o": "==", "l": "k", "lt": "keyPath", "r": 3.13, "rt": "number"}];
}

- (void)testComparisonPredicateWithConstantBoolean {
    var predicate = [CPPredicate predicateWithFormat:@"k = true"];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json equals:{"o": "==", "l": "k", "lt": "keyPath", "r": true, "rt": "bool"}];
}

- (void)testComparisonPrediacteWithConstantDate {
    var predicate = [CPPredicate predicateWithFormat:@"k = %@", [CPDate dateWithTimeIntervalSinceReferenceDate:1234.0]];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json equals:{"o": "==", "l": "k", "lt": "keyPath", "r": 1234.0, "rt": "datetime"}];
}

- (void)testComparisonPrediacteWithConstantNull {
    var predicate = [CPPredicate predicateWithFormat:@"k = %@", null];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json matches:{o: "==", l: "k", lt: "keyPath", rt: "null"}];
    [self assertTrue:(json.r === null) message:@"right"];
}

- (void)testComparisonPredicateThrowsOnUnsupportedOperator {
    var f = function() {
        [[[CPComparisonPredicate alloc] initWithLeftExpression:nil rightExpression:nil modifier:0 type:-999 options:0] LOJSONFormat];
    }
    [self assertThrows:f name:LOJSONUnsupportedPredicateOperatorException reason:@"Unsupported predicate operator '-999'"];
}

- (void)testComparisonPredicateWithCaseInsensitiveLike {
    var predicate = [CPPredicate predicateWithFormat:@"k LIKE[c] 'name'"];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json equals:{"o": "like", "l": "k", "lt": "keyPath", "r": "name", "rt": "string", "c": true}];
}

- (void)testComparisonPredicateWithConstantValueInKeyPath {
    var predicate = [CPPredicate predicateWithFormat:@"'v' IN k"];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json equals:{o: @"in", l: @"v", lt: @"string", r: @"k", rt: @"keyPath"}];
}

- (void)testComparisonPredicateWithKeyPathInConstantValues {
    var predicate = [CPPredicate predicateWithFormat:@"k IN {1,2}"];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json matches:{o: @"in", l: @"k", lt: @"keyPath", rt: @"array"} message:"sans r"];
    [self assertJSON:json.r matches:[ {type:@"number",value:1}, {type:@"number",value:2} ]];
}

- (void)testComparisonPredicateWithKeyPathBetweenConstantValues {
    var predicate = [CPPredicate predicateWithFormat:@"k BETWEEN {1,2}"];
    var json = [predicate LOJSONFormat];
    [self assertJSON:json matches:{o: @"between", l: @"k", lt: @"keyPath", rt: @"array"} message:"sans r"];
    [self assertJSON:json.r matches:[ {type:@"number",value:1}, {type:@"number",value:2} ]];
}

- (void)testComparisonPredicateSupportedOperators {
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k = 's'"] LOJSONFormat] matches:{"o": "=="}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k != 's'"] LOJSONFormat] matches:{"o": "!="}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k < 's'"] LOJSONFormat] matches:{"o": "<"}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k > 's'"] LOJSONFormat] matches:{"o": ">"}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k <= 's'"] LOJSONFormat] matches:{"o": "<="}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k >= 's'"] LOJSONFormat] matches:{"o": ">="}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k LIKE 's'"] LOJSONFormat] matches:{"o": "like"}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"'s' IN k"] LOJSONFormat] matches:{o: @"in"}];
    [self assertJSON:[[CPPredicate predicateWithFormat:@"k BETWEEN {1,2}"] LOJSONFormat] matches:{o: @"between"}];
}

- (void)testCompoundPredicateAND {
    var json = [[CPPredicate predicateWithFormat:@"k = 's' AND k = 't'"] LOJSONFormat];
    [self assertJSON:json matches:{"o": "and"} message:"compound"];
    var preds = json.p;
    [self assert:2 equals:preds.length message:@"subpredicates"];
    [self assertJSON:preds[0] equals:{"o": "==", "l": "k", "r": "s", "lt": "keyPath", "rt": "string"} message:"first"];
    [self assertJSON:preds[1] equals:{"o": "==", "l": "k", "r": "t", "lt": "keyPath", "rt": "string"} message:"second"];
}

- (void)testCompoundPredicateOR {
    var json = [[CPPredicate predicateWithFormat:@"k = 's' OR k = 't'"] LOJSONFormat];
    [self assertJSON:json matches:{"o": "or"} message:"compound"];
    var preds = json.p;
    [self assert:2 equals:preds.length message:@"subpredicates"];
    [self assertJSON:preds[0] equals:{"o": "==", "l": "k", "r": "s", "lt": "keyPath", "rt": "string"} message:"first"];
    [self assertJSON:preds[1] equals:{"o": "==", "l": "k", "r": "t", "lt": "keyPath", "rt": "string"} message:"second"];
}

- (void)testCompoundPredicateNOT {
    var json = [[CPPredicate predicateWithFormat:@"NOT k = 's'"] LOJSONFormat];
    [self assertJSON:json matches:{"o": "not"} message:"compound"];
    var preds = json.p;
    [self assert:1 equals:preds.length message:@"subpredicates"];
    [self assertJSON:preds[0] equals:{"o": "==", "l": "k", "r": "s", "lt": "keyPath", "rt": "string"} message:"first"];
}

- (void)testCompoundPredicateThrowsOnUnsupportedOperator {
    var f = function() {
        [[[CPCompoundPredicate alloc] initWithType:-999 subpredicates:[]] LOJSONFormat];
    }
    [self assertThrows:f name:LOJSONUnsupportedPredicateOperatorException reason:@"Unsupported predicate operator '-999'"];
}

- (void)testCompoundPredicateWithSeveralSubpredicates {
    var json = [[CPPredicate predicateWithFormat:@"x = 'r' AND y = 's' AND z = 't'"] LOJSONFormat];
    [self assertJSON:json matches:{"o": "and"} message:"compound"];
    var preds = json.p;
    [self assert:3 equals:preds.length message:@"subpredicates"];
    [self assertJSON:preds[0] equals:{"o": "==", "l": "x", "r": "r", "lt": "keyPath", "rt": "string"} message:"first"];
    [self assertJSON:preds[1] equals:{"o": "==", "l": "y", "r": "s", "lt": "keyPath", "rt": "string"} message:"second"];
    [self assertJSON:preds[2] equals:{"o": "==", "l": "z", "r": "t", "lt": "keyPath", "rt": "string"} message:"third"];
}

- (void)testNestedPredicates {
    var topLevel = [[CPPredicate predicateWithFormat:@"x = 'r' AND (y = 's' OR (NOT z = 't' AND m != 'u'))"] LOJSONFormat];

    // top level AND: "x = 'r' AND (...)"
    [self assertJSON:topLevel matches:{"o": "and"} message:"level1"];
    [self assert:2 equals:topLevel.p.length message:@"level1 subpredicates"];
    [self assertJSON:topLevel.p[0] equals:{"o": "==", "l": "x", "r": "r", "lt": "keyPath", "rt": "string"} message:"level1 first"];

    // top level's second subpredicate is second level OR: "(y = 's' OR (...))"
    var secondLevel = topLevel.p[1];
    [self assertJSON:secondLevel matches:{"o": "or"} message:"level2"];
    [self assert:2 equals:secondLevel.p.length message:@"level2 subpredicates"];
    [self assertJSON:secondLevel.p[0] equals:{"o": "==", "l": "y", "r": "s", "lt": "keyPath", "rt": "string"} message:"level2 first"];

    // second level's second subpredicate is third level AND: "(NOT z = 't' AND m != 'u')"
    var thirdLevel = secondLevel.p[1];
    [self assertJSON:thirdLevel matches:{"o": "and"} message:"level3"];
    [self assert:2 equals:thirdLevel.p.length message:@"level3 subpredicates"];
    [self assertJSON:thirdLevel.p[1] equals:{"o": "!=", "l": "m", "r": "u", "lt": "keyPath", "rt": "string"} message:"level3 second"];

    // third level's first subpredicate is fourth level NOT: "NOT z = 't'"
    var fourthLevel = thirdLevel.p[0];
    [self assertJSON:fourthLevel matches:{"o": "not"} message:"level4"];
    [self assert:1 equals:fourthLevel.p.length message:@"level4 subpredicates"];
    [self assertJSON:fourthLevel.p[0] equals:{"o": "==", "l": "z", "r": "t", "lt": "keyPath", "rt": "string"} message:"level4 first"];
}

@end
