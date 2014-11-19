gap> LoadPackage("json", false);;
gap> test_cycle := function(i)
> local jsonstr, res, jsonstream, s, streamres;
> jsonstr := GapToJsonString(i);
> res := JsonStringToGap(jsonstr);
> if res <> i then
>   Print("Failed: ", i, " to ", res, " via ", jsonstr, "\n");
> fi;
> jsonstream := "";
> s := OutputTextString(jsonstream, true);
> SetPrintFormattingStatus(s, false);
> GapToJsonStream(s, i);
> CloseStream(s);
> if jsonstr <> jsonstream then
>   Print("Failed str/stream match: ", i, " to ", jsonstr, " and ", jsonstream, "\n");
> fi;
> s := InputTextString(jsonstream);
> streamres := JsonStreamToGap(s);
> if res <> streamres then
>   Print("Failed str/stream back to GAP: ", i, " to ", res, " and ", streamres, "\n");
> fi;
> end;;
gap> test_cycle(true);
gap> test_cycle(false);
gap> test_cycle(-1);
gap> test_cycle(0);
gap> test_cycle(1);
gap> test_cycle(123456789012345678901234567890);
gap> test_cycle(1.0);
gap> test_cycle(1.0e200);
gap> test_cycle(1.0e-200);
gap> test_cycle(-1.0e-200);
gap> test_cycle([1,2,3]);
gap> test_cycle([]);
gap> test_cycle("abc");
gap> test_cycle(",abc,");
gap> test_cycle("\000");
gap> test_cycle("\n");
gap> test_cycle("\r");
gap> test_cycle(List([0..255], CharInt));
gap> test_cycle(rec());
gap> test_cycle(rec(a := 1));
gap> test_cycle(rec(a := [1,2], b := [3,4]));