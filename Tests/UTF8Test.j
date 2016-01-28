@import "../LOAdvanceJSONObjectStore"

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
//objj_msgSend_decorate(objj_backtrace_decorator);

// see http://mathiasbynens.be/notes/javascript-encoding for a discussion of how unicode is treated in javascript.
// In short: in javascript a string is a sequence of 16 bit characters, just like in Cocoa. A browser will most likely produce valid UTF-16 character sequences, including surrogate pairs to represent unicode characters outside of the BMP.

@implementation UTF8Test : OJTestCase {
}

- (void)testUTF16ToUTF8HandlesASCII {
    [self assertChars:"\u0041" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\u0041"]];
    [self assertChars:"\u0000" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\u0000"]];
    [self assertChars:"\u007f" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\u007f"]];
}

- (void)testUTF16ToUTF8HandlesTwoBytes {
    [self assertChars:"\u00c2\u0080" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\u0080"]];
    [self assertChars:"\u00df\u00bf" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\u07ff"]];
    
}

- (void)testUTF16ToUTF8HandlesThreeBytes {
    [self assertChars:"\u00e0\u00a0\u0080" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\u0800"]];
    [self assertChars:"\u00ed\u009f\u00bf" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\ud7ff"]];
    [self assertChars:"\u00ee\u0080\u0080" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\ue000"]];
}

- (void)testUTF16ToUTF8HandlesValidSurrogatePairs {
    [self assertChars:"\u00f0\u0090\u0080\u0080" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\ud800\udc00"]];
    [self assertChars:"\u00f0\u0090\u008f\u00bf" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\ud800\udfff"]];
    [self assertChars:"\u00f4\u008f\u00b0\u0080" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\udbff\udc00"]];
    [self assertChars:"\u00f4\u008f\u00bf\u00bf" equals: [LOAdvanceJSONObjectStore UTF16ToUTF8:"\udbff\udfff"]];
}

- (void)testUTF16ToUTF8HandlesStraySurrogateMarkers {
    var markers = ["\ud800", "\udbff", "\udc00", "\udfff"];
    for (var i=0; i<markers.length; i++) {
        var marker = markers[i];
        [self assertNull:[LOAdvanceJSONObjectStore UTF16ToUTF8:marker] message:"marker " + i];
        [self assertNull:[LOAdvanceJSONObjectStore UTF16ToUTF8:marker + "\u0041"] message:"marker " + i + " head"];
        [self assertNull:[LOAdvanceJSONObjectStore UTF16ToUTF8:"\u0041" + marker] message:"marker " + i + " tail"];
        [self assertNull:[LOAdvanceJSONObjectStore UTF16ToUTF8:"\u0041" + marker + "\u0041"] message:"marker " + i + " middle"];
    }
}

- (void)testUTF16ToUTF8HandlesInvalidCodePoints {
    // Maybe handle invalid code points like 0xffff, fffe and the likes?
}

- (void)assertChars:(CPString)expected equals:(CPString)actual {
    var tohex = function(s) {
        var hex_chars = "0123456789abcdef".split("");
        var out = [];
        for (var i=0; i<s.length; i++) {
            var c = s.charCodeAt(i);
            out.push(
                hex_chars[(c >> 12) & 0x0f]
                + hex_chars[(c >>  8) & 0x0f]
                + hex_chars[(c >>  4) & 0x0f]
                + hex_chars[(c)       & 0x0f]);
        }
        return "<" + out.join(" ") + ">";
    };
    [self assert:tohex(expected) equals:tohex(actual)];
}

@end
