#version 460 core
in flat int instanceId;
in vec3 pos;
in vec2 uv;
in float size;
in float duration;
out vec4 FragColor;


void main(){
    FragColor = vec4(uv, duration, 0.0);
}
