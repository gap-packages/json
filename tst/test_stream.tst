gap> LoadPackage("json", false);;
gap> test_stream := function(str, res)
> local g, s, i;
> s := InputTextString(str);
> for i in res do
>   g := JsonStreamToGap(s);
>   if g <> i then
>     Print("Failed: ",[str,res]," index ", i , " produced ", g, "\n");
>   fi;
> od;
> end;;
gap> test_stream("1",[1]);
gap> test_stream("1 2",[1,2]);
gap> test_stream("[1][2]",[[1],[2]]);
gap> test_stream("{}{}",[rec(), rec()]);
gap> test_stream("\"abc\"\"def\"", ["abc", "def"]);
gap> test_stream("\"abc\" \"def\"", ["abc", "def"]);
gap> test_stream("1", [1,1]);
Error, syntax error at line 1 near: 
gap> test_stream("\"\"", [""]);
gap> test_stream("\"\"", ["",1]);
Error, syntax error at line 1 near: 
