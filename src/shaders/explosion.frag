#version 460 core
in flat int instanceId;
in vec3 pos;
in vec2 uv;
in float size;
in float duration;
out vec4 FragColor;


void main(){
    vec2 p = (uv - vec2(0.5, 0.5)) * 2.0;
    float radius = length(p);
    if (radius > (1.0 - duration) && radius < (1.0 - duration + 0.2)) {
        FragColor = vec4(1.0, 0.0, 0.0, 1.0);
    } else{
        FragColor = vec4(0.0);
    }
}
