#version 460 core
in flat int instanceId;
in vec3 pos;
in vec2 uv;
in float size;
in float duration;
out vec4 FragColor;


void main(){
    if (length((uv - vec2(0.5, 0.5))) < duration / 10.0) {
        FragColor = vec4(1.0, 0.0, 0.0, 1.0);
    } else{
        FragColor = vec4(0.0);
    }
}
