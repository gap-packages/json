#
# json: Reading and Writing JSON
#
# Declarations
#

#! @Description
#!   Outputs a GAP object as JSON to a stream
DeclareOperation("GapToJsonStream", [IsOutputStream, IsObject]);

#! @Description
#!   Outputs a GAP object as a JSON string
DeclareGlobalFunction("GapToJsonString");

#! @Description
#!   Reads a JSON string as GAP
DeclareGlobalFunction("JsonToGap");