gap> LoadPackage("json", false);;
gap> JsonToGap("1");
1
gap> JsonToGap("1.0");
1.
gap> JsonToGap("1e5");
100000
gap> JsonToGap("1.0e5");
100000.
gap> JsonToGap("1.0e-5");
1.e-05
gap> JsonToGap("1e-5");
1.e-05
gap> JsonToGap("true");
true
gap> JsonToGap("false");
false
gap> JsonToGap("null");
fail
gap> JsonToGap("\"abc\"");
"abc"
gap> JsonToGap("\"abc\\\\\"");
"abc\\"
gap> JsonToGap("\"\"");
""
gap> JsonToGap("[1,2,3]");
[ 1, 2, 3 ]
gap> JsonToGap("[]");
[  ]
gap> JsonToGap("[[[]]]");
[ [ [  ] ] ]
gap> JsonToGap("[1,[2,[3]]]");
[ 1, [ 2, [ 3 ] ] ]
gap> JsonToGap("{}");
rec(  )
gap> JsonToGap("{ \"a\": 1}");
rec( a := 1 )
gap> JsonToGap("{ \"a\": [1,2,3]}");
rec( a := [ 1, 2, 3 ] )