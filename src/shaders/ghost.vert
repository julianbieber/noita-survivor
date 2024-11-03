#version 460 core
out flat int instanceId;
out vec3 pos;
out vec2 uv;
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 uv_in;
layout(location = 2) in vec2 offset;


void main() {
    instanceId = gl_InstanceID;
    gl_Position = vec4(aPos.x + offset.x, aPos.y + offset.y, aPos.z, 1.0);
    pos = vec3(aPos.x, aPos.y, aPos.z) ;
    uv = uv_in;
}
