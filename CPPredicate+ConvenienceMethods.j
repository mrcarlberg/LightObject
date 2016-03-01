/*
 * CPPredicate+ConvenienceMethods.j
 *
 * Created by Martin Carlberg on Januaray 28, 2016.
 * Copyright 2016, All rights reserved.
 */

@import <Foundation/CPPredicate.j>

@implementation CPPredicate (PredicateConvenienceMethods)

+ (CPPredicate)keyPath:(CPString)aKeyPath equalsConstantValue:(CPObject)aValue {
    return [CPPredicate keyPath:aKeyPath comparedToConstantValue:aValue operatorType:CPEqualToPredicateOperatorType];
}

+ (CPPredicate)keyPath:(CPString)aKeyPath notEqualsConstantValue:(CPObject)aValue {
    return [CPPredicate keyPath:aKeyPath comparedToConstantValue:aValue operatorType:CPNotEqualToPredicateOperatorType];
}

+ (CPPredicate)constantValue:(CPString)inValue inKeyPath:(CPString)aKeyPath {
    return [CPComparisonPredicate predicateWithLeftExpression:[CPExpression expressionForConstantValue:inValue]
                                              rightExpression:[CPExpression expressionForKeyPath:aKeyPath]
                                                     modifier:CPDirectPredicateModifier
                                                         type:CPInPredicateOperatorType
                                                      options:0];
}

+ (CPPredicate)keyPath:(CPString)aKeyPath inConstantValues:(CPArray)inValues {
    return [CPComparisonPredicate predicateWithLeftExpression:[CPExpression expressionForKeyPath:aKeyPath]
                                              rightExpression:[CPExpression expressionForConstantValue:inValues]
                                                     modifier:CPDirectPredicateModifier
                                                         type:CPInPredicateOperatorType
                                                      options:0];
}

+ (CPPredicate)keyPath:(CPString)aKeyPath notInConstantValues:(CPArray)inValues {
    return [CPCompoundPredicate notPredicateWithSubpredicate:[self keyPath:aKeyPath inConstantValues:inValues]];
}

+ (CPPredicate)keyPath:(CPString)aKeyPath comparedToConstantValue:(CPObject)aValue operatorType:(CPPredicateOperatorType)aType {
    return [CPComparisonPredicate predicateWithLeftExpression:[CPExpression expressionForKeyPath:aKeyPath]
                                              rightExpression:[CPExpression expressionForConstantValue:aValue]
                                                     modifier:CPDirectPredicateModifier
                                                         type:aType
                                                      options:0];
}

@end
