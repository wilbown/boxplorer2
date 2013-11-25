// "Fractal Cartoon" - former "DE edge detection" by Kali
// (https://www.shadertoy.com/view/4djGz1)

// Cartoon-like effect using eiffies's edge detection found here: 
// https://www.shadertoy.com/view/4ss3WB
// I used my own method previously but was too complicated and not compiling everywhere.
// Thanks to the suggestion by WouterVanNifterick. 

// There are no lights and no AO, only color by normals and dark edges.

uniform float xres, yres, speed, time;
varying vec3 eye, dir;
uniform sampler2D my_texture;
uniform int iters, max_steps;

#include "setup.inc"
#line 17

vec2 iResolution = vec2(xres, yres);
vec3 iMouse = vec3(0.);
float iGlobalTime = time;
#define iChannel0 my_texture

//#define SHOWONLYEDGES
#define WAVES
//#define BORDER

#define RAY_STEPS max_steps

#define BRIGHTNESS 1.2
#define GAMMA 1.35
#define SATURATION .65


#define detail .001
#define t iGlobalTime*.5



const vec3 origin=vec3(-1.,.7,0.);
float det=0.0;

// 2D rotation function
mat2 rot(float a) {
  return mat2(cos(a),sin(a),-sin(a),cos(a));  
}

// "Amazing Surface" fractal
vec4 formula(vec4 p) {
  p.xz = abs(p.xz+1.)-abs(p.xz-1.)-p.xz;
  p.y-=.25;
  p.xy*=rot(radians(35.));
  p=p*2./clamp(dot(p.xyz,p.xyz),.2,1.);
  return p;
}

// Distance function
float de(vec3 pos) {
#ifdef WAVES
  pos.y+=sin(pos.z-t*6.)*.15; //waves!
#endif
  float hid=0.;
  vec3 tpos=pos;
  tpos.z=abs(3.-mod(tpos.z,6.));
  vec4 p=vec4(tpos,1.);
  for (int i=0; i<iters; i++) {p=formula(p);}
  float fr=(length(max(vec2(0.),p.yz-1.5))-1.)/p.w;
  float ro=max(abs(pos.x+1.)-.3,pos.y-.35);
  ro=max(ro,-max(abs(pos.x+1.)-.1,pos.y-.5));
  pos.z=abs(.25-mod(pos.z,.5));
  ro=max(ro,-max(abs(pos.z)-.2,pos.y-.3));
  ro=max(ro,-max(abs(pos.z)-.01,-pos.y+.32));
  float d=min(fr,ro);
  return d;
}

float de_for_host(vec3 p) { return de(p); }

// Camera path
vec3 path(float ti) {
  vec3  p=vec3(sin(ti),(1.-sin(ti))*.5,-ti*5.)*.5;
  return p;
}

// Calc normals, and here is edge detection, set to variable "edge"

float edge=0.;
vec3 normal(vec3 p) { 
  vec3 e = vec3(0.0,det*5.,0.0);

  float d1=de(p-e.yxx),d2=de(p+e.yxx);
  float d3=de(p-e.xyx),d4=de(p+e.xyx);
  float d5=de(p-e.xxy),d6=de(p+e.xxy);
  float d=de(p);
  edge=abs(d-0.5*(d2+d1))+abs(d-0.5*(d4+d3))+abs(d-0.5*(d6+d5));//edge finder
  edge=min(1.,pow(edge,.5)*15.);
  return normalize(vec3(d1-d2,d3-d4,d5-d6));
}

// Raymarching and 2D graphics

vec3 raymarch(in vec3 from, in vec3 dir) 
{
  edge=0.;
  vec3 p, norm;
  float d=100.;
  float totdist=0.;
  for (int i=0; i<RAY_STEPS; i++) {
    if (d>det && totdist<25.0) {
      p=from+totdist*dir;
      d=de(p);
      det=detail*exp(.13*totdist);
      totdist+=d; 
    }
  }
  vec3 col=vec3(0.);
  p-=(det-d)*dir;
  norm=normal(p);
#ifdef SHOWONLYEDGES
  col=1.-vec3(edge); // show wireframe version
#else
  col=(1.-abs(norm))*max(0.,1.-edge*.8); // set normal as color with dark edges
#endif    
  totdist=clamp(totdist,0.,26.);
  dir.y-=.02;
  float sunsize=7.-max(0.,texture2D(iChannel0,vec2(.6,.2)).x-.4)*5.; // responsive sun size
  float an=atan(dir.x,dir.y)+iGlobalTime*1.5; // angle for drawing and rotating sun
  float s=pow(clamp(1.0-length(dir.xy)*sunsize-abs(.2-mod(an,.4)),0.,1.),.1); // sun
  float sb=pow(clamp(1.0-length(dir.xy)*(sunsize-.3)-abs(.2-mod(an,.4)),0.,1.),.1); // sun border
  float sg=pow(clamp(1.0-length(dir.xy)*(sunsize-4.5)-.5*abs(.2-mod(an,.4)),0.,1.),3.); // sun rays
  float y=mix(.45,1.2,pow(smoothstep(0.,1.,.75-dir.y),2.))*(1.-sb*.5); // gradient sky
  
  // set up background with sky and sun
  vec3 backg=vec3(0.5,0.,1.)*((1.-s)*(1.-sg)*y+(1.-sb)*sg*vec3(1.,.8,0.15)*3.);
  backg+=vec3(1.,.9,.1)*s;
  backg=max(backg,sg*vec3(1.,.9,.5));
  
  col=mix(vec3(1.,.9,.3),col,exp(-.004*totdist*totdist));// distant fading to sun color
  if (totdist>25.) col=backg; // hit background
  return col;
}

// get camera position
vec3 move(inout vec3 dir) {
  vec3 go=path(t);
  vec3 adv=path(t+.7);
  float hd=de(adv);
  vec3 advec=normalize(adv-go);
  float an=adv.x-go.x; an*=min(1.,abs(adv.z-go.z))*sign(adv.z-go.z)*.7;
  dir.xy*=mat2(cos(an),sin(an),-sin(an),cos(an));
  an=advec.y*1.7;
  dir.yz*=mat2(cos(an),sin(an),-sin(an),cos(an));
  an=atan(advec.x,advec.z);
  dir.xz*=mat2(cos(an),sin(an),-sin(an),cos(an));
  return go;
}


void main(void)
{
  vec2 uv = gl_FragCoord.xy / iResolution.xy*2.-1.;
  vec2 oriuv=uv;
  uv.y*=iResolution.y/iResolution.x;
  vec2 mouse=(iMouse.xy/iResolution.xy-.5)*3.;
  if (iMouse.z<1.) mouse=vec2(0.,-.1);
  float fov=.9-max(0.,.7-iGlobalTime*.3);
  vec3 ddir=normalize(vec3(uv*fov,1.));
  ddir.yz*=rot(mouse.y);
  ddir.xz*=rot(mouse.x);
  vec3 from=origin+move(ddir);
  if (!setup_ray(eye, dir, from, ddir)) {  // boxplorify view
    return;
  }
  vec3 color=raymarch(from,ddir);
  color=pow(color,vec3(GAMMA))*BRIGHTNESS;
  color=mix(vec3(length(color)),color,SATURATION);

#ifdef SHOWONLYEDGES
  color=1.-vec3(length(color));
#else
  color*=vec3(1.,.9,.85);
 #ifdef BORDER
  color=mix(vec3(0.5),color,pow(max(0.,.95-length(oriuv*oriuv*oriuv*vec2(1.05,1.1))),.3));
 #endif
#endif
  //gl_FragColor = vec4(color,1.);
  write_pixel(dir, 1., color);  // boxplorify write
}
