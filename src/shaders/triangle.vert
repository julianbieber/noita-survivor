#version 460 core
out flat int instanceId;
layout (location = 0) in vec3 aPos;
uniform float time;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    instanceId = gl_InstanceID;
    gl_Position = vec4(aPos.x + (hash(vec2(gl_InstanceID + 0.2))*2.0)*fract(time), aPos.y + (hash(vec2(gl_InstanceID + 0.2))*2.0)*fract(time), aPos.z, 1.0);
}
