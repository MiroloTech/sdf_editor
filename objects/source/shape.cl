#define MAX_STEPS   500
#define EPSILON     0.001f
#define MAX_DIST    2500.0f

#define colorr      s0
#define colorg      s1
#define colorb      s2
#define unshaded    s3
#define dist        s7

#define Material    float8
#define Sample      float8



inline Sample sdfSphere(float3 p, float r, Material material) {
    material.dist = length(p) - r;
    return material;
}

inline Sample sdfPlane(float3 p, float3 n, float h, Material material) {
    material.dist = dot(p, n) + h;
    return material;
}

inline Sample sdfBox(float3 p, float3 bounds, Material material) {
    const float3 q = abs3(p) - bounds;
    material.dist = length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
    return material;
}
