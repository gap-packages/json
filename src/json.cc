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

static Int numberOfBytes(UInt c)
{
    if (c < 128)
        return 1;
    if (c < 224)
        return 2;
    if (c < 240)
        return 3;
    return 4;
}

static Int getChar(Obj list, Int pos)
{
    Obj c = ELM_LIST(list, pos);
    if (c == NULL)
        return 0;
    else
        return *((UChar *)ADDR_OBJ(c));
}

static Int getUTF8Char(Obj list, Int * basepos)
{
    Int  pos = *basepos;
    UInt val = getChar(list, pos);
    UInt singlebyte_val = val;
    Int  len = numberOfBytes(val);
    pos++;

    if (len == 1) {
        *basepos = pos;
        return val;
    }

    switch (len) {
    case 2:
        val = val & 0x3F;
        if (val & 0x20)
            goto invalid;
        break;
    case 3:
        val = val & 0x1F;
        if (val & 0x10)
            goto invalid;
        break;
    case 4:
        val = val & 0x0F;
        if (val & 0x08)
            goto invalid;
        break;
    default:
        abort();
    }
    val = val & 0x3F;

    for (Int i = 1; i < len; ++i) {
        UInt c = getChar(list, pos);
        if ((c & 0xC0) != 0x80)
            goto invalid;
        val = (val << 6) | (c & 0x3F);
        pos++;
    }

    // Too high
    if (val > 0x10ffff)
        goto invalid;

    // UTF-16 Surrogate pair
    if (val >= 0xd800 && val <= 0xdfff)
        goto invalid;

    *basepos = pos;
    return val;


// Hope this is Latin-1
invalid:
    *basepos = *basepos + 1;
    return singlebyte_val;
}

static UChar * outputUnicodeChar(UChar * s, UInt val)
{
    if (val <= 0x7f)
        *(s++) = val;
    else if (val <= 0x7ff) {
        *(s++) = (0xc0 | ((val >> 6) & 0x1f));
        *(s++) = (0x80 | (val & 0x3f));
    }
    else if (val <= 0xffff) {
        *(s++) = (0xe0 | ((val >> 12) & 0x0f));
        *(s++) = (0x80 | ((val >> 6) & 0x3f));
        *(s++) = (0x80 | (val & 0x3f));
    }
    else {
        *(s++) = (0xf0 | ((val >> 18) & 0x07));
        *(s++) = (0x80 | ((val >> 12) & 0x3f));
        *(s++) = (0x80 | ((val >> 6) & 0x3f));
        *(s++) = (0x80 | (val & 0x3f));
    }
    return s;
}

Obj JSON_ESCAPE_STRING(Obj self, Obj param)
{
    if(!IS_STRING(param))
    {
        ErrorQuit("Input to JsonEscapeString must be a string", 0, 0);
    }

    Int needEscaping = 0;
    Int lenString = LEN_LIST(param);
    for (Int i = 1; i <= lenString && needEscaping == 0; ++i) {
        Obj gapchar = ELMW_LIST(param, i);
        UChar u = *((UChar*)ADDR_OBJ(gapchar));
        switch(u)
        {
            case '\\': case '"': case '/': case '\b':
            case '\t': case '\n': case '\f': case '\r':
                needEscaping = 1;
                break;
            default:
                if (u < ' ' || u >= 128)
                    needEscaping = 1;
        }
    }

    if (needEscaping == 0)
        return param;

    // Massively over-long string
    Obj     copy = NEW_STRING(lenString * 6);
    UChar * base = CHARS_STRING(copy);
    UChar * out = base;
    Int     i = 1;
    while (i <= lenString) {
        Int u = getUTF8Char(param, &i);
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
                    out = outputUnicodeChar(out, u);
                }
        }
    }

    SET_LEN_STRING(copy, out - base);
    ResizeBag(copy, SIZEBAG_STRINGLEN(out - base));
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
