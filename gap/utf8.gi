#############################################################################
##
#W  utf8.gi                  json Package
##
##  UTF-8 handling and string escaping for the pure GAP implementation.
##
##  The functions here are transcriptions of getUTF8Char, outputUnicodeChar
##  and FuncJSON_ESCAPE_STRING in src/json.cc. They reproduce that code's
##  quirks on purpose, so that both implementations produce identical output;
##  see the comments on _JSON_GetUTF8Char.
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


#############################################################################
##
#F  _JSON_GetUTF8Char( <str>, <pos> )
##
##  Decodes the character of the string <str> starting at position <pos> and
##  returns [ <codepoint>, <nextpos> ].
##
##  This is *not* a correct UTF-8 decoder, and must not be turned into one:
##  it mirrors getUTF8Char in src/json.cc byte for byte, and tst/test_hard.tst
##  pins the resulting output for a file full of malformed UTF-8. In
##  particular the bytes 0x80-0x9F count as two byte lead bytes, so that the
##  input 0x80 0x80 decodes to code point 0. A sequence that does not decode
##  is treated as a single Latin-1 byte.
##
BindGlobal( "_JSON_GetUTF8Char", function(str, pos)
  local len, first, val, n, i, c;

  len := Length(str);
  first := INT_CHAR(str[pos]);

  if first < 128 then
    return [ first, pos + 1 ];
  elif first < 224 then
    n := 2;
    val := first mod 64;
    if val >= 32 then
      return [ first, pos + 1 ];
    fi;
  elif first < 240 then
    n := 3;
    val := first mod 32;
  else
    n := 4;
    val := first mod 16;
    if val >= 8 then
      return [ first, pos + 1 ];
    fi;
  fi;

  for i in [ 1 .. n-1 ] do
    # reading past the end yields 0, which is not a continuation byte
    if pos + i > len then
      return [ first, pos + 1 ];
    fi;
    c := INT_CHAR(str[pos + i]);
    if QuoInt(c, 64) <> 2 then
      return [ first, pos + 1 ];
    fi;
    val := 64 * val + (c mod 64);
  od;

  if val > 1114111 or (val >= 55296 and val <= 57343) then
    return [ first, pos + 1 ];
  fi;

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
    # the escaping decision is made on the decoded code point, not on the
    # byte: the C code sends overlong encodings through the same switch, so
    # that e.g. the bytes 0xC0 0xAF come out as \/
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
