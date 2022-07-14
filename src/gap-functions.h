static Obj ReadByteFunction;
static Obj AddGAPObjToCacheFunction;
static Obj ClearGAPCacheFunction;

static Obj callGAPFunction(Obj fun, Obj arg)
{
  return CALL_1ARGS(fun, arg);
}

static Obj callGAPFunction(Obj fun)
{
  return CALL_0ARGS(fun);
}

static void JSON_setupGAPFunctions()
{
  if(!ReadByteFunction)
  {
    ReadByteFunction = VAL_GVAR(GVarName("ReadByte"));
    AddGAPObjToCacheFunction = VAL_GVAR(GVarName("_JSON_addRef"));
    ClearGAPCacheFunction = VAL_GVAR(GVarName("_JSON_clearRefs"));
  }
}
