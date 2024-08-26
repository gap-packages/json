#
# json: Reading and Writing JSON
#
# Reading the declaration part of the package.
#

if LoadKernelExtension("json", "json") = false then
    Error("failed to load json kernel extension");
fi;

ReadPackage( "json", "gap/json.gd");
