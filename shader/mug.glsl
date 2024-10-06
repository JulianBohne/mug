#version 330

#define PI 3.1415926
#define EPSILON 0.001
#define MAX_STEPS 100
#define MAX_DEPTH 2

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

uniform float aspectRatio; // height / width
uniform float fov = 100.0; // horizontal

uniform float time = 0.0; // time in seconds

// Output fragment color
out vec4 finalColor;

float random(vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

vec3 rand3 (float seed) {
    return vec3(
        random(fragTexCoord + vec2(fract(time / 10.0) * 10.0 + 0.328, seed)), 
        random(fragTexCoord + vec2(fract(time / 12.0) * 12.0 + 1.203, seed)), 
        random(fragTexCoord + vec2(fract(time / 15.0) * 15.0 + 2.234, seed)));
}

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

HitInfo plane(vec3 pos, vec3 planePos, vec3 planeNormal, Material mat) {
    return HitInfo(
        mat,
        planeNormal,
        dot(pos - planePos, planeNormal)
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

const Material mattWhite = Material(
    vec4(1.0, 1.0, 1.0, 1.0), // color
    1.0 // roughness
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
        isinf(a.dist) || isinf(b.dist) ? a.dist : mix(a.dist, b.dist, t) 
    );
}

HitInfo or(HitInfo a, HitInfo b) {
    return a.dist <= b.dist ? a : b;
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
    return or(
        smooth_or(
            sphere(pos, spherePos, 1.0, sphereMat1),
            sphere(pos, vec3(cos(time * 0.9124) * 2, sin(time) * 2, 5.0), 1.0, sphereMat2),
            0.35
        ),
        plane(pos, vec3(0., -3.0, 0.), vec3(0., 1., 0.), mattWhite)
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

struct TraceStackItem {
    vec3 startPos;
    vec3 rayDir;
    float randomness;
    int raysRemaining;
    vec3 accLight;
};

TraceStackItem traceStack[MAX_DEPTH];

vec3 trace(vec3 rayDir) {

    int depth = 0;

    traceStack[0] = TraceStackItem(
        vec3(0.0), // ray starting position
        rayDir,    // ray direction
        0.0,       // ray direction randomness
        1,         // rays remaining
        vec3(0.0) // accumulated light contribution (color)
    );

    HitInfo hit;

    int i;

    float rayIndex = 0.0;

    while(depth >= 0) {

        if (traceStack[depth].raysRemaining <= 0) {
            // Accumulate colors further down
            --depth;
            continue;
        }

        --traceStack[depth].raysRemaining;
        vec3 pos = traceStack[depth].startPos;
        vec3 dir = normalize(traceStack[depth].rayDir + rand3(rayIndex++) * traceStack[depth].randomness);
        
        // TODO: Remove (this is just here because I don't acrually want to recurse further)
        if (depth == 1) {
            continue;
        }


        i = 0;
        do {
            hit = scene(pos);
            pos += rayDir * hit.dist;
            ++i;
        } while (hit.dist > EPSILON && i < MAX_STEPS);


        if (i == MAX_STEPS) {
            continue;
        } else {
            // Lift hit off of surface
            pos += hit.normal * EPSILON * 2;

            // TODO: Refactor lights
            vec3 lightColorR = shadowRay(pos, sceneLightR);
            vec3 lightDirR = normalize(sceneLightR.position - pos);
            traceStack[depth].accLight += max(dot(lightDirR, hit.normal), 0) * lightColorR * hit.mat.color.xyz;

            vec3 lightColorG = shadowRay(pos, sceneLightG);
            vec3 lightDirG = normalize(sceneLightG.position - pos);
            traceStack[depth].accLight += max(dot(lightDirG, hit.normal), 0) * lightColorG * hit.mat.color.xyz;
            
            vec3 lightColorB = shadowRay(pos, sceneLightB);
            vec3 lightDirB = normalize(sceneLightB.position - pos);
            traceStack[depth].accLight += max(dot(lightDirB, hit.normal), 0) * lightColorB * hit.mat.color.xyz;

            if (depth < MAX_DEPTH - 1) {
                traceStack[++depth] = TraceStackItem(
                    pos,                         // ray starting position
                    reflect(rayDir, hit.normal), // ray direction
                    0.0,                         // ray direction randomness
                    1,                           // rays remaining
                    vec3(0.0)                    // accumulated light contribution (color)
                );
            }
        }
    }

    return traceStack[0].accLight;
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

    vec3 pxColor = trace(rayDir);

    // Doing a little bit of a color transform to keep it between zero and 1 without hard clipping, but not getting too dark
    finalColor = vec4(pow(tanh(pxColor), vec3(0.75)), 1.0);

}
