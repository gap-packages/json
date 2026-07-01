/*
 * json: Reading and Writing JSON
 */

#include "gap_all.h" // GAP headers

#include "gap-functions.h"

#include "picojson/picojson.h"
#include "picojson/gap-traits.h"

#include <cstdlib>
#include <cstring>

static Obj _GapToJsonStreamInternal;
static Obj _JSON_ObjToString;

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
        const char* c_str = v.get<std::string>().c_str();
        Int len = v.get<std::string>().size();
        str = NEW_STRING(len);
        memcpy(CHARS_STRING(str), c_str, len);
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

// Does <param> (a string, possibly not in string rep) contain any character
// that JSON string output must escape or re-encode?
static Int jsonNeedsEscaping(Obj param, Int lenString)
{
    for (Int i = 1; i <= lenString; ++i) {
        Obj gapchar = ELMW_LIST(param, i);
        UChar u = *((UChar*)ADDR_OBJ(gapchar));
        switch(u)
        {
            case '\\': case '"': case '/': case '\b':
            case '\t': case '\n': case '\f': case '\r':
                return 1;
            default:
                if (u < ' ' || u >= 128)
                    return 1;
        }
    }
    return 0;
}

static Obj FuncJSON_ESCAPE_STRING(Obj self, Obj param)
{
    if(!IS_STRING(param))
    {
        ErrorQuit("Input to JsonEscapeString must be a string", 0, 0);
    }

    Int lenString = LEN_LIST(param);

    if (jsonNeedsEscaping(param, lenString) == 0)
        return param;

    // Massively over-long string
    Obj     copy = NEW_STRING(lenString * 6 + 7);
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
                    snprintf((char*)out,7, "\\u%04X",(unsigned)u);
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

static Obj FuncGAP_LIST_TO_JSON_STRING(Obj self, Obj string, Obj stream, Obj list) {
    RequireDenseList("list", list);
    Int len = LEN_LIST(list);
    char buf[50] = {};

    // Call this at the start
    ConvString(string);
    AppendCStr(string, "[", 1);
    for(int i = 1; i <= len; ++i) {
        if(i != 1) {
            AppendCStr(string, ",", 1);
        }
        Obj val = ELM_LIST(list, i);
        if(IS_INTOBJ(val)) {
            snprintf(buf, sizeof(buf), "%ld", INT_INTOBJ(val));
            AppendCStr(string, buf, strlen(buf));
        } else if(IS_LIST(val) && !(IS_STRING(val))) {
            FuncGAP_LIST_TO_JSON_STRING(self, string, stream, val);
        } else {
            CALL_2ARGS(_GapToJsonStreamInternal, stream, val);
            // Convert back in case this call modified the string
            ConvString(string);
        }
    }
    AppendCStr(string, "]", 1);

    return 0;
}

/******************************************************************************
** Direct-to-string JSON serialiser used by GapToJsonString.
**
** GapToJsonString owns its output string, so instead of writing through an
** OutputTextString + AppendCStr we manage the string as a raw buffer: we
** over-allocate, write directly, and shrink to the exact length at the end.
**
** GC discipline: a raw pointer into a GAP string bag is invalidated by any
** allocation, so we never *store* one. The buffer state is the string bag
** handle (stable across GC) plus the length and capacity as plain integers
** (GC-immune). Every write primitive calls jbuf_ensure first, then fetches
** CHARS_STRING(str) freshly and writes with no allocation in between. This
** means callers may allocate/GC freely between primitives (e.g. the fallback
** below) with nothing to re-derive.
******************************************************************************/

struct JBuf {
    Obj    str;    // the growing GAP string bag (handle stable across GC)
    size_t len;    // bytes written so far
    size_t cap;    // capacity in bytes (== the length passed to GROW_STRING)
};

// Ensure room for `need` more bytes. May allocate (and GC); callers must hold
// no raw string pointer across this call, only the JBuf.
static inline void jbuf_ensure(JBuf * b, size_t need)
{
    if (b->cap - b->len < need) {
        size_t newcap = b->cap ? b->cap : 256;
        while (newcap - b->len < need)
            newcap *= 2;
        GROW_STRING(b->str, newcap);
        b->cap = newcap;
    }
}

static inline void jbuf_putc(JBuf * b, char c)
{
    jbuf_ensure(b, 1);
    CHARS_STRING(b->str)[b->len++] = (UChar)c;
}

static inline void jbuf_putlit(JBuf * b, const char * s, size_t n)
{
    jbuf_ensure(b, n);
    memcpy(CHARS_STRING(b->str) + b->len, s, n);
    b->len += n;
}

// Append <str> (must be in string rep) as a quoted, escaped JSON string.
static void jbuf_json_string(JBuf * b, Obj str)
{
    Int len = LEN_LIST(str);

    if (jsonNeedsEscaping(str, len) == 0) {
        // No escaping needed: quote + raw bytes. Fetch both string pointers
        // *after* jbuf_ensure, in the same no-allocation region.
        jbuf_ensure(b, (size_t)len + 2);
        UChar * out = CHARS_STRING(b->str) + b->len;
        *out++ = '"';
        memcpy(out, CONST_CSTR_STRING(str), len);
        out += len;
        *out++ = '"';
        b->len += (size_t)len + 2;
        return;
    }

    // Worst case is 6 bytes per input byte (\uXXXX). Reserve once so the walk
    // below allocates nothing; base/out stay valid throughout.
    jbuf_ensure(b, (size_t)len * 6 + 2);
    UChar * base = CHARS_STRING(b->str);
    UChar * out = base + b->len;
    *out++ = '"';
    Int i = 1;
    while (i <= len) {
        Int u = getUTF8Char(str, &i);
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
                    snprintf((char*)out, 7, "\\u%04X", (unsigned)u);
                    out += 6;
                }
                else
                {
                    out = outputUnicodeChar(out, u);
                }
        }
    }
    *out++ = '"';
    b->len = out - base;
}

// Record fields sorted by name, for byte-stable output (matches Set(RecNames)).
struct JsonFieldRef {
    const UChar * name;
    UInt          len;
    UInt          pos;
};

static int jsonFieldRefCmp(const void * a, const void * b)
{
    const JsonFieldRef * fa = (const JsonFieldRef *)a;
    const JsonFieldRef * fb = (const JsonFieldRef *)b;
    UInt m = fa->len < fb->len ? fa->len : fb->len;
    int  c = memcmp(fa->name, fb->name, m);
    if (c != 0)
        return c;
    if (fa->len != fb->len)
        return fa->len < fb->len ? -1 : 1;
    return 0;
}

static void serialiseJson(JBuf * b, Obj obj);

static void serialiseJsonRecord(JBuf * b, Obj rec)
{
    // Sort (and de-duplicate) the record's components, exactly as RecNames
    // does. Afterwards all stored rnams are negated (the "sorted" marker), so
    // the true rnam is -GET_RNAM_PREC(...). Without this, freshly built records
    // can hold positive/unsorted rnams and NAME_RNAM indexes out of range.
    SortPRecRNam(rec);
    UInt n = LEN_PREC(rec);
    jbuf_putc(b, '{');
    if (n > 0) {
        JsonFieldRef * fields = (JsonFieldRef *)malloc(n * sizeof(JsonFieldRef));
        for (UInt i = 1; i <= n; ++i) {
            Obj nm = NAME_RNAM(-GET_RNAM_PREC(rec, i));
            fields[i - 1].name = CONST_CHARS_STRING(nm);
            fields[i - 1].len = GET_LEN_STRING(nm);
            fields[i - 1].pos = i;
        }
        // No GAP allocation happens during the sort, so the cached name
        // pointers stay valid here.
        qsort(fields, n, sizeof(JsonFieldRef), jsonFieldRefCmp);
        for (UInt k = 0; k < n; ++k) {
            if (k != 0)
                jbuf_putc(b, ',');
            // Re-fetch the name Obj fresh: emitting the previous field may have
            // grown the buffer (GC), invalidating cached name pointers.
            jbuf_json_string(b, NAME_RNAM(-GET_RNAM_PREC(rec, fields[k].pos)));
            jbuf_putlit(b, " : ", 3);
            serialiseJson(b, GET_ELM_PREC(rec, fields[k].pos));
        }
        free(fields);
    }
    jbuf_putc(b, '}');
}

static void serialiseJson(JBuf * b, Obj obj)
{
    if (IS_INTOBJ(obj)) {
        char tmp[32];
        int  m = snprintf(tmp, sizeof(tmp), "%ld", (long)INT_INTOBJ(obj));
        jbuf_putlit(b, tmp, m);
        return;
    }
    if (obj == True)  { jbuf_putlit(b, "true", 4);  return; }
    if (obj == False) { jbuf_putlit(b, "false", 5); return; }
    if (obj == Fail)  { jbuf_putlit(b, "null", 4);  return; }

    if (IS_STRING(obj)) {
        Int len = LEN_LIST(obj);
        if (len == 0) {
            // Matches the GAP IsString method: "" for string rep, [] otherwise.
            if (IS_STRING_REP(obj))
                jbuf_putlit(b, "\"\"", 2);
            else
                jbuf_putlit(b, "[]", 2);
            return;
        }
        if (!IS_STRING_REP(obj))
            obj = CopyToStringRep(obj);   // allocates; obj is local, safe after
        jbuf_json_string(b, obj);
        return;
    }

    if (IS_LIST(obj)) {
        RequireDenseList("GapToJsonString", obj);
        Int len = LEN_LIST(obj);
        jbuf_putc(b, '[');
        for (Int i = 1; i <= len; ++i) {
            if (i != 1)
                jbuf_putc(b, ',');
            serialiseJson(b, ELMW_LIST(obj, i));
        }
        jbuf_putc(b, ']');
        return;
    }

    if (IS_PREC(obj)) {
        serialiseJsonRecord(b, obj);
        return;
    }

    // Fallback for everything else (floats, large integers, component objects,
    // user-installed methods): let the GAP operation produce the JSON string,
    // then copy it in. The call may GC, but we hold only the JBuf (bag handle
    // + integer offsets), so there is nothing to re-derive.
    {
        Obj s = CALL_1ARGS(_JSON_ObjToString, obj);
        Int slen = GET_LEN_STRING(s);
        jbuf_ensure(b, slen);   // may move the bags; fetch both pointers after
        memcpy(CHARS_STRING(b->str) + b->len, CONST_CSTR_STRING(s), slen);
        b->len += slen;
    }
}

static Obj FuncGAP_OBJ_TO_JSON_STRING(Obj self, Obj obj)
{
    JBuf b;
    b.str = NEW_STRING(256);
    b.len = 0;
    b.cap = 256;

    serialiseJson(&b, obj);

    SET_LEN_STRING(b.str, b.len);
    SHRINK_STRING(b.str);
    return b.str;
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

static Obj FuncJSON_STREAM_TO_GAP(Obj self, Obj stream)
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

// WARNING: This class is only complete enough to work with
// picojson's iterator support.
struct GapStringToInputIterator {
    Obj    obj;
    size_t pos;

    GapStringToInputIterator() : obj(0), pos(0)
    {
    }

    GapStringToInputIterator(Obj s, size_t startpos = 0)
        : obj(s), pos(startpos)
    {
    }

    GapStringToInputIterator(const GapStringToInputIterator & gstii)
        : obj(gstii.obj), pos(gstii.pos)
    {
    }

    char operator*()
    {
        return CSTR_STRING(obj)[pos];
    }

    void operator++()
    {
        pos++;
    }

    friend bool operator==(GapStringToInputIterator & lhs,
                           GapStringToInputIterator & rhs)
    {
        return (lhs.pos == rhs.pos);
    }
};


static GapStringToInputIterator endGapStringIterator(Obj obj)
{
    GapStringToInputIterator g(obj, GET_LEN_STRING(obj));
    return g;
}

static Obj FuncJSON_STRING_TO_GAP(Obj self, Obj param)
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
    
    
    typedef picojson::value_t<gap_type_traits> gmp_value;
    
    gmp_value v;
    
    std::string err;
    bool ungotc_check = false;
    GapStringToInputIterator endparse = picojson::parse(
        v, GapStringToInputIterator(real_string),
        endGapStringIterator(real_string), &err, &ungotc_check);

    //    char* res = picojson::parse(v, ptr, ptrend, &err, &ungotc_check);
    if (! err.empty()) {
      ErrorQuit(err.c_str(), 0, 0);
      return Fail;
    }

    // Check end of string
    const char * ptr = CSTR_STRING(real_string);
    const char * ptrend = ptr + strlen(ptr);

    // Extra position in the string
    const char * res = ptr + endparse.pos;

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

// Table of functions to export
static StructGVarFunc GVarFuncs [] = {
    GVAR_FUNC_1ARGS(JSON_STRING_TO_GAP, string),
    GVAR_FUNC_1ARGS(JSON_ESCAPE_STRING, string),
    GVAR_FUNC_1ARGS(JSON_STREAM_TO_GAP, string),
    GVAR_FUNC_3ARGS(GAP_LIST_TO_JSON_STRING, string, stream, list),
    GVAR_FUNC_1ARGS(GAP_OBJ_TO_JSON_STRING, obj),

	{ 0 } /* Finish with an empty entry */

};

/******************************************************************************
*F  InitKernel( <module> )  . . . . . . . . initialise kernel data structures
*/
static Int InitKernel( StructInitInfo *module )
{
    /* init filters and functions                                          */
    InitHdlrFuncsFromTable( GVarFuncs );

    ImportGVarFromLibrary("_GapToJsonStreamInternal", &_GapToJsonStreamInternal);
    ImportGVarFromLibrary("_JSON_ObjToString", &_JSON_ObjToString);

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
