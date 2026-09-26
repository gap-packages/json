#
# Runs the JSONTestSuite corpus in tst/JSONTestSuite through the package; see
# tst/jsontestsuite.g for the expectations and tst/JSONTestSuite/README for
# where the corpus comes from.
#
gap> START_TEST("json package: test_jsontestsuite.tst");
gap> LoadPackage("json", false);;
gap> if not IsBound(_JSON_TS_CheckConformance) then
>      Read(Filename(DirectoriesPackageLibrary("json", "tst"), "jsontestsuite.g"));
>    fi;

# the complete corpus is present
gap> Length(_JSON_TS_Files()[2]);
316

# the active implementation accepts and rejects what we expect it to
gap> _JSON_TS_CheckConformance();

#
gap> STOP_TEST("json package: test_jsontestsuite.tst");
