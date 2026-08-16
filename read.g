#
# json: Reading and Writing JSON
#
# Reading the implementation part of the package.
#
ReadPackage( "json", "gap/utf8.gi");
ReadPackage( "json", "gap/parse.gi");
ReadPackage( "json", "gap/json.gi");

# must come last: it selects the implementation to use
ReadPackage( "json", "gap/impl.gi");
