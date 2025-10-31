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

// Avg. frame time : 31



const float8 mat_black = (float8)(0.0f, 0.0f, 0.0f, 0,  0, 0, 0,  -1.0f);
const float8 mat_gray =  (float8)(0.5f, 0.5f, 0.5f, 0,  0, 0, 0,  -1.0f);
const float8 mat_red =   (float8)(1.0f, 0.0f, 0.0f, 0,  0, 0, 0,  -1.0f);
const float8 mat_green = (float8)(0.0f, 1.0f, 0.0f, 0,  0, 0, 0,  -1.0f);
const float8 mat_blue =  (float8)(0.0f, 0.0f, 1.0f, 0,  0, 0, 0,  -1.0f);


typedef struct {
    float3 ambient;
    
    float3 sun_dir;
    float3 sun_pos;
    float sun_size;
    
    float3 sky_color;
} Environment;

const Environment DEFAULT_ENV = (Environment){
    (float3)(0.1f, 0.1f, 0.1f),
    
    (float3)(-0.577f, -0.577f, 0.577f),
    (float3)(10.0f, 10.0f, -10.0f),
    0.8f,
    
    (float3)(0.5f, 0.7f, 1.0f),
};


// ========  MATH =======
inline float3 rot3D(float3 v, float3 axis, float angle) {
    return mix(dot(axis, v) * axis, v, cos(angle)) + cross(axis, v) * sin(angle);
}

inline float3 mod3(float3 p, float3 m) {
    return (float3)(fmod(p.x, m.x), fmod(p.y, m.y), fmod(p.z, m.z));
}

inline float3 abs3(float3 v) {
    return (float3)(fabs(v.x), fabs(v.y), fabs(v.z));
}

inline float fract(float v) {
    return v - floor(v);
}

inline float mod(float v, float s) {
    return fabs(fract((v + (s * 0.5f)) / 6.0) * 6.0f - (s * 0.5f));
}



inline Sample sdfBox(float3 p, float3 bounds, Material material) {
    const float3 q = abs3(p) - bounds;
    material.dist = length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
    return material;
}


inline Material   newMaterial( float3 color, bool unshaded ) {
    return (Material)(color.r, color.g, color.b, (float)(unshaded), 0.0f, 0.0f, 0.0f,   0.0f);
}


inline float3  Float3( float x,  float y,  float z                                                    )  { return (float3)(x, y, z); }




inline float f_v3x(float3 v) {             return v.x;                         }


inline float f_v3y(float3 v) {             return v.y;                         }


inline float f_v3z(float3 v) {             return v.z;                         }


inline float f_add(float a, float b) {     return a + b;                       }

inline float f_sin(float x) {              return sin(x);                      }


inline float f_mul(float a, float b) {     return a * b;                       }


inline float f_cos(float x) {              return cos(x);                      }



// ======== SDF FUNCTIONS ========

/*
inline float8 sdfPlane(float3 p, float3 n, float h, float8 material) {
    material.dist = fabs(dot(p, n) + h);
    return material;
}

inline float8 sdfSphere(float3 p, float r, float8 material) {
    material.dist = length(p) - r;
    return material;
}

inline float8 sdfBox(float3 p, float3 bounds, float8 material) {
    const float3 q = abs3(p) - bounds;
    material.dist = length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
    return material;
}



inline float8 opUnion(float8 a, float8 b) {
    // return select(a, b, (int4)(a.w < b.w));
    return a.dist < b.dist ? a : b;
}


inline float8 opSmoothUnion(float8 a, float8 b, float k) {
    float diff = fabs(a.dist - b.dist);

    // If distances are far apart, skip blending
    if (diff >= 6.0f * k) {
        return opUnion(a, b);
    }
    
    const float h = 1.0 - min(fabs(a.dist - b.dist) / (6.0f * k), 1.0f);
    const float w = h * h * h;
    const float m = w * 0.5f;
    const float s = w * k;
    if (a.dist < b.dist) {
        float8 sample = mix(a, b, m);
        sample.dist = a.dist - s;
        return sample;
    } else {
        float8 sample = mix(a, b, 1.0f - m);
        sample.dist = b.dist - s;
        return sample;
    }
}
*/


// ======== SCENE ========

float8 map(float3 p, float time) {
	float var57 = time;
	float var62 = f_mul(var57, 6.0);
	float var67 = f_cos(var62);
	float var59 = f_sin(var62);
	float3 var31 = p;
	float var37 = f_v3z(var31);
	float var73 = f_mul(var67, 5.0);
	float var33 = f_v3x(var31);
	float var70 = f_mul(var59, 5.0);
	float3 var26 = Float3(0.9500002, 0.09999515, 0.8999998);
	float var65 = f_add(var73, var37);
	float var35 = f_v3y(var31);
	float var56 = f_add(var70, var33);
	float8 var22 = newMaterial(var26, 0.0);
	float3 var30 = Float3(2.0, 2.0, 2.0);
	float3 var41 = Float3(var56, var35, var65);
	float8 var19 = sdfBox(var41, var30, var22);
return var19;
}

float8 march(float3 ro, float3 rd, float time) {
    float total_dist = 0.0f;
    float8 hit = (float8)(mat_black);
    
    for (int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * total_dist;
        float8 sample = map(p, time);
        
        if (sample.dist <= EPSILON) {
            hit = sample;
            hit.dist = total_dist;
            break;
        }
        
        total_dist += sample.dist;
        if (total_dist >= MAX_DIST) {
            break;
        }
    }
    
    return hit;
}

float3 sky(float3 rd, Environment env) {
    float t = 0.5f * (rd.y + 1.0f);
    return mix((float3)(1.0f, 1.0f, 1.0f), env.sky_color, t);
}


// ======== UTIL =========

float3 get_normal(float3 p, float time) {
    float d = map(p, time).dist;
    float2 eps = (float2)(EPSILON, 0.0f);
    float3 v = (float3)(
        map(p + eps.xyy, time).dist - d,
        map(p + eps.yxy, time).dist - d,
        map(p + eps.yyx, time).dist - d
    );
    return normalize(v);
}

// Returns the total distance in x and the minimum recorded distance in y
float2 min_dist(float3 ro, float3 rd, float time) {
    float total_dist = 0.0f;
    float min_dist = MAX_DIST;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * total_dist;
        float8 sample = map(p, time);
        
        if (sample.dist <= EPSILON) {
            return (float2)(total_dist, sample.dist);
        }
        
        total_dist += sample.dist;
        min_dist = min(min_dist, sample.dist);
        if (total_dist >= MAX_DIST) {
            break;
        }
    }
    
    return (float2)(total_dist, min_dist);
}



float3 shade(float3 ro, float3 rd, float8 sample, Environment env, float time) {
    float3 sky_color = sky(rd, env);
    float3 p = ro + rd * sample.dist;
    float3 sample_color = (float3)(sample.colorr, sample.colorg, sample.colorb);
    
    if (sample.dist < 0.0f) {
        return sky_color;
    }
    
    if (sample.unshaded) {
        return sample_color;
    }
    
    // Simple directional shading
    float3 n = get_normal(p, time);
    float sun_shine = max(0.0f, dot(n, -env.sun_dir));
    float3 color = mix(env.ambient, sample_color, sun_shine);
    
    
    // Check for shadows
    bool blocked = march(p + n * EPSILON, -env.sun_dir, time).dist >= 0.0f;
    if (blocked) {
        color = env.ambient;
    }
    
    
    return color;
}


// ======== MAIN =========

__kernel void raymarching_fast(
        __write_only image2d_t outputImage,
        float fov,
        float cam_pos_x, float cam_pos_y, float cam_pos_z,
        float cam_dir_x, float cam_dir_y, float cam_dir_z,
        // float cam_pos_x, float cam_pos_y, float cam_pos_z,
        // float cam_dir_x, float cam_dir_y, float cam_dir_z,
        float time
) {
    const int width = get_global_size(0);
    const int height = get_global_size(1);
    const int2 screen_pos = (int2)(get_global_id(0), get_global_id(1));
    float2 uv = ((float2)(screen_pos.x, screen_pos.y) / (float2)(width, height)) * 2.0f - (float2)(1.0f);
    // uv.y *= -1.0f;
    uv.x *= (float)width / (float)height;
    
    // Calculate ray origin and direction
    const float3 cam_pos = (float3)(cam_pos_x, cam_pos_y, cam_pos_z);
    const float3 cam_dir = normalize((float3)(cam_dir_x, cam_dir_y, cam_dir_z));
    
    const float3 ro = cam_pos;
    
    const float3 world_up = (float3)(0.0f, -1.0f, 0.0f);
    const float3 right = normalize(cross(cam_dir, world_up));
    const float3 up = cross(right, cam_dir);
    
    const float tan_fov = tan(fov * 0.5f);
    const float3 ray_dir_cam = normalize((float3)(uv.x * tan_fov, uv.y * tan_fov, 1.0));
    const float3 rd = normalize(right * ray_dir_cam.x + up * ray_dir_cam.y + cam_dir * ray_dir_cam.z);
    
    // Sample through map and write output color into image
    float8 sample = march(ro, rd, time);
    float3 color = shade(ro, rd, sample, DEFAULT_ENV, time);
    // float d = sample.dist * 0.05f;
    
    write_imagef(outputImage, screen_pos, (float4)(color.r, color.g, color.b, 1.0f));
}

