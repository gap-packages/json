
InstallMethod(GapToJsonStream, [IsOutputStream, IsInt],
function(o, d)
  PrintTo(o, String(d));
end );

InstallMethod(GapToJsonStream, [IsOutputStream, IsFloat],
function(o, d)
  PrintTo(o, String(d));
end );

InstallMethod(GapToJsonStream, [IsOutputStream, IsBool],
function(o, b)
  if b = true then
    PrintTo(o, "true");
  elif b = false then
    PrintTo(o, "false");
  else
    Error("Invalid Boolean");
  fi;
end );
      
InstallMethod(GapToJsonStream, [IsOutputStream, IsString],
function(o, s)
  if IsEmpty(s) then
    if IsStringRep(s) then
      PrintTo(o, "\"\"");
    else
      PrintTo(o, "[]");
    fi;
  else
    PrintTo(o, "\"", JSON_ESCAPE_STRING(s), "\"");
  fi;
end );

InstallMethod(GapToJsonStream, [IsOutputStream, IsList],
function(o, l)
  local i, first;
  first := true;
  PrintTo(o, "[");
  for i in l do
    if first then
      first := false;
    else
      PrintTo(o, ",");
    fi;
    GapToJsonStream(o, i);
  od;
  PrintTo(o, "]");
end );

InstallMethod(GapToJsonStream, [IsOutputStream, IsRecord],
function(o, r)
  local i, first;
  first := true;
  PrintTo(o, "{");
  for i in RecNames(r) do
    if first then
      first := false;
    else
      PrintTo(o, ",");
    fi;
    GapToJsonStream(o, i);
    PrintTo(o, " :", r.(i));
  od;
  PrintTo(o, "}");
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
  