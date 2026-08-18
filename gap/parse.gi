#############################################################################
##
#W  parse.gi                 json Package
##
##  The pure GAP JSON parser.
##
##  This is a transcription of the picojson parser in src/picojson/picojson.h
##  and of gap_val::from_str in src/picojson/gap-traits.h, so that both
##  implementations accept and reject the same texts, produce the same values
##  and raise the same error messages. picojson is more permissive than
##  RFC 8259 about numbers -- it accepts leading zeros, `1.`, `-.5` and `2.e3`
##  -- and that is reproduced here on purpose; tst/test_jsontestsuite.tst
##  pins the exact list of deviations.
##
##  Reading is done through a reader record mirroring picojson's input<Iter>:
##
##    buf      the bytes read so far
##    marks    a copy of buf with `"`, `\` and the control characters replaced
##             by _JSON_MARK, so that string bodies can be scanned with the
##             kernel's Position rather than a GAP level loop
##    len      Length(buf)
##    reallen  how many bytes of buf came from the source
##    pos      index of the next byte to read
##    maxpos   the largest value pos has ever had, so maxpos-1 is the number
##             of bytes actually read; used for the error line number
##    eofread  whether the last read hit the end of the input
##

# Maximum nesting depth accepted here. The kernel parser recurses on the C
# stack instead and crashes GAP outright on deeply nested input.
_JSON_MAX_DEPTH := 1024;

# declared ahead of its definition because it recurses
DeclareGlobalFunction( "_JSON_ParseValue" );

# `"`, `\` and the control characters end a run of ordinary string bytes
BindGlobal( "_JSON_PARSE_MARKS",
  _JSON_MarkTable( Concatenation( [ 0 .. 31 ], [ 34, 92 ] ) ) );

BindGlobal( "_JSON_CONTROL_CHARS", List( [ 0 .. 31 ], CHAR_INT ) );
ConvertToStringRep( _JSON_CONTROL_CHARS );


#############################################################################
##
##  Filling the buffer.
##

# Appends <chunk> to the buffer, keeping <marks> in step.
BindGlobal( "_JSON_Append", function(r, chunk)
  local m;
  m := ShallowCopy(chunk);
  TranslateString(m, _JSON_PARSE_MARKS);
  Append(r.buf, chunk);
  Append(r.marks, m);
  r.len := Length(r.buf);
end );

# Tries to make at least one more byte available; returns whether it managed.
BindGlobal( "_JSON_FillMore", function(r)
  local chunk, byte;

  if r.eof then
    return false;
  fi;

  if r.seekable then
    chunk := ReadAll(r.stream, r.chunk);
    r.chunk := Minimum(2 * r.chunk, 65536);
    if chunk <> fail and Length(chunk) > 0 then
      r.reallen := r.reallen + Length(chunk);
      _JSON_Append(r, chunk);
      return true;
    fi;
  else
    byte := ReadByte(r.stream);
    if byte <> fail then
      r.reallen := r.reallen + 1;
      _JSON_Append(r, [ CHAR_INT(byte) ]);
      return true;
    fi;
  fi;

  # The stream is exhausted. The C iterator returns a byte 0 for the first
  # failing ReadByte and only reports the end of the input on the next call,
  # so the parser sees one spurious NUL first; reproduce that, as
  # tst/test_stream.tst depends on it. See src/json.cc:281-320.
  r.eof := true;
  _JSON_Append(r, "\000");
  return true;
end );

# Ensures the byte at index <n> is available if the source can supply it.
BindGlobal( "_JSON_Fill", function(r, n)
  while r.len < n do
    if not _JSON_FillMore(r) then
      return false;
    fi;
  od;
  return true;
end );


#############################################################################
##
##  The primitives of picojson's input<Iter>.
##

# picojson's getc: the next byte, or -1 at the end of the input
BindGlobal( "_JSON_Next", function(r)
  local c;
  if r.len < r.pos and not _JSON_Fill(r, r.pos) then
    r.eofread := true;
    return -1;
  fi;
  c := INT_CHAR(r.buf[r.pos]);
  r.pos := r.pos + 1;
  if r.pos > r.maxpos then
    r.maxpos := r.pos;
  fi;
  r.eofread := false;
  return c;
end );

# picojson's ungetc, which is a no-op after the end of the input was reached
BindGlobal( "_JSON_Unget", function(r)
  if not r.eofread then
    r.pos := r.pos - 1;
  fi;
end );

BindGlobal( "_JSON_SkipWs", function(r)
  local c;
  repeat
    c := _JSON_Next(r);
  until c <> 32 and c <> 9 and c <> 10 and c <> 13;
  _JSON_Unget(r);
end );

BindGlobal( "_JSON_Expect", function(r, c)
  _JSON_SkipWs(r);
  if _JSON_Next(r) <> c then
    _JSON_Unget(r);
    return false;
  fi;
  return true;
end );

BindGlobal( "_JSON_Match", function(r, str)
  local c;
  for c in str do
    if _JSON_Next(r) <> INT_CHAR(c) then
      _JSON_Unget(r);
      return false;
    fi;
  od;
  return true;
end );

# Position of the next mark at or after index <from>, filling as needed.
BindGlobal( "_JSON_FindMark", function(r, from)
  local q;
  while true do
    q := Position(r.marks, _JSON_MARK, from - 1);
    if q <> fail then
      return q;
    fi;
    from := r.len + 1;
    if not _JSON_FillMore(r) then
      return fail;
    fi;
  od;
end );


#############################################################################
##
##  Errors.
##

# Position of the next newline at or after r.pos, or len+1 if there is none.
BindGlobal( "_JSON_FindNewline", function(r)
  local p, from;
  from := r.pos;
  while true do
    p := Position(r.buf, '\n', from - 1);
    if p <> fail then
      return p;
    fi;
    from := r.len + 1;
    if not _JSON_FillMore(r) then
      return r.len + 1;
    fi;
  od;
end );

# Repositions a seekable stream on the byte after the last one the parser
# used, undoing any read-ahead done for speed.
BindGlobal( "_JSON_StreamSync", function(r)
  if r.seekable then
    SeekPositionStream(r.stream,
                       r.startpos + Minimum(r.maxpos - 1, r.reallen));
  fi;
end );

BindGlobal( "_JSON_SyntaxError", function(r)
  local read, line, p, stop, tail;

  # picojson counts a line for every read whose predecessor was a newline
  read := r.maxpos - 1;
  line := 1;
  p := 0;
  while true do
    p := Position(r.buf, '\n', p);
    if p = fail or p >= read then
      break;
    fi;
    line := line + 1;
  od;

  # the message ends with the rest of the current line, control characters
  # removed
  stop := _JSON_FindNewline(r);
  tail := r.buf{[ r.pos .. stop - 1 ]};
  RemoveCharacters(tail, _JSON_CONTROL_CHARS);

  # that scan consumes the rest of the line, terminating newline included
  r.maxpos := Maximum(r.maxpos, stop + 1);
  _JSON_StreamSync(r);
  ErrorNoReturn("syntax error at line ", line, " near: ", tail);
end );


#############################################################################
##
##  Numbers.
##

BindGlobal( "_JSON_ISNUMCHAR", List( [ 0 .. 255 ],
  i -> (i >= 48 and i <= 57) or i = 43 or i = 45 or i = 101 or i = 69 or i = 46 ) );

# gap_val::to_gap_int: an optional sign followed by at least one digit
BindGlobal( "_JSON_ToGapInt", function(s)
  local neg, rest;
  if IsEmpty(s) then
    return fail;
  fi;
  neg := s[1] = '-';
  if neg or s[1] = '+' then
    rest := s{[ 2 .. Length(s) ]};
  else
    rest := s;
  fi;
  # Int("") and Int("-") are both 0, so check the digits ourselves
  if IsEmpty(rest) or not IsSubset(CHARS_DIGITS, rest) then
    return fail;
  fi;
  if neg then
    return - Int(rest);
  fi;
  return Int(rest);
end );

BindGlobal( "_JSON_ParseNumber", function(r)
  local tok, c, loc, i, val, mant, exp;

  tok := "";
  repeat
    c := _JSON_Next(r);
    if c >= 0 and _JSON_ISNUMCHAR[ c+1 ] then
      Add(tok, CHAR_INT(c));
    else
      _JSON_Unget(r);
      break;
    fi;
  until false;

  if IsEmpty(tok) then
    _JSON_SyntaxError(r);
  fi;

  # gap_val::from_str: a fractional part or a negative exponent gives a float,
  # anything else an integer of arbitrary size
  if '.' in tok then
    val := FLOAT_STRING(tok);
    if val = fail then
      _JSON_SyntaxError(r);
    fi;
    return val;
  fi;

  loc := fail;
  for i in [ 1 .. Length(tok) ] do
    if tok[i] = 'e' or tok[i] = 'E' then
      loc := i;
      break;
    fi;
  od;

  if loc = fail then
    val := _JSON_ToGapInt(tok);
    if val = fail then
      _JSON_SyntaxError(r);
    fi;
    return val;
  fi;

  if loc < Length(tok) and tok[loc+1] = '-' then
    val := FLOAT_STRING(tok);
    if val = fail then
      _JSON_SyntaxError(r);
    fi;
    return val;
  fi;

  mant := _JSON_ToGapInt(tok{[ 1 .. loc-1 ]});
  exp := _JSON_ToGapInt(tok{[ loc+1 .. Length(tok) ]});
  if mant = fail or exp = fail then
    _JSON_SyntaxError(r);
  fi;
  return mant * 10 ^ exp;
end );


#############################################################################
##
##  Strings.
##

# picojson's _parse_quadhex, returning fail rather than -1
BindGlobal( "_JSON_ParseQuadHex", function(r)
  local val, i, c;
  val := 0;
  for i in [ 1 .. 4 ] do
    c := _JSON_Next(r);
    if c = -1 then
      return fail;
    elif c >= 48 and c <= 57 then
      c := c - 48;
    elif c >= 65 and c <= 70 then
      c := c - 55;
    elif c >= 97 and c <= 102 then
      c := c - 87;
    else
      _JSON_Unget(r);
      return fail;
    fi;
    val := 16 * val + c;
  od;
  return val;
end );

# picojson's _parse_codepoint
BindGlobal( "_JSON_ParseCodepoint", function(r, out)
  local val, second;

  val := _JSON_ParseQuadHex(r);
  if val = fail then
    return false;
  fi;

  if val >= 55296 and val <= 57343 then
    if val >= 56320 then
      # a low surrogate on its own
      return false;
    fi;
    # note the short circuit: if the first byte is not a backslash the second
    # one is never read
    if _JSON_Next(r) <> 92 or _JSON_Next(r) <> 117 then
      _JSON_Unget(r);
      return false;
    fi;
    second := _JSON_ParseQuadHex(r);
    if second = fail or second < 56320 or second > 57343 then
      return false;
    fi;
    val := 65536 + 1024 * (val - 55296) + (second - 56320) mod 1024;
  fi;

  _JSON_AppendUTF8Char(out, val);
  return true;
end );

# picojson's _parse_string, entered after the opening quote. Runs of ordinary
# bytes are copied in one go, so a string without escapes costs one Position
# and one slice.
BindGlobal( "_JSON_ParseStringBody", function(r)
  local start, out, q, c;

  start := r.pos;
  out := fail;

  while true do
    q := _JSON_FindMark(r, r.pos);
    if q = fail then
      # ran off the end; picojson reads -1, which is below ' '
      r.pos := r.len + 1;
      r.eofread := true;
      _JSON_SyntaxError(r);
    fi;

    c := INT_CHAR(r.buf[q]);
    if c = 34 then
      if out = fail then
        out := r.buf{[ start .. q-1 ]};
      else
        Append(out, r.buf{[ start .. q-1 ]});
      fi;
      r.pos := q + 1;
      r.maxpos := Maximum(r.maxpos, q + 1);
      r.eofread := false;
      return out;
    elif c < 32 then
      # a raw control character; picojson ungets it before failing
      r.pos := q;
      r.maxpos := Maximum(r.maxpos, q + 1);
      r.eofread := false;
      _JSON_SyntaxError(r);
    fi;

    # a backslash
    if out = fail then
      out := "";
    fi;
    Append(out, r.buf{[ start .. q-1 ]});
    r.pos := q + 1;
    r.maxpos := Maximum(r.maxpos, q + 1);
    r.eofread := false;

    c := _JSON_Next(r);
    if c = -1 then
      _JSON_SyntaxError(r);
    elif c = 34 or c = 92 or c = 47 then
      Add(out, CHAR_INT(c));
    elif c = 98 then
      Add(out, '\b');
    elif c = 102 then
      Add(out, '\014');
    elif c = 110 then
      Add(out, '\n');
    elif c = 114 then
      Add(out, '\r');
    elif c = 116 then
      Add(out, '\t');
    elif c = 117 then
      if not _JSON_ParseCodepoint(r, out) then
        _JSON_SyntaxError(r);
      fi;
    else
      _JSON_SyntaxError(r);
    fi;
    start := r.pos;
  od;
end );


#############################################################################
##
##  Values.
##

InstallGlobalFunction( _JSON_ParseValue, function(r, depth)
  local c, res, list, key;

  if depth > _JSON_MAX_DEPTH then
    _JSON_StreamSync(r);
    ErrorNoReturn("JSON input nested more than _JSON_MAX_DEPTH (",
                  _JSON_MAX_DEPTH, ") levels deep");
  fi;

  _JSON_SkipWs(r);
  c := _JSON_Next(r);

  if c = 110 then          # null
    if not _JSON_Match(r, "ull") then
      _JSON_SyntaxError(r);
    fi;
    return fail;

  elif c = 116 then        # true
    if not _JSON_Match(r, "rue") then
      _JSON_SyntaxError(r);
    fi;
    return true;

  elif c = 102 then        # false
    if not _JSON_Match(r, "alse") then
      _JSON_SyntaxError(r);
    fi;
    return false;

  elif c = 34 then         # a string
    return _JSON_ParseStringBody(r);

  elif c = 91 then         # an array
    list := [];
    if _JSON_Expect(r, 93) then
      return list;
    fi;
    repeat
      Add(list, _JSON_ParseValue(r, depth + 1));
    until not _JSON_Expect(r, 44);
    if not _JSON_Expect(r, 93) then
      _JSON_SyntaxError(r);
    fi;
    return list;

  elif c = 123 then        # an object
    res := rec();
    if _JSON_Expect(r, 125) then
      return res;
    fi;
    repeat
      if not _JSON_Expect(r, 34) then
        _JSON_SyntaxError(r);
      fi;
      key := _JSON_ParseStringBody(r);
      if not _JSON_Expect(r, 58) then
        _JSON_SyntaxError(r);
      fi;
      # a repeated key overwrites the earlier value, as in the C version
      res.(key) := _JSON_ParseValue(r, depth + 1);
    until not _JSON_Expect(r, 44);
    if not _JSON_Expect(r, 125) then
      _JSON_SyntaxError(r);
    fi;
    return res;

  elif c = 45 or (c >= 48 and c <= 57) then
    _JSON_Unget(r);
    return _JSON_ParseNumber(r);
  fi;

  _JSON_Unget(r);
  _JSON_SyntaxError(r);
end );


#############################################################################
##
##  Entry points.
##

BindGlobal( "_JSON_StringReader", function(str)
  local marks;
  marks := ShallowCopy(str);
  TranslateString(marks, _JSON_PARSE_MARKS);
  return rec( buf := str, marks := marks,
              len := Length(str), reallen := Length(str),
              pos := 1, maxpos := 1, eofread := false,
              eof := true, seekable := false, stream := fail,
              chunk := 0, startpos := 0 );
end );

BindGlobal( "_JSON_PureStringToGap", function(str)
  local r, val, i, c, stop;

  if not IsString(str) then
    ErrorNoReturn("Input to JsonToGap must be a string");
  fi;
  if not IsStringRep(str) then
    str := CopyToStringRep(str);
  fi;

  r := _JSON_StringReader(str);
  val := _JSON_ParseValue(r, 0);

  # nothing but whitespace may follow, mirroring src/json.cc:449-456
  for i in [ r.pos .. Length(str) ] do
    c := str[i];
    if not (c in " \t\n\013\014\r") and c <> '\000' then
      # the C prints the rest with %s, which stops at a NUL
      stop := Position(str, '\000', i-1);
      if stop = fail then
        stop := Length(str) + 1;
      fi;
      ErrorNoReturn("Failed to parse end of string: '",
                    str{[ i .. stop-1 ]}, "'");
    fi;
  od;

  return val;
end );

BindGlobal( "_JSON_StreamReader", function(stream)
  local start, seekable;

  # reading in chunks is far faster than byte by byte, but is only safe if we
  # can put back what we did not use
  start := CALL_WITH_CATCH(PositionStream, [ stream ]);
  seekable := start[1] and IsInt(start[2])
              and CALL_WITH_CATCH(SeekPositionStream, [ stream, start[2] ])
                  = [ true, true ];
  if not seekable then
    start := [ true, 0 ];
  fi;

  return rec( buf := "", marks := "",
              len := 0, reallen := 0,
              pos := 1, maxpos := 1, eofread := false,
              eof := false, seekable := seekable, stream := stream,
              chunk := 1024, startpos := start[2] );
end );

BindGlobal( "_JSON_PureStreamToGap", function(stream)
  local r, val;
  r := _JSON_StreamReader(stream);
  # unlike the string case there is no check for trailing garbage: a stream
  # may hold several values in a row
  val := _JSON_ParseValue(r, 0);
  _JSON_StreamSync(r);
  return val;
end );
