gap> LoadPackage("json", false);;
gap> dir := DirectoriesPackageLibrary( "json", "tst" );;
gap> f := Filename(dir, "UTF-8-test.txt");;
gap> s := StringFile(f);;
gap> json := GapToJsonString(s);;
gap> fout := Filename(dir, "UTF-8-test.txt.clean");;
gap> sout := StringFile(fout);;
gap> json = sout;
true
