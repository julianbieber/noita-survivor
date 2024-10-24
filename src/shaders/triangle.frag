 #version 460 core
 in flat int instanceId;
 out vec4 FragColor;
 void main() {
     FragColor = vec4(1.0, 1.0 / (instanceId / 100.0), 0.2, 1.0);   
 }
