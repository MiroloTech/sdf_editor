#define MAX_STEPS 500
#define EPSILON 0.001f
#define MAX_DIST 2500.0f

// Avg. frame time : 73

typedef struct {
    float3 color;
    int unshaded;
} Material;

inline Material blend_material(Material a, Material b, float t) {
    return (Material){
        mix(a.color, b.color, t),
        t < 0.5f ? a.unshaded : b.unshaded
    };
}

typedef struct {
    float dist;
    Material material;
} Sample;


const Material mat_black = (Material){(float3)(0.0f, 0.0f, 0.0f), 0};
const Material mat_gray =  (Material){(float3)(0.5f, 0.5f, 0.5f), 0};
const Material mat_red =   (Material){(float3)(1.0f, 0.0f, 0.0f), 0};
const Material mat_green = (Material){(float3)(0.0f, 1.0f, 0.0f), 0};
const Material mat_blue =  (Material){(float3)(0.0f, 0.0f, 1.0f), 0};


typedef struct {
    float3 ambient;
    
    float3 sun_dir;
    float3 sun_pos;
    
    float3 sky_color;
} Environment;

const Environment DEFAULT_ENV = (Environment){
    (float3)(0.1f, 0.1f, 0.1f),
    
    (float3)(-0.577f, -0.577f, 0.577f),
    (float3)(-100.0f, -100.0f, 100.0f),
    
    (float3)(0.5f, 0.7f, 1.0f),
};


// ========  MATH =======
inline float3 rot3D(float3 v, float3 axis, float angle) {
    return mix(dot(axis, v) * axis, v, cos(angle)) + cross(axis, v) * sin(angle);
}

inline float3 mod3(float3 p, float3 m) {
    return (float3)( fmod(p.x, m.x), fmod(p.y, m.y), fmod(p.z, m.z) );
}

inline float3 abs3(float3 v) {
    return (float3)( fabs(v.x), fabs(v.y), fabs(v.z) );
}

inline float fract(float v) {
    return v - floor(v);
}

inline float mod(float v, float s) {
    return fabs(fract((v + (s * 0.5f)) / 6.0) * 6.0f - (s * 0.5f));
}


// ======== SDF FUNCTIONS ========

inline Sample sdfPlane(float3 p, float3 n, float h, Material material) {
    return (Sample){
        dot(p, n) + h,
        material
    };
}

inline Sample sdfSphere(float3 p, float r, Material material) {
    return (Sample){
        length(p) - r,
        material
    };
}

inline Sample sdfBox(float3 p, float3 bounds, Material material) {
    const float3 q = abs3(p) - bounds;
    const float dist = length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
    return (Sample){
        dist,
        material
    };
}

inline Sample sdfCylinder(float3 p, float3 a, float3 b, float r, Material material) {
    const float3 ba = b - a;
    const float3 pa = p - a;
    const float baba = dot(ba, ba);
    const float paba = dot(pa, ba);
    const float x = length(pa * baba - ba * paba) - r * baba;
    const float y = fabs(paba - baba * 0.5f) - baba * 0.5f;
    const float x2 = x * x;
    const float y2 = y * y * baba;
    const float d = (max(x, y) < 0.0f) ? -min(x2, y2) : (((x > 0.0f) ? x2 : 0.0f) + ((y > 0.0f) ? y2 : 0.0f));
    const float dist = sign(d) * sqrt(fabs(d)) / baba;
    return (Sample){
        dist,
        material
    };
}

inline Sample sdfCone(float3 p, float2 c, float h, Material material) {
    const float2 q = h * (float2)(c.x / c.y, -1.0f);
    const float2 w = (float2)(length(p.xz), p.y);
    const float2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0f, 1.0f);
    const float2 b = w - q * (float2)(clamp(w.x/ q.x, 0.0f, 1.0f ), 1.0f);
    const float k = sign(q.y);
    const float d = min(dot(a, a), dot(b, b));
    const float s = max(k * (w.x * q.y - w.y * q.x), k *(w.y - q.y));
    return (Sample){
        sqrt(d) * sign(s),
        material
    };
}



/*
Sample sdfGizmo_XYZ_Arrows(float3 p, float scale) {
    float3 px = p;
    // TODO : This
}
*/



inline Sample opUnion(Sample a, Sample b) {
    // return a.dist < b.dist ? a : b;
    int cond = a.dist < b.dist;
    Sample out;
    out.dist              = min(a.dist, b.dist);
    // out.material.color    = select(b.material.color, a.material.color, (int3)(cond));
    // out.material.unshaded = cond ? a.material.unshaded : b.material.unshaded;
    out.material = cond ? a.material : b.material;
    return out;
}

inline Sample opSmoothUnion(Sample a, Sample b, float k) {
    // TODO : Make this circular
    const float h = 1.0 - min(fabs(a.dist - b.dist) / (6.0f * k), 1.0f);
    const float w = h * h * h;
    const float m = w * 0.5f;
    const float s = w * k;
    if (a.dist < b.dist) {
        return (Sample){
            a.dist - s,
            blend_material(a.material, b.material, m)
        };
    } else {
        return (Sample){
            b.dist - s,
            blend_material(a.material, b.material, 1.0f - m)
        };
    }
}



// ======== SCENE ========

Sample map(float3 p, float time) {
    const Sample sphere1 = sdfSphere(p - (float3)(3.0f, sin(time * 3.0f) * 2.0f, 0.0f), 1.0f, mat_red); //  - (float3)(-1.5f, 0.0f, 3.0f)
    const Sample sphere2 = sdfSphere(p - (float3)(1.5f, 0.0f, 4.0f),                    1.0f, mat_green);
    // const Sample plane = sdfPlane(p, (float3)(0.0f, 1.0f, 0.0f), 1.5f, mat_gray);
    
    const Sample box = sdfBox(p, (float3)(1.5f, 1.5f, 1.5f), mat_blue);
    
    Sample d = sphere1;
    d = opUnion(d, sphere2);
    d = opUnion(d, box);
    // d = opSmoothUnion(d, plane, 0.2f);
    return d;
}

Sample march(float3 ro, float3 rd, float time) {
    float total_dist = 0.0f;
    Sample hit = (Sample){-1.0f, mat_black};
    
    for (int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * total_dist;
        Sample sample = map(p, time);
        
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


float3 shade(float3 ro, float3 rd, Sample sample, Environment env, float time) {
    float3 sky_color = sky(rd, env);
    float3 p = ro + rd * sample.dist;
    
    if (sample.dist < 0.0f) {
        return sky_color;
    }
    
    if (sample.material.unshaded) {
        return sample.material.color;
    }
    
    // Simple directional shading
    float3 n = get_normal(ro + rd * sample.dist, time);
    float sun_shine = max(0.0f, dot(n, -env.sun_dir));
    float3 color = mix(env.ambient, sample.material.color, sun_shine);
    
    // Check for shadows
    bool blocked = march(p + n * EPSILON, -env.sun_dir, time).dist >= 0.0f;
    if (blocked) {
        color = env.ambient;
    }
    
    return color;
}


// Returns the total distance in x and the minimum recorded distance in y
float2 min_dist(float3 ro, float3 rd, float time) {
    float total_dist = 0.0f;
    float min_dist = MAX_DIST;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * total_dist;
        Sample sample = map(p, time);
        
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




// ======== MAIN =========

__kernel void raymarching(__write_only image2d_t outputImage, float fov, float cam_pos_x, float cam_pos_y, float cam_pos_z, float cam_dir_x, float cam_dir_y, float cam_dir_z, float time) {
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
    // Sample sample = march(ro, rd, time);
    // float3 color = shade(ro, rd, sample, DEFAULT_ENV, time);
    
    float3 color = march(ro, rd, time).material.color;
    // dist *= 0.05f;
    
    /*
    float dist_test = min_dist(ro, rd, time).y;
    if (dist_test <= 0.04f && dist_test > EPSILON) {
        color = (float3)(1.0f, 0.2f, 0.1f);
    }
    */
    
    // write_imagef(outputImage, screen_pos, (float4)(color.r, color.g, color.b, 1.0f));
    write_imagef(outputImage, screen_pos, (float4)(color.r, color.g, color.b, 1.0f));
}

