#version 460 core
out flat int instanceId;
out vec3 pos;
layout (location = 0) in vec3 aPos;
uniform float time;

const float e = 2.71828;
const float pi = 3.14159265359 ;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    instanceId = gl_InstanceID;

    float instanceOffset = hash(vec2(gl_InstanceID + 0.2));    
    float x = aPos.x + 1.0 / pow(e, fract(time * instanceOffset)) -1.0;
    if (instanceId %2 == 1) {
        x = x * -1;
    }
    float y = aPos.y - pow(fract(time * instanceOffset) * 3.0- 1, 2.0) * 0.2 +0.5;
    // y = aPos.y;
    gl_Position = vec4(x, y, aPos.z, 1.0);
    pos = vec3(x, y, aPos.z) * hash(vec2(instanceId)).x;
}
