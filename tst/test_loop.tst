gap> LoadPackage("json", false);;
gap> tmpdir := DirectoryTemporary();;
gap> tmpname := Filename(tmpdir, "test.json");;
gap> test_cycle := function(i)
> local jsonstr, res, jsonstream, s, streamres;
> jsonstr := GapToJsonString(i);
> res := JsonStringToGap(jsonstr);
> if res <> i then
>   Print("Failed: ", i, " to ", res, " via ", jsonstr, "\n");
> fi;
> jsonstream := "";
> s := OutputTextString(jsonstream, true);
> GapToJsonStream(s, i);
> CloseStream(s);
> if jsonstr <> jsonstream then
>   Print("Failed str/stream match: \n", i, "to \n", jsonstr, " and \n", jsonstream, "\n");
> fi;
> s := InputTextString(jsonstream);
> streamres := JsonStreamToGap(s);
> if res <> streamres then
>   Print("Failed str/stream back to GAP: ", i, " to ", res, " and ", streamres, "\n");
> fi;
> s := OutputTextFile(tmpname, false);
> GapToJsonStream(s, i);
> CloseStream(s);
> s := InputTextFile(tmpname);
> jsonstream := ReadAll(s);
> CloseStream(s);
> if jsonstr <> jsonstream then
>   Print("Failed str/file match: \n", i, "to \n", jsonstr, " and \n", jsonstream, "\n");
> fi;
> s := InputTextFile(tmpname);
> streamres := JsonStreamToGap(s);
> CloseStream(s);
> if res <> streamres then
>   Print("Failed str/file back to GAP: ", i, " to ", res, " and ", streamres, "\n");
> fi;
> end;;
gap> test_cycle(true);
gap> test_cycle(false);
gap> test_cycle(-1);
gap> test_cycle(0);
gap> test_cycle(1);
gap> test_cycle(123456789012345678901234567890);
gap> x := rec(a := 2^200, b := 2.0^200, c := List([1..10000], x -> 'a'));;
gap> l := ListWithIdenticalEntries(1000, x);;
gap> test_cycle(l);
gap> test_cycle(l);
gap> test_cycle(l);
gap> test_cycle(l);
gap> test_cycle(l);
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
gap> for i in [0..127] do
> test_cycle(List([0..100],x->CharInt(i)));
> od;
gap> test_cycle(rec());
gap> test_cycle(rec(a := 1));
gap> test_cycle(rec(a := [1,2], b := [3,4]));
gap> test_cycle(rec(a := "4,5,6"));
gap> test_cycle(rec(a := rec(b := rec(c := "4,5,6"))));
gap> test_cycle([1,2,[3,4,rec(a := false)],"abc",false,"",rec(c := ["4",true]),7,8]);
gap> test_cycle([1,2,"",['a', 'b', 'c']]);
gap> test_cycle([0.0]);
gap> test_cycle([-0.0]);
gap> test_cycle([1.0,2.0,1.0e100,1.0e-100]);
gap> r := rec();;
gap> r.("a b c") := 2;;
gap> test_cycle(r);
gap> r.("a \"love\" cats") := 3;;
gap> test_cycle(r);
