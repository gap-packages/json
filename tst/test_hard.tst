gap> LoadPackage("json", false);;
gap> dir := DirectoriesPackageLibrary( "json", "tst" );;
gap> f := Filename(dir, "UTF-8-test.txt");;
gap> s := StringFile(f);;
gap> json := GapToJsonString(s);;
gap> fout := Filename(dir, "UTF-8-test.txt.clean");;
gap> sout := StringFile(fout);;
gap> json = sout;
true

# A truncated multi-byte sequence at the very end of a string used to make
# getUTF8Char read past the end of the buffer. Like any other malformed
# sequence, its bytes are now treated as Latin-1 and re-encoded.
gap> List(GapToJsonString([ CHAR_INT(200) ]), IntChar);
[ 34, 195, 136, 34 ]
gap> List(GapToJsonString([ CHAR_INT(226), CHAR_INT(130) ]), IntChar);
[ 34, 195, 162, 194, 130, 34 ]
gap> ForAll([0..255], b -> IsString(GapToJsonString([ CHAR_INT(b) ])));
true

# Invalid UTF-8 bytes are interpreted individually as Latin-1 rather than
# being mistaken for overlong, surrogate, or out-of-range encodings.
gap> List(GapToJsonString(List([192,175], CHAR_INT)), IntChar);
[ 34, 195, 128, 194, 175, 34 ]
gap> List(GapToJsonString(List([237,160,128], CHAR_INT)), IntChar);
[ 34, 195, 173, 194, 160, 194, 128, 34 ]
gap> List(GapToJsonString(List([244,144,128,128], CHAR_INT)), IntChar);
[ 34, 195, 180, 194, 144, 194, 128, 194, 128, 34 ]
gap> List(GapToJsonString(List([255], CHAR_INT)), IntChar);
[ 34, 195, 191, 34 ]
gap> validUtf8 := [[194,128], [223,191], [224,160,128], [237,159,191], [238,128,128], [239,191,191], [240,144,128,128], [244,143,191,191]];;
gap> ForAll(validUtf8, bytes -> List(GapToJsonString(List(bytes, CHAR_INT)), IntChar) = Concatenation([34], bytes, [34]));
true

# The pure GAP and kernel string escapers must implement the same byte policy.
gap> not _JSON_KERNEL_AVAILABLE or ForAll([0..255], b -> _JSON_PureEscapeString([CHAR_INT(b)]) = JSON_ESCAPE_STRING([CHAR_INT(b)]));
true
gap> not _JSON_KERNEL_AVAILABLE or _JSON_PureEscapeString(s) = JSON_ESCAPE_STRING(s);
true
