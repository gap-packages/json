static Obj ReadByteFunction;
static Obj AddGAPObjToCacheFunction;
static Obj ClearGAPCacheFunction;

static Obj callGAPFunction(Obj fun, Obj arg)
{
  typedef Obj(*F)(Obj,Obj);
  return reinterpret_cast<F>(HDLR_FUNC(fun,1))(fun, arg);
}

static Obj callGAPFunction(Obj fun)
{
  typedef Obj(*F)(Obj);
  return reinterpret_cast<F>(HDLR_FUNC(fun,0))(fun);
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
