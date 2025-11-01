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



inline Sample Union(Sample a, Sample b) {
    return a.dist < b.dist ? a : b;
}

inline Sample Subtraction(Sample a, Sample b) {
    return -a.dist > b.dist ? a : b;
}

inline Sample Intersection(Sample a, Sample b) {
    return a.dist > b.dist ? a : b;
}

inline Sample opSmoothUnion(Sample a, Sample b, float k) {
    // TODO : Make this circular
    const float h = 1.0 - min(fabs(a.dist - b.dist) / (6.0f * k), 1.0f);
    const float w = h * h * h;
    const float m = w * 0.5f;
    const float s = w * k;
    if (a.dist < b.dist) {
        Sample sample = mix(a, b, m);
        sample.dist = a.dist - s;
        return sample;
    } else {
        Sample sample = mix(a, b, 1.0f - m);
        sample.dist = b.dist - s;
        return sample;
    }
}
