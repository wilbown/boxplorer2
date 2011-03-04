// 2D Mandelbrot
// shader parts from https://github.com/Syntopia/Fragmentarium

// Camera position and direction.
varying vec3 eye, dir;

// Interactive parameters.
uniform vec3 par[10];

uniform int iters;  // Number of fractal iterations. {min=10 max=1000}

#define surfaceColor par[2]
#define R par[2].x
#define G par[2].y
#define B par[2].z
#define Divider par[0].x  // {min=0 max=50}
#define Power par[0].y  // {min=0 max=6}
#define Radius par[0].z // {min=0 max=5}

vec2 complexMul(vec2 a, vec2 b) {
  return vec2(a.x*b.x - a.y*b.y,a.x*b.y + a.y * b.x);
}

// Mandelbrot for c.x,c.y
vec3 getColor2D(vec2 c) {
  vec2 z = vec2(0.0,0.0);
  int i = 0;
  float dist = 10000.0;
  for (i = 0; i < iters; i++) {
    z = complexMul(z,z) + c;
    if (dot(z,z)> 100.0) break;
    dist = min(dist, abs(length(z)-Radius));
  }
  if (i < iters) {
    // The color scheme here is based on one
    // from Inigo Quilez's Shader Toy:
    float co = float( i) + 1.0 - log2(.5*log2(dot(z,z)));
    co = sqrt(co/256.0);
    float  co2 = dist * Divider;
    float fac = clamp(1.0/pow(co2,Power),0.0,1.0);
    return fac*vec3( .5+.5*cos(6.2831*co+R),
      .5+.5*cos(6.2831*co+G),
      .5+.5*cos(6.2831*co+B) );
  } else {
    return vec3(0.0);
  }
}

void main() {
  vec3 p = eye;

  // Intersect the view ray with the 2D plane at Z==0
  float totalD = -p.z / dir.z;
  p += totalD * dir;

  vec3 col = getColor2D(vec2(p));

  // Write zBuffer and pixel
  float zFar = 5.0;
  float zNear = 0.0001;
  float a = zFar / (zFar - zNear);
  float b = zFar * zNear / (zNear - zFar);
  float depth = (a + b / clamp(totalD/length(dir), zNear, zFar));
  gl_FragDepth = depth;
  gl_FragColor = vec4(col, depth);
}
