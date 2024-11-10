#version 460 core
out flat int instanceId;
out vec3 pos;
out vec2 uv;
out float size;
out float duration;
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 uv_in;
layout(location = 2) in vec2 offset;
layout(location = 3) in float max_size;
layout(location = 4) in float remaining_duration;


void main() {
    instanceId = gl_InstanceID;
    gl_Position = vec4(aPos.x * max_size + offset.x, aPos.y * max_size + offset.y, aPos.z, 1.0);
    pos = vec3(aPos.x, aPos.y, aPos.z) ;
    uv = uv_in;
    size = max_size;
    duration = remaining_duration;
}
