/*
 * json: Reading and Writing JSON
 */

#include "src/compiled.h"          /* GAP headers                */
#include "gap-functions.h"

#include "picojson/picojson.h"
#include "picojson/gap-traits.h"

typedef picojson::value_t<gap_type_traits> gmp_value;

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


Obj JSON_ESCAPE_STRING(Obj self, Obj param)
{
    if(!IS_STRING(param))
    {
        ErrorQuit("Input to JsonEscapeString must be a string", 0, 0);
    }
 
    Int escapeCount = 0;
    Int lenString = LEN_LIST(param);
    for(int i = 1; i <= lenString; ++i)
    {
        Obj gapchar = ELMW_LIST(param, i);
        UChar u = *((UChar*)ADDR_OBJ(gapchar));
        switch(u)
        {
            case '\\': case '"': case '/': case '\b':
            case '\t': case '\n': case '\f': case '\r':
                escapeCount++;
                break;
            default:
                if(u < ' ')
                    escapeCount+=5;
        }
    }
    
    if(escapeCount == 0)
        return param;
    
    Obj copy = NEW_STRING(lenString + escapeCount);
    UChar* out = CHARS_STRING(copy);
    for(int i = 1; i <= lenString; ++i)
    {
        Obj gapchar = ELMW_LIST(param, i);
        UChar u = *((UChar*)ADDR_OBJ(gapchar));
        switch(u)
        {
            case '\\': case '"': case '/':
                out[0] = '\\';
                out[1] = u;
                out += 2;
                break;
#define ESCAPE_CASE(x,y) case x: out[0] = '\\'; out[1] = y; out += 2; break;
            ESCAPE_CASE('\b', 'b');
            ESCAPE_CASE('\t', 't');
            ESCAPE_CASE('\n', 'n');
            ESCAPE_CASE('\f', 'f');
            ESCAPE_CASE('\r', 'r');
#undef ESCAPE_CASE
            default:
                if(u < ' ')
                {
                    sprintf((char*)out,"\\u%04X",(unsigned)u);
                    out += 6;
                }
                else
                {
                    out[0] = u;
                    out++;
                }
        }
    }
    *out = '\0';
    return copy;
}



// WARNING: This class is only complete enough to work with
// picojson's iterator support.
struct GapStreamToInputIterator
{
  Obj stream;
  enum State {
    notread, failed, cached
  };
  State state;
  char store;
  
  GapStreamToInputIterator()
  : stream(0), state(notread), store(0)
  { }
  
  GapStreamToInputIterator(Obj s)
  : stream(s), state(notread), store(0)
  { }
  
  GapStreamToInputIterator(const GapStreamToInputIterator& gstii)
  : stream(gstii.stream), state(gstii.state), store(gstii.store)
  { } 

  char operator*()
  {
    if(state == cached)
      return store;
    
    if(state == failed)
      return 0;

    Obj val = callGAPFunction(ReadByteFunction, stream);
    if(val == Fail)
    {
      state = failed;
      return 0;
    }
    else
    {
      state = cached;
      store = INT_INTOBJ(val);
      return store;
    }
  }
  
  void operator++()
  {
    if(state == failed)
      return;
    
    // skip character
    if(state == notread)
    {
      *(*this);
    }
    
    state = notread;
  }
  
  friend bool operator==(GapStreamToInputIterator& lhs, GapStreamToInputIterator& rhs)
  { return (lhs.state == failed) == (rhs.state == failed); }
  
};
      
static GapStreamToInputIterator endGapStreamIterator()
{
  GapStreamToInputIterator g;
  g.state = GapStreamToInputIterator::failed;
  return g;
}

// making an object of this type will ensure when the scope is exited
// we clean up any GAP objects we cached
struct CleanupCacheGuard
{
  ~CleanupCacheGuard()
    { callGAPFunction(ClearGAPCacheFunction); }
};

Obj JSON_STREAM_TO_GAP(Obj self, Obj stream)
{
  JSON_setupGAPFunctions();
  CleanupCacheGuard ccg;
  
  typedef picojson::value_t<gap_type_traits> gmp_value;
  
  gmp_value v;
  
  std::string err;
  bool ungotc_check = false;
  picojson::parse(v, GapStreamToInputIterator(stream), endGapStreamIterator(), &err, &ungotc_check);
  if (! err.empty()) {
    ErrorQuit(err.c_str(), 0, 0);
    return Fail;
  }

  return JsonToGap(v);
}
  
Obj JSON_STRING_TO_GAP(Obj self, Obj param)
{
    JSON_setupGAPFunctions();
    CleanupCacheGuard ccg;

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
    Char* ptrend = ptr + strlen(ptr);
    
    typedef picojson::value_t<gap_type_traits> gmp_value;
    
    gmp_value v;
    
    std::string err;
    bool ungotc_check = false;
    Char* res = picojson::parse(v, ptr, ptrend, &err, &ungotc_check);
    if (! err.empty()) {
      ErrorQuit(err.c_str(), 0, 0);
      return Fail;
    }

    // Woo, this is horrible. The parser steps one character too far
    // if the only thing parsed is a number. So step back.
    if(ungotc_check) {
      res--;
    }

    for(; res != ptrend; res++)
    {
      if(!(isspace(*res)) && *res)
      {
        ErrorMayQuit("Failed to parse end of string: '%s'",(Int)res,0);
        return Fail;
      }
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
    GVAR_FUNC_TABLE_ENTRY("json.c", JSON_STRING_TO_GAP, 1, "string"),
    GVAR_FUNC_TABLE_ENTRY("json.c", JSON_ESCAPE_STRING, 1, "string"),
    GVAR_FUNC_TABLE_ENTRY("json.c", JSON_STREAM_TO_GAP, 1, "string"),
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
