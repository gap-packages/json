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
