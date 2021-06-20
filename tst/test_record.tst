gap> START_TEST("json package: test_record.tst");
gap> LoadPackage("json", false);;

#
gap> r := rec(second := rec(two := 3, one := 4), first := true);;
gap> r.5 := [1, 2, 3];;
gap> GapToJsonString(r);
"{\"5\" : [1,2,3],\"first\" : true,\"second\" : {\"one\" : 4,\"two\" : 3}}"

#
gap> STOP_TEST("json package: test_record.tst");
