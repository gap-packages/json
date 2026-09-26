#############################################################################
##
##
#W  json.gi                  json Package                Chris Jefferson
##
##  Installation file for functions of the json package.
##
#Y  Copyright (C) 2013-2014 University of St. Andrews, North Haugh,
#Y                          St. Andrews, Fife KY16 9SS, Scotland
##

####
# Functions and variables beginning '_JSON_' are only called
# from C++ by the json package.
####


_JSON_Globals := [];

_JSON_addRef := function(obj)
  Add(_JSON_Globals, obj);
end;

_JSON_clearRefs := function()
  _JSON_Globals := [];
end;

# Called from C by GAP_OBJ_TO_JSON_STRING to serialise objects it does not
# handle directly (floats, large integers, component objects, and any types
# with a user-installed _GapToJsonStreamInternal method).
_JSON_ObjToString := function(obj)
  local str, s;
  str := "";
  s := OutputTextString(str, true);
  SetPrintFormattingStatus(s, false);
  _GapToJsonStreamInternal(s, obj);
  return str;
end;

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsInt],
function(o, d)
  WriteAll(o, STRING_INT(d));
end );

_JSON_IsValidNumberString := function(s)
  local i, len, isDigit;
  i := 1;
  len := Length(s);
  isDigit := c -> '0' <= c and c <= '9';

  if i <= len and s[i] = '-' then
    i := i + 1;
  fi;
  if i > len then
    return false;
  elif s[i] = '0' then
    i := i + 1;
  elif '1' <= s[i] and s[i] <= '9' then
    repeat
      i := i + 1;
    until i > len or not isDigit(s[i]);
  else
    return false;
  fi;

  if i <= len and s[i] = '.' then
    i := i + 1;
    if i > len or not isDigit(s[i]) then
      return false;
    fi;
    repeat
      i := i + 1;
    until i > len or not isDigit(s[i]);
  fi;

  if i <= len and s[i] in "eE" then
    i := i + 1;
    if i <= len and s[i] in "+-" then
      i := i + 1;
    fi;
    if i > len or not isDigit(s[i]) then
      return false;
    fi;
    repeat
      i := i + 1;
    until i > len or not isDigit(s[i]);
  fi;

  return i > len;
end;

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsFloat],
function(o, d)
  local dot, s;
  if IsNaN(d) then
    WriteAll(o, "NaN");
    return;
  elif not IsFinite(d) then
    if d > 0.0 then
      WriteAll(o, "Infinity");
    else
      WriteAll(o, "-Infinity");
    fi;
    return;
  fi;

  s := String(d);
  dot := Position(s, '.');
  if dot = Length(s) then
    s := Concatenation(s, "0");
  elif dot <> fail and s[dot + 1] in "eE" then
    s := Concatenation(s{[1..dot]}, "0", s{[dot + 1..Length(s)]});
  fi;

  if not _JSON_IsValidNumberString(s) then
    ErrorNoReturn("cannot encode float as JSON: ", s);
  fi;
  WriteAll(o, s);
end );

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsBool],
function(o, b)
  # GAP's `fail` is the third value satisfying IsBool. JsonStringToGap
  # already deserialises JSON `null` as `fail`; round-trip the other way
  # so the encode/decode pair is symmetric.
  if b = true then
    WriteAll(o, "true");
  elif b = false then
    WriteAll(o, "false");
  else
    WriteAll(o, "null");
  fi;
end );

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsString],
function(o, s)
  if IsEmpty(s) then
    if IsStringRep(s) then
      WriteAll(o, "\"\"");
    else
      WriteAll(o, "[]");
    fi;
  else
    WriteAll(o, "\"");
    WriteAll(o, JSON_ESCAPE_STRING(s));
    WriteAll(o, "\"");
  fi;
end );

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsList],
function(o, l)
  local i, first;
  if IsOutputTextStringRep(o) and IsStringRep(o![1]) then
    GAP_LIST_TO_JSON_STRING(o![1], o, l);
  else
    first := true;
    WriteAll(o, "[");
    for i in l do
      if first then
        first := false;
      else
        WriteAll(o, ",");
      fi;
      _GapToJsonStreamInternal(o, i);
    od;
    WriteAll(o, "]");
  fi;
end );

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsRecord],
function(o, r)
  local i, first;
  first := true;
  WriteAll(o, "{");
  for i in Set(RecNames(r)) do # sort for output stability across GAP sessions
    if first then
      first := false;
    else
      WriteAll(o, ",");
    fi;
    _GapToJsonStreamInternal(o, i); # a string or small integer
    WriteAll(o, " : ");
    _GapToJsonStreamInternal(o, r.(i)); # an arbitrary GAP object
  od;
  WriteAll(o, "}");
end );

InstallGlobalFunction(GapToJsonStream,
function(stream, obj)
  local streamformat;
  streamformat := PrintFormattingStatus(stream);
  SetPrintFormattingStatus(stream, false);
  _GapToJsonStreamInternal(stream, obj);
  SetPrintFormattingStatus(stream, streamformat);
end );


InstallGlobalFunction(GapToJsonString,
function(obj)
  return GAP_OBJ_TO_JSON_STRING(obj);
end );

InstallGlobalFunction(JsonStringToGap,
function(str)
  return JSON_STRING_TO_GAP(str);
end );

InstallGlobalFunction(JsonStreamToGap,
function(str)
  return JSON_STREAM_TO_GAP(str);
end );
