#############################################################################
##
#W  impl.gi                  json Package
##
##  Select the kernel implementation when available, otherwise the pure GAP
##  fallback. The GAP output backend reuses _GapToJsonStreamInternal.
##

_JSON_BACKEND.StringToGap  := _JSON_PureStringToGap;
_JSON_BACKEND.StreamToGap  := _JSON_PureStreamToGap;
_JSON_BACKEND.ObjToString  := _JSON_ObjToString;
_JSON_BACKEND.EscapeString := _JSON_PureEscapeString;
_JSON_BACKEND.ListToString := fail;

if _JSON_KERNEL_AVAILABLE then
  _JSON_BACKEND.StringToGap  := ValueGlobal("JSON_STRING_TO_GAP");
  _JSON_BACKEND.StreamToGap  := ValueGlobal("JSON_STREAM_TO_GAP");
  _JSON_BACKEND.ObjToString  := ValueGlobal("GAP_OBJ_TO_JSON_STRING");
  _JSON_BACKEND.EscapeString := ValueGlobal("JSON_ESCAPE_STRING");
  _JSON_BACKEND.ListToString := ValueGlobal("GAP_LIST_TO_JSON_STRING");
fi;
