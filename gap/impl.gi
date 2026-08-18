#############################################################################
##
#W  impl.gi                  json Package
##
##  The registry of JSON implementations, and the selection of the one to use.
##  This file must be read last: it refers to functions installed by all the
##  other files.
##

# The kernel functions are looked up by name rather than referenced directly,
# so that reading this file produces no warnings when the kernel extension is
# absent and the globals are therefore unbound.
BindGlobal( "_JSON_IMPLEMENTATIONS", rec(
  gap := rec(
    name         := "gap",
    StringToGap  := _JSON_PureStringToGap,
    StreamToGap  := _JSON_PureStreamToGap,
    EscapeString := _JSON_PureEscapeString,
    ListToString := fail,  # kernel-only optimisation, see gap/json.gi
  ) ) );

if JSON_KERNEL_AVAILABLE then
  _JSON_IMPLEMENTATIONS.kernel := rec(
    name         := "kernel",
    StringToGap  := ValueGlobal("JSON_STRING_TO_GAP"),
    StreamToGap  := ValueGlobal("JSON_STREAM_TO_GAP"),
    EscapeString := ValueGlobal("JSON_ESCAPE_STRING"),
    ListToString := ValueGlobal("GAP_LIST_TO_JSON_STRING"),
  );
fi;

InstallGlobalFunction(JsonAvailableImplementations,
function()
  if JSON_KERNEL_AVAILABLE then
    return [ "kernel", "gap" ];
  fi;
  return [ "gap" ];
end );

InstallGlobalFunction(JsonImplementation,
function()
  return _JSON_ACTIVE.name;
end );

InstallGlobalFunction(SetJsonImplementation,
function(name)
  local old, impl, comp;
  if not name in JsonAvailableImplementations() then
    # the text deliberately does not list the implementations, which depend
    # on whether the kernel extension was built
    ErrorNoReturn("<name> must be one of JsonAvailableImplementations()");
  fi;
  old := _JSON_ACTIVE.name;
  impl := _JSON_IMPLEMENTATIONS.(name);
  # mutate in place; other code holds on to _JSON_ACTIVE itself
  for comp in RecNames(impl) do
    _JSON_ACTIVE.(comp) := impl.(comp);
  od;
  return old;
end );

SetJsonImplementation( JsonAvailableImplementations()[1] );
