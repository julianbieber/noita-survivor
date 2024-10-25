 #version 460 core
 in flat int instanceId;
 in vec3 pos;
 out vec4 FragColor;


float hash(vec2 p) {
    p = fract(sin(p * vec2(123.34, 456.21)));
    p += sin(dot(p, p + 45.32));
    return fract(p.x * p.y);
} 
 void main() {
     float y = floor(pos.y * 1000.0)/1000.0;
     float x = floor(pos.x * 1000.0)/1000.0;
     FragColor = vec4(hash(vec2(instanceId * 5.0)+x), hash(vec2(instanceId*8.0)+y), hash(vec2(instanceId*4.0)*x*y), 1.0)*abs(pos.x);   
 }
