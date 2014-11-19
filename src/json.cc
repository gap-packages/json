/*
 * json: Reading and Writing JSON
 */

#include "src/compiled.h"          /* GAP headers                */

#include "picojson/picojson.h"
#include "picojson/gap-traits.h"

typedef picojson::value_t<gap_type_traits> gmp_value;

Obj TestCommand(Obj self)
{
    return INTOBJ_INT(42);
}

Obj JsonToGap(const gmp_value& v)
{
    if (v.is<picojson::null>()) {
      return Fail;
    } else if (v.is<bool>()) {
        if(v.get<bool>())
            return True;
        else
            return False;
    } else if (v.is<gap_val>()) {
        return v.get<gap_val>().obj;
    } else if (v.is<std::string>()) {
        Obj str;
        const Char* c_str = v.get<std::string>().c_str();
        Int len = v.get<std::string>().size();
        C_NEW_STRING(str, len, c_str);
        return str;
    } else if (v.is<gmp_value::array>()) {
        const gmp_value::array& a = v.get<gmp_value::array>();
        Obj list = NEW_PLIST(T_PLIST_DENSE, a.size());
        SET_LEN_PLIST(list, a.size());
        for(int i = 1; i <= a.size(); ++i)
        {
            Obj val = JsonToGap(a[i-1]);
            SET_ELM_PLIST(list, i, val);
            CHANGED_BAG(list);
        }
        return list;
    } else if (v.is<gmp_value::object>()) {
        const gmp_value::object& o = v.get<gmp_value::object>();
        Obj rec = NEW_PREC(0);
        for (gmp_value::object::const_iterator i = o.begin(); i != o.end(); ++i) {
            Obj res = JsonToGap(i->second);
            AssPRec(rec, RNamName(i->first.c_str()), res);
            CHANGED_BAG(rec);
        }
        return rec;
    }
    return Fail;
}

// Add function prototype missing from string.h
extern Obj CopyToStringRep(Obj string);

Obj JSON_TO_GAP(Obj self, Obj param)
{
    if(!IS_STRING(param))
    {
        ErrorQuit("Input to JsonToGap must be a string", 0, 0);
    }
    
    Obj real_string = param;
    
    if(!IS_STRING_REP(param))
    {
        real_string = CopyToStringRep(param);
    }
    
    Char* ptr = CSTR_STRING(real_string);
    
    typedef picojson::value_t<gap_type_traits> gmp_value;
    
    gmp_value v;
    
    std::string err;
    picojson::parse(v, ptr, ptr + strlen(ptr), &err);
    if (! err.empty()) {
      std::cerr << err << std::endl;
      return Fail;
    }
    
    return JsonToGap(v);
}

typedef Obj (* GVarFunc)(/*arguments*/);

#define GVAR_FUNC_TABLE_ENTRY(srcfile, name, nparam, params) \
  {#name, nparam, \
   params, \
   (GVarFunc)name, \
   srcfile ":Func" #name }

// Table of functions to export
static StructGVarFunc GVarFuncs [] = {
    GVAR_FUNC_TABLE_ENTRY("json.c", TestCommand, 0, ""),
    GVAR_FUNC_TABLE_ENTRY("json.c", JSON_TO_GAP, 1, "string"),

	{ 0 } /* Finish with an empty entry */

};

/******************************************************************************
*F  InitKernel( <module> )  . . . . . . . . initialise kernel data structures
*/
static Int InitKernel( StructInitInfo *module )
{
    /* init filters and functions                                          */
    InitHdlrFuncsFromTable( GVarFuncs );

    /* return success                                                      */
    return 0;
}

/******************************************************************************
*F  InitLibrary( <module> ) . . . . . . .  initialise library data structures
*/
static Int InitLibrary( StructInitInfo *module )
{
    /* init filters and functions */
    InitGVarFuncsFromTable( GVarFuncs );

    /* return success                                                      */
    return 0;
}

/******************************************************************************
*F  InitInfopl()  . . . . . . . . . . . . . . . . . table of init functions
*/
static StructInitInfo module = {
 /* type        = */ MODULE_DYNAMIC,
 /* name        = */ "json",
 /* revision_c  = */ 0,
 /* revision_h  = */ 0,
 /* version     = */ 0,
 /* crc         = */ 0,
 /* initKernel  = */ InitKernel,
 /* initLibrary = */ InitLibrary,
 /* checkInit   = */ 0,
 /* preSave     = */ 0,
 /* postSave    = */ 0,
 /* postRestore = */ 0
};

extern "C"
StructInitInfo * Init__Dynamic ( void )
{
  return &module;
}
