#version 330

#define PI 3.1415926
#define EPSILON 0.001
#define MAX_STEPS 25

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

uniform float aspectRatio; // height / width
uniform float fov = 100.0; // horizontal

uniform float time = 0.0; // time in seconds

// Output fragment color
out vec4 finalColor;

struct Material {
    vec4 color;
    float roughness;
};

struct HitInfo {
    Material mat;
    vec3 normal;
    float dist;
};

HitInfo sphere(vec3 pos, vec3 spherePos, float radius, Material mat) {
    return HitInfo(
        mat,
        normalize(pos - spherePos),
        length(spherePos - pos) - radius
    );
}

struct Light {
    vec3 position;
    vec3 color;
    float falloffExponent; // falloff with distance exponent (0 is approx sun light, 2 is point light)
};


Light sceneLightR = Light(
    vec3(1.0, 1.0, 4.0), 
    vec3(3.0, 3.5, 3.5) * 0.0 + vec3(5.0),
    2.0
);

Light sceneLightG = Light(
    vec3(1.0, 1.0, 4.0), 
    vec3(3.5, 3.0, 3.5) * 0.0 + vec3(5.0),
    2.0
);

Light sceneLightB = Light(
    vec3(1.0, 1.0, 4.0), 
    vec3(3.5, 3.5, 3.0) * 0.0 + vec3(5.0),
    2.0
);

const Material sphereMat1 = Material(
    vec4(1.0, 0.3, 0.0, 1.0), // color
    0.0 // roughness
);

const Material sphereMat2 = Material(
    vec4(0.5, 0.0, 1.0, 1.0), // color
    0.0 // roughness
);

const vec3 spherePos = vec3(0.0, 0.0, 5.0);
const vec3 spherePos2 = vec3(0.0, 1.0, 5.0);

HitInfo lerpHit(HitInfo a, HitInfo b, float t) {
    return HitInfo(
        Material(
            mix(a.mat.color, b.mat.color, t),
            mix(a.mat.roughness, b.mat.roughness, t)
        ),
        normalize(mix(a.normal, b.normal, t)),
        mix(a.dist, b.dist, t)
    );
}

HitInfo or(HitInfo a, HitInfo b) {
    float t = a.dist < b.dist ? 0.0 : 1.0;
    return lerpHit(a, b, t);
}

// quadratic polynomial - https://iquilezles.org/articles/smin/
vec2 smin( float a, float b, float k )
{
    float h = 1.0 - min( abs(a-b)/(4.0*k), 1.0 );
    float w = h*h;
    float m = w*0.5;
    float s = w*k;
    return (a<b) ? vec2(a-s,m) : vec2(b-s,1.0-m);
}

float map(float x, float fromA, float fromB, float toA, float toB) {
    return (toB - toA) * (x - fromA) / (fromB - fromA) + toA;
}

HitInfo smooth_or(HitInfo a, HitInfo b, float k) {
    vec2 smoothed = smin(a.dist, b.dist, k);
    HitInfo smoothedInfo = lerpHit(a, b, smoothed.y);
    smoothedInfo.dist = smoothed.x;
    return smoothedInfo;
}

HitInfo scene(vec3 pos) {
    return smooth_or(
        sphere(pos, spherePos, 1.0, sphereMat1),
        sphere(pos, vec3(cos(time * 0.9124) * 2, sin(time) * 2, 5.0), 1.0, sphereMat2),
        0.35
    );
}

vec3 shadowRay(vec3 pos, Light light) {
    vec3 startPos = pos;
    vec3 rayDir = normalize(light.position - pos);

    int i;
    for (i = 0; i < MAX_STEPS; ++i) {
        HitInfo hit = scene(pos);
        if (hit.dist < EPSILON) {
            return vec3(0); // TODO: Recurse into more hits
        }
        pos += min(hit.dist, length(light.position - pos)) * rayDir;
        if (distance(light.position, pos) < EPSILON) break;
    }

    // This will bleed light, but whatever
    return light.color * pow(length(light.position - startPos), -light.falloffExponent);
    // return vec3(1.0, 0.0, 1.0); // Too many steps to light :/
} 

vec3 trace(vec3 pos, vec3 rayDir) {

    HitInfo hit;

    for (int i = 0; i < MAX_STEPS; ++i) {
        hit = scene(pos);
        if (hit.dist < EPSILON) {
            vec3 incomingLight = vec3(0);

            vec3 offsetHitPosition = pos + hit.normal * EPSILON * 2;

            vec3 lightColorR = shadowRay(offsetHitPosition, sceneLightR);
            vec3 lightDirR = normalize(sceneLightR.position - pos);
            incomingLight += max(dot(lightDirR, hit.normal), 0) * lightColorR;
            
            vec3 lightColorG = shadowRay(offsetHitPosition, sceneLightG);
            vec3 lightDirG = normalize(sceneLightG.position - pos);
            incomingLight += max(dot(lightDirG, hit.normal), 0) * lightColorG;
            
            vec3 lightColorB = shadowRay(offsetHitPosition, sceneLightB);
            vec3 lightDirB = normalize(sceneLightB.position - pos);
            incomingLight += max(dot(lightDirB, hit.normal), 0) * lightColorB;

            // Handle bounces :D

            return incomingLight * hit.mat.color.xyz;
        }
        pos += rayDir * hit.dist;
    }

    return vec3(0);
}

void main() {

    sceneLightR.position = normalize(vec3(
        sin(time * 3 + 13.231),
        sin(time * 2 + .403),
        (cos(time * 0.5 + 4.123) - 1.5)
    )) * (1.0 + sin(time + 23.52) + 2.0) + vec3(0., 0., 4.5);
    
    sceneLightG.position = normalize(vec3(
        cos(time * 3 + 12.451),
        sin(time * 1 + 32.234),
        (cos(time * 0.2 + 8.43) - 1.5)
    )) * (1.0 + sin(time + 13.52) + 2.0) + vec3(0., 0., 4.5);
    
    sceneLightB.position = normalize(vec3(
        cos(time),
        sin(time * 2),
        (cos(time * 0.23) - 1.5)
    )) * (1.0 + sin(time + 7.52) + 2.0) + vec3(0., 0., 4.5);

    vec2 coord = ((fragTexCoord*2) - 1) * vec2(1.0, -aspectRatio);

    float screenDist = atan(PI * fov / 180.0);

    vec3 rayDir = normalize(vec3(coord, screenDist));

    vec3 pxColor = trace(vec3(0.0), rayDir);

    finalColor = vec4(tanh(pxColor), 1.0);
}
