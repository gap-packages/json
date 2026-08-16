#############################################################################
##
#W  parse.gi                 json Package
##
##  The pure GAP JSON parser.
##
##  This follows the parser contract implemented by the kernel extension:
##  strict UTF-8 strings, bounded nesting, Python-compatible non-finite
##  numbers, and deliberately generous finite-number syntax. The
##  JSONTestSuite tests pin the accepted language and compare both
##  implementations.
##
##  String input is scanned in bulk. Stream input is deliberately read one
##  byte at a time with one byte of parser lookahead. This avoids bulk read-ahead
##  and works uniformly for seekable and non-seekable streams.
##

# Maximum nesting depth, shared with the kernel parser's public contract.
_JSON_MAX_DEPTH := 1024;

# declared ahead of its definition because it recurses
DeclareGlobalFunction( "_JSON_ParseValue" );

# Quotes, backslashes, controls and non-ASCII bytes need individual handling.
BindGlobal( "_JSON_PARSE_MARKS",
  _JSON_MarkTable( Concatenation( [ 0 .. 31 ], [ 34, 92 ], [ 128 .. 255 ] ) ) );


#############################################################################
##
##  The primitives of picojson's input<Iter>.
##

# picojson's getc: the next byte, or -1 at the end of the input
BindGlobal( "_JSON_Next", function(r)
  local c;
  if r.isStream then
    if r.lookahead <> fail then
      c := r.lookahead;
      r.lookahead := fail;
    else
      c := ReadByte(r.stream);
      if c = fail then
        r.eofread := true;
        return -1;
      fi;
    fi;
    r.last := c;
    if c = 10 then
      r.line := r.line + 1;
    fi;
    r.eofread := false;
    return c;
  fi;
  if r.pos > Length(r.buf) then
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
  if r.isStream then
    if not r.eofread then
      Assert(1, r.lookahead = fail);
      r.lookahead := r.last;
      if r.last = 10 then
        r.line := r.line - 1;
      fi;
    fi;
    return;
  fi;
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

# Position of the next syntax-significant byte at or after <from>.
BindGlobal( "_JSON_FindMark", function(r, from)
  return Position(r.marks, _JSON_MARK, from - 1);
end );


#############################################################################
##
##  Errors.
##

BindGlobal( "_JSON_SyntaxError", function(r)
  local read, line, p;

  if r.isStream then
    ErrorNoReturn("Invalid JSON syntax at line ", r.line);
  fi;

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

  ErrorNoReturn("Invalid JSON syntax at line ", line);
end );

BindGlobal( "_JSON_InvalidUTF8", function(r)
  ErrorNoReturn("invalid UTF-8 in JSON string");
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

BindGlobal( "_JSON_ParseNumber", function(r, prefix)
  local tok, c, loc, i, val, mant, exp;

  tok := prefix;
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

BindGlobal( "_JSON_AppendUTF8Sequence", function(r, out, first)
  local length, i, continuation;
  length := _JSON_UTF8SequenceLength(first);
  if length = 0 then
    _JSON_InvalidUTF8(r);
  fi;
  Add(out, CHAR_INT(first));
  for i in [ 1 .. length - 1 ] do
    continuation := _JSON_Next(r);
    if not _JSON_IsValidUTF8Continuation(first, i, continuation) then
      _JSON_InvalidUTF8(r);
    fi;
    Add(out, CHAR_INT(continuation));
  od;
end );


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

BindGlobal( "_JSON_ParseEscape", function(r, out)
  local c;
  c := _JSON_Next(r);
  if c = 34 or c = 92 or c = 47 then
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
  elif c = 117 and _JSON_ParseCodepoint(r, out) then
    return;
  else
    _JSON_SyntaxError(r);
  fi;
end );

# picojson's _parse_string, entered after the opening quote. Runs of ordinary
# bytes are copied in one go, so a string without escapes costs one Position
# and one slice.
BindGlobal( "_JSON_ParseStringBody", function(r)
  local start, out, q, c;

  if r.isStream then
    out := "";
    while true do
      c := _JSON_Next(r);
      if c = -1 then
        _JSON_SyntaxError(r);
      elif c = 34 then
        return out;
      elif c < 32 then
        _JSON_Unget(r);
        _JSON_SyntaxError(r);
      elif c >= 128 then
        _JSON_AppendUTF8Sequence(r, out, c);
      elif c <> 92 then
        Add(out, CHAR_INT(c));
      else
        _JSON_ParseEscape(r, out);
      fi;
    od;
  fi;

  start := r.pos;
  out := fail;

  while true do
    q := _JSON_FindMark(r, r.pos);
    if q = fail then
      # ran off the end; picojson reads -1, which is below ' '
      r.pos := Length(r.buf) + 1;
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
    elif c >= 128 then
      if out = fail then
        out := "";
      fi;
      Append(out, r.buf{[ start .. q-1 ]});
      r.pos := q;
      r.maxpos := Maximum(r.maxpos, q);
      r.eofread := false;
      _JSON_AppendUTF8Sequence(r, out, _JSON_Next(r));
      start := r.pos;
      continue;
    fi;

    # a backslash
    if out = fail then
      out := "";
    fi;
    Append(out, r.buf{[ start .. q-1 ]});
    r.pos := q + 1;
    r.maxpos := Maximum(r.maxpos, q + 1);
    r.eofread := false;

    _JSON_ParseEscape(r, out);
    start := r.pos;
  od;
end );


#############################################################################
##
##  Values.
##

InstallGlobalFunction( _JSON_ParseValue, function(r, depth)
  local c, next, res, list, key;

  _JSON_SkipWs(r);
  c := _JSON_Next(r);

  if c = 110 then          # null or nan
    next := _JSON_Next(r);
    if next = 117 and _JSON_Match(r, "ll") then
      return fail;
    elif next = 97 and _JSON_Match(r, "n") then
      return Float("nan");
    fi;
    _JSON_SyntaxError(r);

  elif c = 78 then         # NaN
    if _JSON_Match(r, "aN") then
      return Float("nan");
    fi;
    _JSON_SyntaxError(r);

  elif c = 105 then        # inf
    if _JSON_Match(r, "nf") then
      return Float("inf");
    fi;
    _JSON_SyntaxError(r);

  elif c = 73 then         # Infinity
    if _JSON_Match(r, "nfinity") then
      return Float("inf");
    fi;
    _JSON_SyntaxError(r);

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
    if depth = _JSON_MAX_DEPTH then
      ErrorNoReturn("JSON input nested more than 1024 levels deep");
    fi;
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
    if depth = _JSON_MAX_DEPTH then
      ErrorNoReturn("JSON input nested more than 1024 levels deep");
    fi;
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
      res.(key) := _JSON_ParseValue(r, depth + 1);
    until not _JSON_Expect(r, 44);
    if not _JSON_Expect(r, 125) then
      _JSON_SyntaxError(r);
    fi;
    return res;

  elif c = 45 then
    next := _JSON_Next(r);
    if next = 73 and _JSON_Match(r, "nfinity") then
      return Float("-inf");
    elif next = 105 and _JSON_Match(r, "nf") then
      return Float("-inf");
    fi;
    _JSON_Unget(r);
    return _JSON_ParseNumber(r, "-");

  elif c >= 48 and c <= 57 then
    _JSON_Unget(r);
    return _JSON_ParseNumber(r, "");
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
  return rec( isStream := false, buf := str, marks := marks,
              pos := 1, maxpos := 1, eofread := false );
end );

BindGlobal( "_JSON_PureStringToGap", function(str)
  local r, val, i, c;

  if not IsString(str) then
    ErrorNoReturn("Input to JsonToGap must be a string");
  fi;
  if not IsStringRep(str) then
    str := CopyToStringRep(str);
  fi;

  r := _JSON_StringReader(str);
  val := _JSON_ParseValue(r, 0);

  # nothing but whitespace may follow
  for i in [ r.pos .. Length(str) ] do
    c := str[i];
    if not c in " \t\n\013\014\r" then
      ErrorNoReturn("Unexpected non-whitespace after JSON value at byte ", i);
    fi;
  od;

  return val;
end );

BindGlobal( "_JSON_StreamReader", function(stream)
  return rec( isStream := true, stream := stream, lookahead := fail,
              last := fail, line := 1, eofread := false );
end );

BindGlobal( "_JSON_PureStreamToGap", function(stream)
  local r, val;
  r := _JSON_StreamReader(stream);
  # unlike the string case there is no check for trailing garbage: a stream
  # may hold several values in a row
  val := _JSON_ParseValue(r, 0);
  return val;
end );
