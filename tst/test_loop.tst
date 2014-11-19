gap> LoadPackage("json", false);;
gap> test_cycle := function(i)
> local json, res;
> json := GapToJsonString(i);
> res := JsonToGap(json);
> if res <> i then
>   Print("Failed: ", i, " to ", res, " via ", json, "\n");
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
gap> test_cycle("");
gap> test_cycle(",abc,");
gap> test_cycle(rec());
gap> test_cycle(rec(a := 1));
gap> test_cycle(rec(a := [1,2], b := [3,4]));
