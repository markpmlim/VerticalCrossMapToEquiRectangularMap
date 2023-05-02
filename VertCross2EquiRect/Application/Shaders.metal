//
//  Shaders.metal
//  
//
//

#include <metal_stdlib>

using namespace metal;

typedef struct {
    float4 clip_pos [[position]];
    float2 uv;
} ScreenFragment;

/*
 No geometry are passed to this vertex shader; the range of vid: [0, 2]
 The position and texture coordinates attributes of 3 vertices are
 generated on the fly.
 clip_pos: (-1.0, -1.0), (-1.0,  3.0), (3.0, -1.0)
       uv: ( 0.0,  1.0), ( 0.0, -1.0), (2.0,  1.0)
 The area of the generated triangle covers the entire 2D clip-space.
 Note: any geometry rendered outside this 2D space is clipped.
 Clip-space:
 Range of position: [-1.0, 1.0]
       Range of uv: [ 0.0, 1.0]
 The origin of the uv axes starts at the top left corner of the
   2D clip space with u-axis from left to right and
   v-axis from top to bottom
 For the mathematically inclined, the equation of the line joining
 the 2 points (-1.0,  3.0), (3.0, -1.0) is
        y = -x + 2
 The point (1.0, 1.0) lies on this line. The other 3 points which make up
 the 2D clipspace lie on the lines x=-1 or x=1 or y=-1 or y=1
 */

vertex ScreenFragment
vertexShader(uint vid [[vertex_id]]) {
    // from "Vertex Shader Tricks" by AMD - GDC 2014
    ScreenFragment out;
    out.clip_pos = float4((float)(vid / 2) * 4.0 - 1.0,
                          (float)(vid % 2) * 4.0 - 1.0,
                          0.0,
                          1.0);
    out.uv = float2((float)(vid / 2) * 2.0,
                    1.0 - (float)(vid % 2) * 2.0);
    return out;
}


/*
 The range of uv: [0.0, 1.0]
 The origin of the Metal texture coord system is at the upper-left of the quad.
 */
fragment half4
fragmentShader(ScreenFragment  in  [[stage_in]],
               texture2d<half> tex [[texture(0)]]) {

    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    half4 out_color = tex.sample(textureSampler, in.uv);
    return out_color;
}

/*
 Convert the direction vector into a pair of texture coords
  and a face index.
 */
float2 directionToCubeFaceUV(float3 direction,
                             thread uint &faceIndex) {

    float absX = fabs(direction.x);
    float absY = fabs(direction.y);
    float absZ = fabs(direction.z);
    
    bool isXPositive = direction.x > 0 ? true : false;
    bool isYPositive = direction.y > 0 ? true : false;
    bool isZPositive = direction.z > 0 ? true : false;
    
    float maxAxis = 0.0, sc = 0.0, tc = 0.0;
    
    // POSITIVE X
    if (isXPositive && absX >= absY && absX >= absZ) {
        maxAxis = absX;
        sc = -direction.z;
        tc = -direction.y;
        faceIndex = 0;
    }
    // NEGATIVE X
    if (!isXPositive && absX >= absY && absX >= absZ) {
        maxAxis = absX;
        sc = direction.z;
        tc = -direction.y;
        faceIndex = 1;
    }
    // POSITIVE Y
    if (isYPositive && absY >= absX && absY >= absZ) {
        maxAxis = absY;
        sc = direction.x;
        tc = direction.z;
        faceIndex = 2;
    }
    // NEGATIVE Y
    if (!isYPositive && absY >= absX && absY >= absZ) {
        maxAxis = absY;
        sc = direction.x;
        tc = -direction.z;
        faceIndex = 3;
    }
    // POSITIVE Z
    if (isZPositive && absZ >= absX && absZ >= absY) {
        maxAxis = absZ;
        sc = direction.x;
        tc = -direction.y;
        faceIndex = 4;
    }
    // NEGATIVE Z
    if (!isZPositive && absZ >= absX && absZ >= absY) {
        maxAxis = absZ;
        //sc = -direction.x;
        //tc = -direction.y;
        // This face must be flipped horizontally and vertically.
        sc = direction.x;
        tc = direction.y;
        faceIndex = 5;
    }
    /*
     s   =   ( sc/|ma| + 1 ) / 2
     t   =   ( tc/|ma| + 1 ) / 2
     
     where ma = maxAxis
     
     */
    
    // Convert range from -1 to 1 to 0 to 1
    float s = 0.5 * (sc / maxAxis + 1.0);
    float t = 0.5 * (tc / maxAxis + 1.0);
    return float2(s, t);
}

// These are the positions of the top left corner of each square making
//  up the 3x4 rectangular grid of 12 squares. Only need to map to 6 of them.
constant float2 topLeftCorners[] = {
    float2(2.0, 1.0),   // +X face
    float2(0.0, 1.0),   // -X face
    float2(1.0, 0.0),   // +Y face
    float2(1.0, 2.0),   // -Y face
    float2(1.0, 1.0),   // +Z face
    float2(1.0, 3.0),   // -Z face
};

/*
 Map the uv to a 3x4 rectangular grid of squares, each of the 12 squares
  being 1x1 squared units.
 The range is [0.0, 1.0] for both uv.x and uv.y;
 */
float2 mapTo3by4Grid(float2 uv, uint faceIndex) {
    // Translate the uv of the fragment to the correct square.
    float2 uv2 = uv + topLeftCorners[faceIndex];
    // Range of uv2.x: [0.0, 3.0]
    // Range of uv2.y: [0.0, 4.0]
    // Caller must do a scale down before accessing the vertical cross texture.
    return uv2;
}

/*
 Metal's texture coordinate system has its origin at the top left corner
  with its positive u-axis pointing right
  and its positive v-axis pointing down
 */
fragment half4
vertCross2ERPShader(ScreenFragment  in  [[stage_in]],
                    texture2d<half> tex [[texture(0)]]) {

    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    float2 uv = in.uv;
    // Map uv's range from [0.0, 1.0) --> [-1.0, 1.0)
    uv = 2.0 * uv - 1.0;

    float longitude = uv.x * M_PI_F;    // Range for longitude = [-π, π]
    float latitude = uv.y * M_PI_2_F;   //  Range for latitude = [-π/2, π/2]
    // We need to flip the y-direction
    float3 dir = float3(cos(latitude) * sin(longitude),
                        -sin(latitude),
                        cos(latitude) * cos(longitude));

    // Convert direction vector to a pair of uv's and a face index
    uint faceIndex = 0;

    uv = directionToCubeFaceUV(dir, faceIndex);

    // Map it to a 3x4 rectangular grid of 12 squares.
    uv = mapTo3by4Grid(uv, faceIndex);

    // Scale it down to [0.0, 1.0]
    uv /= float2(3.0, 4.0);
 
    // Access the vertical cross texture passed as parameter
    half4 out_color = tex.sample(textureSampler, uv);
    return out_color;
}
