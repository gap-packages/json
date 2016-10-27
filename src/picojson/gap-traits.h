#include <string>
#include <algorithm>
#include <math.h>


struct gap_val
{
    Obj obj;

    gap_val()
    : obj(0)
    { }
    
    explicit gap_val(Obj o)
    : obj(o)
    { // As we are storing an Obj in a C++ object, we need to make sure
      // it does not get garbage collected
      if(!IS_INTOBJ(o))
        callGAPFunction(AddGAPObjToCacheFunction, o);
    }
    
    bool evaluate_as_boolean() const
    { 
        abort(); // never called
    }
    
    static std::pair<gap_val*, bool> from_str_double(const std::string& s)
    {
        char* endp;
        double f = strtod(s.c_str(), &endp);
        if(endp == s.c_str() + s.size()) {
            return std::make_pair(new gap_val(NEW_MACFLOAT(f)), true);
        }
        return std::make_pair(new gap_val(), false);
    }
    
    static Obj to_gap_int(const char* begin, const char* end)
    {
        bool neg = false;
        if(*begin == '-')
        {
            neg = true;
            begin++;
        }
        else if(*begin == '+')
        {
            begin++;
        }
        if(begin == end)
        {
          return Fail;
        }
        Obj res = INTOBJ_INT(0);
        for(; begin != end; ++begin)
        {
            if(*begin < '0' || *begin > '9')
                return Fail;
            
            Obj prod = ProdInt(res, INTOBJ_INT(10));
            res = SumInt(INTOBJ_INT((*begin - '0')), prod);
        }
        if(neg)
            res = ProdInt(res, INTOBJ_INT(-1));
        return res;
    }
    
    static std::pair<gap_val*, bool> from_str(const std::string& s)
    {
        if(s.find(".") != std::string::npos)
        {
            return from_str_double(s);
        }
        else
        {
            try
            {
                // The following code is just designed to turn any valid
                // json integer into a gmp number.
                int loc = s.find_first_of("eE");
                if(loc == std::string::npos)
                {
                    Obj o = to_gap_int(s.c_str(), s.c_str() + s.size());
                    return std::make_pair(new gap_val(o), o != Fail);
                }
                
                if(s[loc+1] == '-')
                {
                    // back to a double!
                    return from_str_double(s);
                }
                
                Obj arg1 = to_gap_int(s.c_str(), s.c_str() + loc);
               
                Obj arg2 = to_gap_int(s.c_str() + loc + 1, s.c_str() + s.size());
                if(arg1 == Fail || arg2 == Fail) {
                  return std::make_pair(new gap_val(), false);
                }
                Obj retval = ProdInt(arg1, PowInt(INTOBJ_INT(10), arg2));
                return std::make_pair(new gap_val(retval), true);
            }
            catch(std::invalid_argument)
            { return std::make_pair(new gap_val(), false); }
        }
    }
    
    std::string to_str() const
    {
        // not used
        abort();
    }
};


template<typename T>
struct wrap_number_traits {
  typedef T* value_type;
  typedef T return_type;
  static return_type& to_return_type(value_type& t){
    return *t;
  }
  static value_type default_value() { return new T(); }
  static void construct(value_type &slot, value_type n) {
    slot = new T(*n);
  }
  
  static void destruct(value_type &slot) {delete slot; }
  static bool evaluate_as_boolean(value_type n) {
    return n->evaluate_as_boolean();
  }
  static std::pair<value_type, bool> from_str(const std::string& s) {
      return T::from_str(s);
  }

  static std::string to_str(value_type n) {
      return n->to_str();
  }
};

struct gap_type_traits {
  typedef wrap_number_traits<gap_val> number_traits;
};
