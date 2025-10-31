inline float   Float(  float v                                                                        )  { return v; }
inline float2  Float2( float x,  float y                                                              )  { return (float2)(x, y); }
inline float3  Float3( float x,  float y,  float z                                                    )  { return (float3)(x, y, z); }
inline float4  Float4( float x,  float y,  float z,  float w                                          )  { return (float4)(x, y, z, w); }
inline float8  Float8( float v0, float v1, float v2, float v3, float v4, float v5, float v6, float v7 )  { return (float8)(v0, v1, v2, v3, v4, v5, v6, v7); }
inline float16 Float16(
    float v0, float v1, float v2, float v3, float v4, float v5, float v6, float v7,
    float v8, float v9, float v10, float v11, float v12, float v13, float v14, float v15
) { return (float16)(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15); }

inline double   Double(  double v                                                                               )  { return v; }
inline double2  Double2( double x,  double y                                                                    )  { return (double2)(x, y); }
inline double3  Double3( double x,  double y,  double z                                                         )  { return (double3)(x, y, z); }
inline double4  Double4( double x,  double y,  double z,  double w                                              )  { return (double4)(x, y, z, w); }
inline double8  Double8( double v0, double v1, double v2, double v3, double v4, double v5, double v6, double v7 )  { return (double8)(v0, v1, v2, v3, v4, v5, v6, v7); }
inline double16 Double16(
    double v0, double v1, double v2, double v3, double v4, double v5, double v6, double v7,
    double v8, double v9, double v10, double v11, double v12, double v13, double v14, double v15
) { return (double16)(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15); }

inline int   Int(  int v                                                          )  { return v; }
inline int2  Int2( int x,  int y                                                  )  { return (int2)(x, y); }
inline int3  Int3( int x,  int y,  int z                                          )  { return (int3)(x, y, z); }
inline int4  Int4( int x,  int y,  int z,  int w                                  )  { return (int4)(x, y, z, w); }
inline int8  Int8( int v0, int v1, int v2, int v3, int v4, int v5, int v6, int v7 )  { return (int8)(v0, v1, v2, v3, v4, v5, v6, v7); }
inline int16 Int16(
    int v0, int v1, int v2, int v3, int v4, int v5, int v6, int v7,
    int v8, int v9, int v10, int v11, int v12, int v13, int v14, int v15
) { return (int16)(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15); }

inline bool Bool( bool v ) { return v; }

#define Material    float8

inline Material   newMaterial( float3 color, bool unshaded ) {
    return (Material)(color.r, color.g, color.b, (float)(unshaded), 0.0f, 0.0f, 0.0f,   0.0f);
}
