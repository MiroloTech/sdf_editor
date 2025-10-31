# References
https://www.shadertoy.com/view/l3Xyz4
https://github.com/mwalczyk/sdfperf?tab=readme-ov-file


# Behaviour

## Add Object
***Input : object type as Generic***
- new struct of requested type
- add to buffer through byte destruction ( allow properties to be marked as constant and editor-only )

## Modify Object
***Input : object reference, property name, new value***
- Find reference to requested object through node graph or path
- Change requested property of reference

## Create new Object
***Input : new type id, struct of new object, glsl source code***
- Add SDF to GLSL Code
- Add decompiling instructions based on type
- Recompile GLSL Code
- Reload GLSL Code

## Connect Object
***Input : scene graph***
- Extrapolate behaviour from scene graph
- Translate behaviour into glsl
- Update glsl map function
- Recompile GLSL Code
- Reload GLSL Code


# Optimizations
- Cylinder Tracing vs Cone Tracing vs Sphere Tracing
- World to grid & Culling that grid
- (BVH)


# Buffer structure

```
[ 8bit - buffer start ] [ ... ]
| always 255

( to check, if 
buffer is correctly 
positioned )
```



# Shader

## V1.0

raymarching.cl
```
struct Sample {
    float dist;
    float3 color;
}



Sample map(float3 p) {
    
}


Sample march(float3 ro, float3 rd) {
    float total_dist = 0.0f;
    Sample hit = sky_sample(rd);
    
    for (int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * total_dist;
        Sample sample = map(p);
        total_dist += sample.dist;
        
        if (sample.dist <= EPSILON) {
            hit = sample;
            break;
        }
    }
    
    return hit
}


// Kernel execution for each pixel
void main( Image screen_image, float3 cam_pos, float3 cam_dir ) {
    Sample sample = march(cam_pos, cam_dir);
    float3 color = get_color_from_sample(sample);
    
    float2 uv = (float2)(get_global_group(0), get_global_group(1));
    draw_iamge(screen_image, uv, color);
}
```




# CL Tokenizer

```
text := "inline float8 sdfSphere(float3 p, float r, float8 material) {
    material.dist = length(p) - r;
    return material;
}"

-> [ "inline", "float8", "sdfSphere", "(", "float3", "p", ",", "float", ... ]

special_chars := "(){}[]!@#$%^&*-=+/?<>,:;\"'\n\t "
excluded_chars := "\n\t "

mut tokens := []string{}

for c8 in text {
    c := c8.ascii_str()
    if tokens.len == 0 {
        tokens << c
        continue
    }
    
    if c in special_chars {
        if !(c in excluded_chars) {
            tokens << c
        }
        continue
    }
    
    tokens[tokens.len - 1] += c
}

return tokens
```



# TODO : Add input for basic values, when field is int, float or double
# TODO : Turn connections into series of custom variables and function calls
# TODO : Transfer custom series to shader


# Graph to Shader

Go from right to left:
```
lines := []
visited := []
todo := []
todo << get_output_node()
depth := 0

while todo.len > 0:
    for node in todo.clone():
        if visited.has(node): continue
        variables := []
        for pin in node.pins_in:
            if pin.is_connected:
                variable_name := pin.from.get_variable() // Returns a generated variable name, or generates one first, if it hasn't happened yet
                todo << get_node_with_pin(pin.from)
                variables << variable_name
            else:
                variables << pin.value
        output_pin := node.pins_right[0] or continue
        output_var := output_pin.get_variable()
        str_vars := variables.join(", ")
        lines << "${output_var} = ${node.function} (${str_vars});"
        visisted << node
    depth++
    if depth == 500:
        return error("Stack Overflow")

lines.reverse_in_place()

```

