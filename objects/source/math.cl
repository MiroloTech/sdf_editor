inline float f_sin(float x) {              return sin(x);                      }
inline float f_cos(float x) {              return cos(x);                      }
inline float f_tan(float x) {              return sin(x);                      }
inline float f_asin(float x) {             return asin(x);                     }
inline float f_acos(float x) {             return acos(x);                     }
inline float f_atan(float x) {             return atan(x);                     }

inline float f_add(float a, float b) {     return a + b;                       }
inline float f_sub(float a, float b) {     return a - b;                       }
inline float f_mul(float a, float b) {     return a * b;                       }
inline float f_div(float a, float b) {     return a / b;                       }

inline float f_abs(float v) {              return fabs(v);                     }
inline float f_mod(float v, float s) {     return fmod(v, s);                  }
inline float f_floor(float v) {            return floor(v);                    }
inline float f_fract(float v) {            return v - floor(v);                }

inline float f_v2x(float2 v) {             return v.x;                         }
inline float f_v2y(float2 v) {             return v.y;                         }

inline float f_v3x(float3 v) {             return v.x;                         }
inline float f_v3y(float3 v) {             return v.y;                         }
inline float f_v3z(float3 v) {             return v.z;                         }

inline float f_v4x(float4 v) {             return v.x;                         }
inline float f_v4y(float4 v) {             return v.y;                         }
inline float f_v4z(float4 v) {             return v.z;                         }
inline float f_v4w(float4 v) {             return v.w;                         }
