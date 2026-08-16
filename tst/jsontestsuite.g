#############################################################################
##
##  jsontestsuite.g              json Package
##
##  Support code for tst/test_jsontestsuite.tst, which runs the corpus in
##  tst/JSONTestSuite through the package.
##
##  Upstream names a file y_* if it must be accepted, n_* if it must be
##  rejected and i_* if either is allowed. We accept every y_ file and reject
##  every n_ file bar the eleven listed below, all of them number formats that
##  picojson is more relaxed about than RFC 8259. Both implementations are
##  deliberately relaxed in the same way, so tightening them up is a separate
##  decision rather than a difference between the two.
##

BindGlobal( "_JSON_TS_DIR", "JSONTestSuite" );

# n_ files we accept anyway
BindGlobal( "_JSON_TS_LENIENT", MakeImmutable( [
  "n_multidigit_number_then_00.json",              # 123\0\0
  "n_number_-01.json",                             # leading zero
  "n_number_-2..json",                             # no fractional digits
  "n_number_0.e1.json",
  "n_number_2.e+3.json",
  "n_number_2.e-3.json",
  "n_number_2.e3.json",
  "n_number_neg_int_starting_with_zero.json",
  "n_number_neg_real_without_int_part.json",       # -.123
  "n_number_real_without_fractional_part.json",    # 1.
  "n_number_with_leading_zero.json",
] ) );

# i_ files we accept; the remaining i_ files must be rejected. Broadly, we
# pass malformed UTF-8 through untouched but insist on well formed \u
# surrogate pairs.
BindGlobal( "_JSON_TS_ACCEPTED", MakeImmutable( [
  "i_number_double_huge_neg_exp.json",
  "i_number_huge_exp.json",
  "i_number_neg_int_huge_exp.json",
  "i_number_pos_double_huge_exp.json",
  "i_number_real_neg_overflow.json",
  "i_number_real_pos_overflow.json",
  "i_number_real_underflow.json",
  "i_number_too_big_neg_int.json",
  "i_number_too_big_pos_int.json",
  "i_number_very_big_negative_int.json",
  "i_string_UTF-8_invalid_sequence.json",
  "i_string_UTF8_surrogate_U+D800.json",
  "i_string_invalid_utf-8.json",
  "i_string_iso_latin_1.json",
  "i_string_lone_utf8_continuation_byte.json",
  "i_string_not_in_unicode_range.json",
  "i_string_overlong_sequence_2_bytes.json",
  "i_string_overlong_sequence_6_bytes.json",
  "i_string_overlong_sequence_6_bytes_null.json",
  "i_string_truncated-utf-8.json",
  "i_structure_500_nested_arrays.json",
] ) );


#############################################################################
##
#F  _JSON_TS_Normalize( <obj> )
##
##  A canonical string for a parsed value, used to compare the results of the
##  two implementations. Strings become lists of byte values, so that the
##  deliberately malformed UTF-8 in the corpus can be compared without being
##  re-encoded, and record components are sorted, so that the order in which
##  the parsers happened to fill a record does not matter.
##
DeclareGlobalFunction( "_JSON_TS_Normalize" );   # recurses

InstallGlobalFunction( _JSON_TS_Normalize, function(obj)
  local parts, nam;

  if obj = fail then
    return "null";
  elif obj = true then
    return "true";
  elif obj = false then
    return "false";
  elif IsInt(obj) then
    return Concatenation("I", String(obj));
  elif IsFloat(obj) then
    return Concatenation("F", String(obj));
  elif IsStringRep(obj) then
    return Concatenation("S", String(List(obj, IntChar)));
  elif IsRecord(obj) then
    parts := List(SortedList(RecNames(obj)),
                  nam -> Concatenation(_JSON_TS_Normalize(nam), ":",
                                       _JSON_TS_Normalize(obj.(nam))));
    return Concatenation("{", JoinStringsWithSeparator(parts, ","), "}");
  elif IsList(obj) then
    parts := List(obj, _JSON_TS_Normalize);
    return Concatenation("[", JoinStringsWithSeparator(parts, ","), "]");
  fi;

  return Concatenation("?", String(obj));
end );


#############################################################################
##
#F  _JSON_TS_Files( )
##
##  The corpus, sorted so that the tests run in a reproducible order.
##
BindGlobal( "_JSON_TS_Files", function()
  local dir, files;
  dir := Filename(DirectoriesPackageLibrary("json", "tst"), _JSON_TS_DIR);
  files := Filtered(DirectoryContents(dir),
             f -> 5 < Length(f) and f{[ Length(f)-4 .. Length(f) ]} = ".json");
  return [ dir, SortedList(files) ];
end );


#############################################################################
##
#F  _JSON_TS_Parse( <dir>, <file> )
##
##  Parses one corpus file, returning either [ true, <normalized value> ] or
##  [ false ].
##
if IsReadOnlyGlobal("ERROR_OUTPUT") then
  MakeReadWriteGlobal("ERROR_OUTPUT");
fi;

BindGlobal( "_JSON_TS_Parse", function(dir, file)
  local saved, sink, res;
  # most of the corpus is meant to be rejected, so send the error messages to
  # a sink rather than into the test output
  saved := ERROR_OUTPUT;
  sink := OutputTextString("", false);
  ERROR_OUTPUT := sink;
  res := CALL_WITH_CATCH(JsonStringToGap,
                         [ StringFile(Filename(Directory(dir), file)) ]);
  ERROR_OUTPUT := saved;
  CloseStream(sink);
  if res[1] then
    return [ true, _JSON_TS_Normalize(res[2]) ];
  fi;
  return [ false ];
end );


#############################################################################
##
#F  _JSON_TS_CheckConformance( )
##
##  Checks the implementation currently in use against the expectations above,
##  and prints a line for every disagreement.
##
BindGlobal( "_JSON_TS_CheckConformance", function()
  local data, dir, file, accepted, expected;

  data := _JSON_TS_Files();
  dir := data[1];

  for file in data[2] do
    accepted := _JSON_TS_Parse(dir, file)[1];
    if file[1] = 'y' then
      expected := true;
    elif file[1] = 'n' then
      expected := file in _JSON_TS_LENIENT;
    else
      expected := file in _JSON_TS_ACCEPTED;
    fi;
    if accepted <> expected then
      if accepted then
        Print("unexpectedly accepted: ", file, "\n");
      else
        Print("unexpectedly rejected: ", file, "\n");
      fi;
    fi;
  od;
end );


#############################################################################
##
#F  _JSON_TS_CheckAgreement( )
##
##  Checks that every available implementation parses the corpus the same way,
##  and prints a line for every disagreement. Does nothing useful when only
##  one implementation is present.
##
BindGlobal( "_JSON_TS_CheckAgreement", function()
  local impls, saved, data, dir, file, results, i;

  impls := JsonAvailableImplementations();
  saved := JsonImplementation();
  data := _JSON_TS_Files();
  dir := data[1];

  for file in data[2] do
    results := [];
    for i in impls do
      SetJsonImplementation(i);
      Add(results, _JSON_TS_Parse(dir, file));
    od;
    for i in [ 2 .. Length(impls) ] do
      if results[i] <> results[1] then
        Print(file, ": ", impls[1], " gave ", results[1],
              " but ", impls[i], " gave ", results[i], "\n");
      fi;
    od;
  od;

  SetJsonImplementation(saved);
end );
