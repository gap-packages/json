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

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsInt],
function(o, d)
  WriteAll(o, STRING_INT(d));
end );

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsFloat],
function(o, d)
  WriteAll(o, String(d));
end );

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsBool],
function(o, b)
  if b = true then
    WriteAll(o, "true");
  elif b = false then
    WriteAll(o, "false");
  else
    Error("Invalid Boolean");
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
  local str, s;
  str := "";
  s := OutputTextString(str, true);
  SetPrintFormattingStatus(s, false);
  GapToJsonStream(s, obj);
  return str;
end );

InstallGlobalFunction(JsonStringToGap,
function(str)
  return JSON_STRING_TO_GAP(str);
end );

InstallGlobalFunction(JsonStreamToGap,
function(str)
  return JSON_STREAM_TO_GAP(str);
end );
