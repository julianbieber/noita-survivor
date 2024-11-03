#version 460 core
in flat int instanceId;
in vec3 pos;
in vec2 uv;
out vec4 FragColor;

#define PI 3.1415926538
#define TAU 6.2831853071
#define FOV 60.0

float hash1(float v) {
    return fract(sin(v * 12321.0));
}
struct SceneSample {
    float closest_distance;
    int index;
};

struct RayEnd {
    SceneSample s;
    vec3 current_position;
};

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec3 rotate(vec3 p, float yaw, float pitch, float roll) {
    return (mat3(cos(yaw), -sin(yaw), 0.0, sin(yaw), cos(yaw), 0.0, 0.0, 0.0, 1.0) *
        mat3(cos(pitch), 0.0, sin(pitch), 0.0, 1.0, 0.0, -sin(pitch), 0.0, cos(pitch)) *
        mat3(1.0, 0.0, 0.0, 0.0, cos(roll), -sin(roll), 0.0, sin(roll), cos(roll))) *
        p;
}

// http://mercury.sexy/hg_sdf/
// Repeat around the origin by a fixed angle.
// For easier use, num of repetitions is use to specify the angle.
float pModPolar(inout vec2 p, float repetitions) {
    float angle = 2. * PI / repetitions;
    float a = atan(p.y, p.x) + angle / 2.;
    float r = length(p);
    float c = floor(a / angle);
    a = mod(a, angle) - angle / 2.;
    p = vec2(cos(a), sin(a)) * r;
    // For an odd number of repetitions, fix cell index of the cell in -x direction
    // (cell index would be e.g. -5 and 5 in the two halves of the cell):
    if (abs(c) >= (repetitions / 2.)) c = abs(c);
    return c;
}

float sdSphere(vec3 p, vec3 c, float r)
{
    return length(p - c) - r;
}

float sdBox(vec3 p, vec3 b)
{
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdTriPrism(vec3 p, vec2 h)
{
    vec3 q = abs(p);
    return max(q.z - h.y, max(q.x * 0.866025 + p.y * 0.5, -p.y) - h.x * 0.5);
}

float sub(float d1, float d2) {
    return max(-d1, d2);
}

SceneSample combine(SceneSample a, SceneSample b) {
    if (b.closest_distance < a.closest_distance) {
        return b;
    } else {
        return a;
    }
}
float pumpkin(vec3 p) {
    vec3 rp = p;
    pModPolar(rp.xz, 12.);
    float sphere = length(rp * vec3(.9, 1, 1) - vec3(.3, 0, 0)) - 1.;

    sphere = abs(sphere + .05) - .05;

    vec3 mirrorP = p;
    mirrorP.z = -abs(mirrorP.z);

    // round eyes
    vec3 mp = p;
    mp.x = abs(mp.x);

    // angular eyes
    sphere = max(sphere, -sdTriPrism(mp * vec3(1, -1, 1) + vec3(-.25, .35, -1.), vec2(.2, 1.1)));

    // both noses
    sphere = max(sphere, -sdTriPrism(mirrorP - vec3(0, .22, -1.), vec2(.1, 1.1)));

    // angular mouth
    sphere = max(sphere, -sdTriPrism(mp * vec3(1, -1, 1) + vec3(-.37, -.03, -1.), vec2(.16, 1.1)));
    sphere = max(sphere, -sdTriPrism(mp * vec3(1, -1, 1) + vec3(-.2, -.04, -1.), vec2(.18, 1.1)));
    sphere = max(sphere, -sdTriPrism(mp * vec3(1, -1, 1) + vec3(0, -.05, -1.), vec2(.2, 1.1)));
    return sphere;
}

float stem(vec3 p) {
    vec3 rp = p;
    pModPolar(rp.xz, 12.);
    float stem = dot(vec4(rp, 1), vec4(1, .1, 0, -.2));
    stem = max(stem, p.y - 1.3);
    stem = max(stem, -p.y + .95);
    return stem;
}

SceneSample scene(vec3 p) {
    SceneSample g = SceneSample(pumpkin(p), 1);
    SceneSample s = SceneSample(stem(p), 2);

    return combine(g, s);
}

float scene_f(vec3 p) {
    return scene(p).closest_distance;
}

vec3 normal(in vec3 p) // for function f(p)
{
    const float eps = 0.0001; // or some other value
    const vec2 h = vec2(eps, 0);
    return normalize(vec3(scene_f(p + h.xyy) - scene_f(p - h.xyy),
            scene_f(p + h.yxy) - scene_f(p - h.yxy),
            scene_f(p + h.yyx) - scene_f(p - h.yyx)));
}
float fov_factor() {
    return tan(FOV / 2.0 * PI / 180.0);
}

RayEnd follow_ray(vec3 start, vec3 direction, int steps, float max_dist) {
    float traveled = 0.0;
    for (int i = 0; i < steps; ++i) {
        vec3 p = start + direction * traveled;
        SceneSample s = scene(p);
        if (s.closest_distance < 0.01) {
            return RayEnd(s, p);
        }
        if (traveled >= max_dist) {
            break;
        }
        traveled += s.closest_distance;
    }

    return RayEnd(SceneSample(traveled, -1), start + direction * traveled);
}

vec4 resolve_color(int index, vec3 p) {
    if (index == 1) {
        vec3 n = normal(p);
        float v = dot(n, normalize(vec3(hash1(instanceId), 1.2+hash1(instanceId*4.0), 3.0)));
        return vec4(vec3(1, .5, 0)*(v), 1.0);
    } else if (index == 2) {
        return vec4(.1, .3, .1, 1.0);
    }

    return vec4(0.0);
}

vec4 render(vec3 eye, vec3 ray) {
    RayEnd end = follow_ray(eye, ray, 100, 100.0);
    if (end.s.index == -1) {
        return vec4(0.0);
    }
    vec4 color = resolve_color(end.s.index, end.current_position);
    return color;
}

void main() {
    float fov = fov_factor();
    vec2 pixel_position = ((uv - 0.5) * vec2(1.92, 1.2)) / 1.2;
    vec3 ray_direction = normalize(vec3(pixel_position, -1.0));

    FragColor = render(vec3(0.0, 0.0, 5.0), ray_direction);
}
