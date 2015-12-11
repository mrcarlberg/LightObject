/*
 * LOContextValueTransformer.j
 *
 * Created by Martin Carlberg on December 7, 2015.
 * Copyright 2015, All rights reserved.
 */

/*!
 * To use a transformer with context create a subclass of CPValueTransformer that conforms to this protocol.
 * The context is a Javascript object with property 'object' containing the owner object for the value.
 * The property 'attributeKey' contains the owner objects attribute key to the value.
 */
@protocol LOContextValueTransformer

- (id)transformedValue:(id)aValue withContext:(id)context;
- (id)reverseTransformedValue:(id)aValue withContext:(id)context;

@end