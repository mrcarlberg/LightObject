@import "../Resources/md5.js"

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
//objj_msgSend_decorate(objj_backtrace_decorator);

@implementation MD5Test : OJTestCase {
}

- (void)testEmptyString {
    [self assert:"d41d8cd98f00b204e9800998ecf8427e" equals:md5lib.md5("")];
}

- (void)testHelloString {
    [self assert:"b1946ac92492d2347c6235b4d2611184" equals:md5lib.md5("hello\n")];
}

- (void)testBase64Characters {
    [self assert:"7845f7eade89338adabfef89bd6e9a5b" equals:md5lib.md5("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")];
}

- (void)testIsntAwareOfEncoding {
    // The md5 digest of the character sequence '\0xC3\xA4' is 8419b71c87a225a2c70b50486fbee545 in hex.
    // Note that there's no such thing as 8 bit chars in javascript and md5lib seem to work with
    // the full 16-bit chars. I'm not sure how the algorithm handles this, but to 'emulate' md5 on
    // 8 bit chars one has to make sure all JS chars are in [\u0000,\u00ff].
    [self assert:md5lib.md5('\u00c3\u00a4') equals:md5lib.md5('\xc3\xa4') message:@"u and x shortcuts"];
    [self assert:"8419b71c87a225a2c70b50486fbee545" equals:md5lib.md5('\xc3\xa4') message:@"'fake' UTF-8"];
    [self assert:"c9aefcd41ec07161fddda02b15f05d5c" equals:md5lib.md5('\uc3a4') message:@"'extended' char"]; // is it possible to achieve this digest using normal 8 bit chars?
}

@end
