#
# json: Reading and Writing JSON
#
# This file runs package tests. It is also referenced in the package
# metadata in PackageInfo.g.
#
# The whole test directory is run once per available implementation, so that
# the pure GAP code is exercised even on installations which have the kernel
# extension.
#
LoadPackage( "json" );

TestJson := function()
  local dirs, result, impl;
  dirs := DirectoriesPackageLibrary( "json", "tst" );
  result := true;
  for impl in JsonAvailableImplementations() do
    SetJsonImplementation( impl );
    Print( "#I  testing the '", impl, "' implementation\n" );
    result := TestDirectory( dirs, rec( exitGAP := false ) ) and result;
  od;
  return result;
end;

if TestJson() then
  QUIT_GAP(0);
fi;
FORCE_QUIT_GAP(1);
