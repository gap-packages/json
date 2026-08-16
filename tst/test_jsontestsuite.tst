#
# Runs the JSONTestSuite corpus in tst/JSONTestSuite through the package; see
# tst/jsontestsuite.g for the expectations and tst/JSONTestSuite/README for
# where the corpus comes from.
#
gap> START_TEST("json package: test_jsontestsuite.tst");
gap> LoadPackage("json", false);;
gap> if not IsBound(_JSON_TS_CheckAgreement) then  # testall.g runs us twice
>      Read(Filename(DirectoriesPackageLibrary("json", "tst"), "jsontestsuite.g"));
>    fi;

# the active implementation accepts and rejects what we expect it to
gap> _JSON_TS_CheckConformance();

# and every implementation agrees with every other one
gap> _JSON_TS_CheckAgreement();

#
gap> STOP_TEST("json package: test_jsontestsuite.tst");
