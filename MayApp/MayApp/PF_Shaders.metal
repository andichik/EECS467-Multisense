//
//  PF_Shaders.metal
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/18.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

//kernel void A_star(texture4d<float, access::read> dangerMap[[texture(0)]], uint index [[ thread_position_in_grid]]) {
//    
//}

struct ScaleDownMapUniforms {
    uint32_t pfmapDiv;
    uint32_t pfmapDim;
};

kernel void scaleDownMap(texture2d<float, access::read> map [[texture(0)]],
                         texture2d<float, access::write> scaleDownMap [[texture(1)]],
//                         device float *scaleDownMap_buffer [[buffer(0)]],
                         constant ScaleDownMapUniforms &uniforms [[buffer(0)]],
                         uint2 threadPosition [[thread_position_in_grid]]) {
    
    // Check if in range of grid
    if (threadPosition.x > scaleDownMap.get_width() - 1 || threadPosition.y > scaleDownMap.get_height() - 1) {
        return;
    }
    
    // Start point in full-size map
    uint2 start = uint2(threadPosition.x * uniforms.pfmapDiv, threadPosition.y * uniforms.pfmapDiv);
    
    // Store largest occupancy probability
    float4 curr_max(-1.0f, 0.0f, 0.0f, 0.0f);
    
    // Index of Iteration
    uint2 index;
    
    // Find highest probability value within region
    for (index.x = start.x; index.x < start.x + uniforms.pfmapDiv; ++index.x) {
        for(index.y = start.y; index.y < start.y + uniforms.pfmapDiv; ++index.y) {
            
            float4 val = map.read(index); // Value from full resolution map
            if(val[0] > curr_max[0]) curr_max[0] = val[0];
        }
    }
    
    // Take the larger of the occupancy value.
    scaleDownMap.write(curr_max,threadPosition);
//    scaleDownMap.write(float4(1.0f, 0.0f, 0.0f, 0.0f),threadPosition);
    
}

struct MapVertex {
    
    float4 position [[position]];
    float2 textureCoordinate;
};

struct PathVertex {
    float4 position [[position]];
//    float2 textureCoordinate;
    float4 color;
};

struct PathUniforms {
    float4x4 projectionMatrix;
    int pathSize;
    int pfmapDim;
};

vertex MapVertex pfmapVertex(device MapVertex *verticies [[buffer(0)]],
                           constant Uniforms &uniforms [[buffer(1)]],
                           uint vid [[vertex_id]]) {
    
    MapVertex out;
    
    out.position = uniforms.projectionMatrix * verticies[vid].position;
    out.textureCoordinate = verticies[vid].textureCoordinate;
    
    return out;
}

fragment float4 pfmapFragment(MapVertex v [[stage_in]],
                            texture2d<float> mapTexture [[texture(0)]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    
//    for (int i = 0; i < uniforms.pathSize; ++i) {
//        if(float2(float(path[i].x),float(path[i].y) == v.textureCoordinate))
//            return float4(0.0, 1.0, 0.0, 1.0)
//    }
    
    float sample = mapTexture.sample(mapSampler, v.textureCoordinate).r;
    float color = 0.5 - 0.5 * sample;
    return float4(color, color, color, 1.0);
}

vertex float4 pathVertex(device MapVertex *verticies [[buffer(0)]],
                         device uint2 *pointBuffer [[buffer(1)]],
                             constant PathUniforms &uniforms [[buffer(2)]],
                             uint vid [[vertex_id]],
                             uint iid [[instance_id]]) {
    
    
//    PathVertex out;
    float4 out = uniforms.projectionMatrix * verticies[vid].position;
//    out.position = uniforms.projectionMatrix * verticies[vid].position;
//    out.textureCoordinate = verticies[vid].textureCoordinate;
    
//    uint x = uint((verticies[vid].textureCoordinate.x) * uniforms.pfmapDim);
//    uint y = uint((verticies[vid].textureCoordinate.y) * uniforms.pfmapDim);
    
//    if((x == pointBuffer[iid].x) && (y == pointBuffer[iid].x))
//        out.color = float4(1.0,1.0,1.0,1.0);
//    else
//        out.color = float4(0.0,0.0,0.0,1.0);
    
    return out;
    
}

fragment float4 pathFragment(PathVertex pathVertex [[stage_in]]) {
    
//    return pathVertex.color;
    return float4(1.0,1.0,1.0,1.0);
}


