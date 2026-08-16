#
# json: Reading and Writing JSON
#
# This file runs package tests. It is also referenced in the package
# metadata in PackageInfo.g.
#
LoadPackage( "json" );

if IsBound(GAPInfo.SystemEnvironment.JSON_EXPECT_NO_KERNEL) and
   GAPInfo.SystemEnvironment.JSON_EXPECT_NO_KERNEL = "true" and
   _JSON_KERNEL_AVAILABLE then
  Error("no-kernel CI job loaded the kernel extension");
fi;

TestDirectory(DirectoriesPackageLibrary( "json", "tst" ),
  rec(exitGAP := true));

FORCE_QUIT_GAP(1);
