#############################################################################
##
#W  utf8.gi                  json Package
##
##  UTF-8 handling and string escaping for the pure GAP implementation.
##
##  The functions here mirror getUTF8Char, outputUnicodeChar and
##  FuncJSON_ESCAPE_STRING in src/json.cc so that the GAP and kernel
##  implementations produce identical output.
##

# Character used to mark interesting positions in a TranslateString'd copy of
# the input. Any character not otherwise used would do.
BindGlobal( "_JSON_MARK", CHAR_INT(1) );

# builds a 256 character translation table mapping every byte in <bytes> to
# _JSON_MARK and everything else to a NUL character
BindGlobal( "_JSON_MarkTable", function(bytes)
  local table, b;
  table := ListWithIdenticalEntries(256, CHAR_INT(0));
  for b in bytes do
    table[b+1] := _JSON_MARK;
  od;
  ConvertToStringRep(table);
  return table;
end );

# `\`, `"`, `/`, the control characters and everything non-ASCII need looking
# at when escaping. Note 0x7f is deliberately absent: the C code does not
# escape it either.
BindGlobal( "_JSON_ESCAPE_MARKS",
  _JSON_MarkTable( Concatenation( [ 0 .. 31 ], [ 34, 47, 92 ], [ 128 .. 255 ] ) ) );

# escapes for the control characters which have no shorter form
BindGlobal( "_JSON_CONTROL_ESCAPES",
  List( [ 0 .. 31 ],
        i -> Concatenation( "\\u00", HexStringInt(i + 256){[2,3]} ) ) );


BindGlobal( "_JSON_UTF8SequenceLength", function(first)
  if first < 128 then return 1;
  elif 194 <= first and first <= 223 then return 2;
  elif 224 <= first and first <= 239 then return 3;
  elif 240 <= first and first <= 244 then return 4;
  fi;
  return 0;
end );

BindGlobal( "_JSON_IsValidUTF8Continuation", function(first, index, byte)
  if byte < 128 or 191 < byte then
    return false;
  elif index <> 1 then
    return true;
  elif first = 224 then
    return 160 <= byte;
  elif first = 237 then
    return byte <= 159;
  elif first = 240 then
    return 144 <= byte;
  elif first = 244 then
    return byte <= 143;
  fi;
  return true;
end );


#############################################################################
##
#F  _JSON_GetUTF8Char( <str>, <pos> )
##
##  Decodes the character of the string <str> starting at position <pos> and
##  returns [ <codepoint>, <nextpos> ].
##
##  A malformed sequence is treated as a single Latin-1 byte, matching the
##  package's documented output policy.
##
BindGlobal( "_JSON_GetUTF8Char", function(str, pos)
  local len, first, val, n, i, c;

  len := Length(str);
  first := INT_CHAR(str[pos]);
  n := _JSON_UTF8SequenceLength(first);
  if n = 1 then
    return [ first, pos + 1 ];
  elif n = 0 then
    return [ first, pos + 1 ];
  fi;

  val := first mod (2 ^ (7 - n));
  for i in [ 1 .. n-1 ] do
    if pos + i > len then
      return [ first, pos + 1 ];
    fi;
    c := INT_CHAR(str[pos + i]);
    if not _JSON_IsValidUTF8Continuation(first, i, c) then
      return [ first, pos + 1 ];
    fi;
    val := 64 * val + (c mod 64);
  od;

  return [ val, pos + n ];
end );


#############################################################################
##
#F  _JSON_AppendUTF8Char( <out>, <val> )
##
##  Appends the UTF-8 encoding of the code point <val> to the string <out>.
##
BindGlobal( "_JSON_AppendUTF8Char", function(out, val)
  if val <= 127 then
    Add(out, CHAR_INT(val));
  elif val <= 2047 then
    Add(out, CHAR_INT(192 + QuoInt(val, 64)));
    Add(out, CHAR_INT(128 + val mod 64));
  elif val <= 65535 then
    Add(out, CHAR_INT(224 + QuoInt(val, 4096)));
    Add(out, CHAR_INT(128 + QuoInt(val, 64) mod 64));
    Add(out, CHAR_INT(128 + val mod 64));
  else
    Add(out, CHAR_INT(240 + QuoInt(val, 262144) mod 8));
    Add(out, CHAR_INT(128 + QuoInt(val, 4096) mod 64));
    Add(out, CHAR_INT(128 + QuoInt(val, 64) mod 64));
    Add(out, CHAR_INT(128 + val mod 64));
  fi;
end );


#############################################################################
##
#F  _JSON_PureEscapeString( <s> )
##
##  Escapes the string <s> for use inside a pair of JSON quotes, and returns
##  <s> itself if nothing needs escaping.
##
BindGlobal( "_JSON_PureEscapeString", function(s)
  local str, marks, p, out, prev, dec, val;

  if IsEmpty(s) then
    return s;
  fi;
  if IsStringRep(s) then
    str := s;
  else
    str := CopyToStringRep(s);
  fi;

  marks := ShallowCopy(str);
  TranslateString(marks, _JSON_ESCAPE_MARKS);
  p := Position(marks, _JSON_MARK);
  if p = fail then
    return s;
  fi;

  out := "";
  prev := 1;
  while p <> fail do
    Append(out, str{[ prev .. p-1 ]});
    # Valid UTF-8 is preserved; a malformed byte is re-encoded as Latin-1.
    dec := _JSON_GetUTF8Char(str, p);
    val := dec[1];
    if val = 34 or val = 47 or val = 92 then
      Add(out, '\\');
      Add(out, CHAR_INT(val));
    elif val = 8 then
      Append(out, "\\b");
    elif val = 9 then
      Append(out, "\\t");
    elif val = 10 then
      Append(out, "\\n");
    elif val = 12 then
      Append(out, "\\f");
    elif val = 13 then
      Append(out, "\\r");
    elif val < 32 then
      Append(out, _JSON_CONTROL_ESCAPES[ val + 1 ]);
    else
      _JSON_AppendUTF8Char(out, val);
    fi;
    prev := dec[2];
    p := Position(marks, _JSON_MARK, prev - 1);
  od;
  Append(out, str{[ prev .. Length(str) ]});

  return out;
end );
