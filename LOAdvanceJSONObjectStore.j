/*
 * LOAdvanceJSONObjectStore.j
 *
 * Created by Martin Carlberg on Januaray 28, 2016.
 * Copyright 2016, All rights reserved.
 */


@import "LOSimpleJSONObjectStore.j"
@import "md5.js"

/*!
    This object store will handle advanced qualifiers by 
*/
@implementation LOAdvanceJSONObjectStore : LOSimpleJSONObjectStore

/*!
    Returns a request with an url for requesting objects. Will add qualifier to url or header.
 */
- (CPURLRequest)urlRequestForRequestObjectWithURL:(CPURL)url andQualifier:(CPPredicate)aQualifier {
    var advancedQualifierString = nil;
    if (aQualifier) {
        var qualifierString = [self buildRequestPathForQualifier:aQualifier];
        if (qualifierString) {
            url = url + @"/" + qualifierString;
        } else {
            qualifierString = boplib.string.UTF16ToUTF8(JSON.stringify([aQualifier LOJSONFormat]));
            advancedQualifierString = [[CPData dataWithRawString:qualifierString] base64];
            url = url + @"/X-LO-Advanced-Qualifier=" + md5lib.md5(qualifierString);
        }
    }
    var request = [CPURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    if (advancedQualifierString) {
        [request setValue:advancedQualifierString forHTTPHeaderField:@"X-LO-Advanced-Qualifier"];
    }

    return request;
}

- (CPString)buildRequestPathForQualifier:(CPPredicate)aQualifier {
    if (!aQualifier) return nil;

    var qualiferAndItems = [aQualifier];
    if ([aQualifier isKindOfClass:[CPCompoundPredicate class]]) {
        if ([aQualifier compoundPredicateType] != CPAndPredicateType) return nil;
        qualiferAndItems = [aQualifier subpredicates];
    }

    var qualiferAndItemSize = [qualiferAndItems count];
    for (var i = 0; i < qualiferAndItemSize; i++) {
        var eachQualifier = [qualiferAndItems objectAtIndex:i];
        if (![eachQualifier isKindOfClass:[CPComparisonPredicate class]]) return nil;
        if ([eachQualifier predicateOperatorType] != CPEqualToPredicateOperatorType) return nil;
        if ([[eachQualifier leftExpression] expressionType] != CPKeyPathExpressionType) return nil;
        if ([[eachQualifier rightExpression] expressionType] != CPConstantValueExpressionType) return nil;
        if (([[eachQualifier rightExpression] expressionType] === CPConstantValueExpressionType) &&
            (![[eachQualifier rightExpression] constantValue])) return nil;
        if (([[eachQualifier rightExpression] expressionType] === CPConstantValueExpressionType) &&
            ((![[[eachQualifier rightExpression] constantValue] isKindOfClass:[CPString class]]) &&
            (![[[eachQualifier rightExpression] constantValue] isKindOfClass:[CPNumber class]]))
            ) return nil;
    }

    // We've now ensured that each predicate is a simple 'keyPath equals constant value' predicate
    var parts = [];
    for (var i = 0; i < qualiferAndItemSize; i++) {
        var eachQualifier = [qualiferAndItems objectAtIndex:i];
        var left = [[eachQualifier leftExpression] description];
        var right = [[[eachQualifier rightExpression] constantValue] description];
        // todo: percent encode whitespace
        [parts addObject:[self escapeStringForQualifier:left] + @"=" + [self escapeStringForQualifier:right]];
    }

    if ([parts count] == 0) return nil;
    return parts.join(@"/");
}

- (CPString)escapeStringForQualifier:(CPString)aString {
    var result = [aString stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
    result = [result stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
    return result;
}

+ (CPString)UTF16ToUTF8:(CPString)source {
    return UTF16ToUTF8(source);
}

@end


/*
* Adaption to javascript of UTF16ToUTF8 from ConvertUTF.[ch] by Unicode, Inc.
* Originalcopyright follows.
*/

/*
* Copyright 2001-2004 Unicode, Inc.
*
* Disclaimer
*
* This source code is provided as is by Unicode, Inc. No claims are
* made as to fitness for any particular purpose. No warranties of any
* kind are expressed or implied. The recipient agrees to determine
* applicability of information provided. If this file has been
* purchased on magnetic or optical media from Unicode, Inc., the
* sole remedy for any claim will be exchange of defective media
* within 90 days of receipt.
*
* Limitations on Rights to Redistribute This Code
*
* Unicode, Inc. hereby grants the right to freely use the information
* supplied in this file in the creation of products supporting the
* Unicode Standard, and to make copies of this file in any form
* for internal or external distribution as long as this notice
* remains attached.
*/

/* ---------------------------------------------------------------------

   Conversions between UTF32, UTF-16, and UTF-8. Source code file.
   Author: Mark E. Davis, 1994.
   Rev History: Rick McGowan, fixes & updates May 2001.
   Sept 2001: fixed const & error conditions per
   mods suggested by S. Parent & A. Lillich.
   June 2002: Tim Dodd added detection and handling of incomplete
   source sequences, enhanced error detection, added casts
   to eliminate compiler warnings.
   July 2003: slight mods to back out aggressive FFFE detection.
   Jan 2004: updated switches in from-UTF8 conversions.
   Oct 2004: updated to use UNI_MAX_LEGAL_UTF32 in UTF-32 conversions.

   See the header file "ConvertUTF.h" for complete documentation.

------------------------------------------------------------------------ */
var UTF16ToUTF8 = function(source) {
    var constants = {
        SURROGATE_HIGH_START: 0xD800,
        SURROGATE_HIGH_END:   0xDBFF,
        SURROGATE_LOW_START:  0xDC00,
        SURROGATE_LOW_END:    0xDFFF,
        REPLACEMENT_CHAR:     0xFFFD,
        firstByteMark:        [0x00, 0x00, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC]
    };

    var target = "";
    var bytesToWrite = 0;
    for (var i=0; i<source.length; i++) {
        var c = source.charCodeAt(i);

        if (c >= constants.SURROGATE_HIGH_START && c <= constants.SURROGATE_HIGH_END) {
            i++;
            if (i < source.length) {
                var c2 = source.charCodeAt(i);
                if (c2 >= constants.SURROGATE_LOW_START && c2 <= constants.SURROGATE_LOW_END) {
                    c = ((c - constants.SURROGATE_HIGH_START) << 10) + (c2 - constants.SURROGATE_LOW_START) + 0x10000;
                } else {
                    // illegal second surrogate char
                    return null;
                }
            } else {
                // missing second surrogate in pair
                return null;
            }
        } else if (c >= constants.SURROGATE_LOW_START && c <= constants.SURROGATE_LOW_END) {
            // stray surrogate
            return null;
        }

        if (c < 0x80) {
            bytesToWrite = 1;
        } else if (c < 0x800) {
            bytesToWrite = 2;
        } else if (c < 0x10000) {
            bytesToWrite = 3;
        } else if (c < 0x110000) {
            bytesToWrite = 4;
        /*
        Can't represent chars >= 0x110000 with surrogates.
        } else {
            bytesToWrite = 3;
            c = constants.REPLACEMENT_CHAR;
        */
        }

        enc = [];
        switch (bytesToWrite) { /* note: everything falls through. */
            case 4: enc.unshift(String.fromCharCode((c | 0x80) & 0xBF)); c >>= 6;
            case 3: enc.unshift(String.fromCharCode((c | 0x80) & 0xBF)); c >>= 6;
            case 2: enc.unshift(String.fromCharCode((c | 0x80) & 0xBF)); c >>= 6;
            case 1: enc.unshift(String.fromCharCode( c | constants.firstByteMark[bytesToWrite]));
        }
        target += enc.join("");
    }
    return target;
}
