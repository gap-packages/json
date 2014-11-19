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
gap> test_parse("{ \"a\": [1,2,3]}",rec( a := [ 1, 2, 3 ] ));
gap> JsonStringToGap(" 1 2 3");
Error, Failed to parse end of string: '2 3'
gap> JsonStringToGap("1 1");
Error, Failed to parse end of string: '1'
gap> JsonStringToGap("{}{}");
Error, Failed to parse end of string: '{}'
gap> JsonStringToGap("e1");
Error, syntax error at line 1 near: e1
gap> JsonStringToGap("e");
Error, syntax error at line 1 near: e