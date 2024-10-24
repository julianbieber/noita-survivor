 #version 460 core
 in flat int instanceId;
 out vec4 FragColor;


float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += sin(dot(p, p + 45.32));
    return fract(p.x * p.y);
} 
 void main() {
     FragColor = vec4(hash(vec2(instanceId * 5.0)), hash(vec2(instanceId*8.0)), hash(vec2(instanceId*4.0)), 1.0);   
 }
