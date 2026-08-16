gap> LoadPackage("json", false);;
gap> test_parse := function(str, res)
> local gapstr, gapstream, s;
> gapstr := JsonStringToGap(str);
> s := InputTextString(str);
> gapstream := JsonStreamToGap(s);
> CloseStream(s);
> if res <> gapstr or res <> gapstream then
>  Print("Failed: ",[str,res]," produced ", gapstr, " and ", gapstream, "\n");
> fi;
> end;;
gap> test_parse("1",1);
gap> test_parse(" 1 ",1);
gap> test_parse("1.0",1.);
gap> test_parse("1e5",100000);
gap> test_parse("1.0e5",100000.);
gap> test_parse("1.0e-5",1.e-05);
gap> test_parse("1e-5",1.e-05);
gap> test_parse("0e0", 0);
gap> test_parse("0e+0", 0);
gap> test_parse("0e-0", 0.);
gap> test_parse("0e+1", 0);
gap> test_parse("0e-1", 0.);
gap> test_parse("1e+1", 10);
gap> test_parse("1e1", 10);
gap> test_parse("1e-1", .1);
gap> test_parse("1e+0", 1);
gap> test_parse("1e-0", 1.);
gap> test_parse("true",true);
gap> test_parse("false",false);
gap> test_parse("null",fail);
gap> test_parse("\"abc\"","abc");
gap> test_parse("\"abc\\\\\"","abc\\");
gap> test_parse("\"\"","");
gap> test_parse("[1,2,3]",[ 1, 2, 3 ]);
gap> test_parse("[]",[  ]);
gap> test_parse("[[[]]]",[[[]]]);
gap> test_parse("[1,[2,[3]]]",[ 1, [ 2, [ 3 ] ] ]);
gap> test_parse("{}",rec(  ));
gap> test_parse("{ \"a\": 1}",rec( a := 1 ));
gap> test_parse("{ \"a\" : 1}",rec( a := 1 ));
gap> test_parse("{\"a\": 1}",rec( a := 1 ));
gap> test_parse("{ \"a\": [1,2,3]}",rec( a := [ 1, 2, 3 ] ));
gap> JsonStringToGap(" 1 2 3");
Error, Unexpected non-whitespace after JSON value at byte 4
gap> JsonStringToGap("1 1");
Error, Unexpected non-whitespace after JSON value at byte 3
gap> JsonStringToGap("{}{}");
Error, Unexpected non-whitespace after JSON value at byte 3
gap> JsonStringToGap("e1");
Error, Invalid JSON syntax at line 1
gap> JsonStringToGap("e");
Error, Invalid JSON syntax at line 1
gap> JsonStringToGap("[-]");
Error, Invalid JSON syntax at line 1
gap> JsonStringToGap("[1e]");
Error, Invalid JSON syntax at line 1
gap> JsonStringToGap("[1e+]");
Error, Invalid JSON syntax at line 1
gap> JsonStringToGap("2x");
Error, Unexpected non-whitespace after JSON value at byte 2
gap> JsonStringToGap("[1,2]x");
Error, Unexpected non-whitespace after JSON value at byte 6
gap> JsonStringToGap("{}x");
Error, Unexpected non-whitespace after JSON value at byte 3
gap> test_parse("01", 1);
gap> test_parse("1.", 1.);
gap> test_parse("-.5", -.5);
gap> test_parse("2.e3", 2000.);
gap> utf8 := bytes -> Concatenation("\"", List(bytes, CHAR_INT), "\"");;
gap> List(JsonStringToGap(utf8([240,157,132,158])), IntChar);
[ 240, 157, 132, 158 ]
gap> JsonStringToGap(utf8([128]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(utf8([192,175]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(utf8([226,130]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(utf8([237,160,128]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(utf8([244,144,128,128]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(utf8([245,128,128,128]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(utf8([255]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(Concatenation("1", [CHAR_INT(0)], "2"));
Error, Unexpected non-whitespace after JSON value at byte 2
gap> nested := n -> Concatenation(Concatenation(ListWithIdenticalEntries(n, "[")), "0", Concatenation(ListWithIdenticalEntries(n, "]")));;
gap> IsList(JsonStringToGap(nested(1024)));
true
gap> JsonStringToGap(nested(1025));
Error, JSON input nested more than 1024 levels deep
gap> validUtf8 := [[194,128], [223,191], [224,160,128], [237,159,191], [238,128,128], [239,191,191], [240,144,128,128], [244,143,191,191]];;
gap> ForAll(validUtf8, bytes -> List(JsonStringToGap(utf8(bytes)), IntChar) = bytes);
true
gap> JsonStringToGap(utf8([224,128,128]));
Error, invalid UTF-8 in JSON string
gap> JsonStringToGap(utf8([240,128,128,128]));
Error, invalid UTF-8 in JSON string

# The pure GAP fallback has the same deliberate extensions and hard limits.
gap> _JSON_PureStringToGap("01");
1
gap> IsNaN(_JSON_PureStringToGap("NaN"));
true
gap> _JSON_PureStringToGap(utf8([192,175]));
Error, invalid UTF-8 in JSON string
gap> _JSON_PureStringToGap(Concatenation("1", [CHAR_INT(0)], "2"));
Error, Unexpected non-whitespace after JSON value at byte 2
gap> IsList(_JSON_PureStringToGap(nested(1024)));
true
gap> _JSON_PureStringToGap(nested(1025));
Error, JSON input nested more than 1024 levels deep
gap> pureStream := InputTextString("[1][2]");;
gap> [ _JSON_PureStreamToGap(pureStream), _JSON_PureStreamToGap(pureStream) ];
[ [ 1 ], [ 2 ] ]
gap> CloseStream(pureStream);
