#
# json: Reading and Writing JSON
#
# This file is a script which compiles the package manual.
#
if fail = LoadPackage("AutoDoc", ">= 2016.01.21") then
    Error("AutoDoc 2016.01.21 or newer is required");
fi;

AutoDoc( rec( scaffold := true, autodoc := true ) );

QUIT;
