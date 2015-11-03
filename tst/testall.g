#
# json: Reading and Writing JSON
#
# This file runs package tests. It is also referenced in the package
# metadata in PackageInfo.g.
#
LoadPackage( "json" );

TestDirectory(DirectoriesPackageLibrary( "json", "tst" ),
  rec(exitGAP := true));

FORCE_QUIT_GAP(1);
