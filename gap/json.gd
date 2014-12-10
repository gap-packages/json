#! @Chapter GAP-JSON mapping
#! This package defines a mapping between the JSON markup language and GAP.
#! The built-in datatypes of GAP provide an easy mapping to and from JSON.
#! This package uses the following mapping between GAP and JSON.
#!
#! * JSON lists are mapped to GAP lists
#! * JSON dictionaries are mapped to GAP records
#! * JSON strings are mapped to GAP strings
#! * Integers are mapped to GAP integers, non-integer numbers are mapped to Floats
#! * true, false and null are mapped to true, false and fail respectively
#! 
#! Note that this library is *NOT* intended to provide a general purpose library
#! for transmitting any GAP object. If you wish to do this, look at
#! the openmath package, or IO_Pickle in the IO package.

#! @Section Methods
#! @Arguments stream value
#! @Description
#! Converts the <A>value</A> to JSON, and outputs it to <A>stream</A>.
#! This function disables GAP's usual line splitting while JSON is
#! being outputted.
DeclareGlobalFunction("GapToJsonStream");

DeclareOperation("_GapToJsonStreamInternal", [IsOutputStream, IsObject]);

#! @Arguments value
#! @Returns string
#! @Description
#! Converts a GAP <A>value</A> to a JSON string.
DeclareGlobalFunction("GapToJsonString");

#! @Arguments string
#! @Returns value
#! @Description
#! Converts a JSON <A>string</A> into a GAP value.
DeclareGlobalFunction("JsonStringToGap");

#! @Arguments stream
#! @Returns value
#! @Description
#! Reads a single JSON object from a <A>stream</A> and converts it to a GAP value.
DeclareGlobalFunction("JsonStreamToGap");