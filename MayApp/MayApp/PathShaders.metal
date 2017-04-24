//
//  PathShaders.metal
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/18.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"
#include "ParticleTypes.h"

//kernel void A_star(texture4d<float, access::read> dangerMap[[texture(0)]], uint index [[ thread_position_in_grid]]) {
//    
//}

struct ScaleDownMapUniforms {
    uint32_t pfmapDiv;
    uint32_t pfmapDim;
    uint32_t pfmapRange;
    uint2 pose;
};

kernel void scaleDownMap(texture2d<float, access::read> map [[texture(0)]],
                         texture2d<float, access::write> scaleDownMap [[texture(1)]],
                         device float *scaleDownMap_buffer [[buffer(0)]],
                         constant ScaleDownMapUniforms &uniforms [[buffer(1)]],
                         uint2 threadPosition [[thread_position_in_grid]]) {
    
    // Check if in range of grid
    if (threadPosition.x > scaleDownMap.get_width() - 1 || threadPosition.y > scaleDownMap.get_height() - 1) {
        return;
    }
    
    // Calculate effective search dimension
    uint32_t searchRange = max(uniforms.pfmapRange, uniforms.pfmapDiv);
    
    // Initialize output value
    float outValue(0.0);
    
    uint2 dist = uniforms.pose;
    dist.x = (dist.x > threadPosition.x) ? dist.x - threadPosition.x : threadPosition.x - dist.x;
    dist.y = (dist.y > threadPosition.y) ? dist.y - threadPosition.y : threadPosition.y - dist.y;
    
    uint32_t boundary = (uniforms.pose.x > dist.y) ? uniforms.pose.x - dist.y : 0;
    
    if ((dist.x < (searchRange / uniforms.pfmapDiv / 2)) && (dist.y < (searchRange/ uniforms.pfmapDiv / 2))) {
        
        outValue = -1.0;
        
    } else if (threadPosition.x < boundary) {
        
        outValue = INFINITY; // Strictly occupied
        
    } else if (uint32_t(sqrt(powr(float(dist.x), 2.0) + powr(float(dist.y), 2.0))) > (uniforms.pfmapDim / 2)) {
        
        outValue = INFINITY; // Strictly occupied
        
    } else {
        
        // Start point in full-resolution map
        uint2 start = uint2(threadPosition.x * uniforms.pfmapDiv, threadPosition.y * uniforms.pfmapDiv);
        start.x = (start.x < searchRange) ? 0 : start.x - (searchRange - uniforms.pfmapDiv) / 2;
        start.y = (start.y < searchRange) ? 0 : start.y - (searchRange - uniforms.pfmapDiv) / 2;
        
        // End point in full-resolution map
        uint2 end = uint2(min(start.x + searchRange, map.get_width()), min(start.y + searchRange, map.get_height()));
        
        // Store largest occupancy probability
        //    float currMax(-1.0);
        float avgValue(0.0);
        
        // Index of Iteration
        uint2 index;
        
        // Find highest probability value within region
        for (index.x = start.x; index.x < end.x; ++index.x) {
            for(index.y = start.y; index.y < end.y; ++index.y) {
                
                float4 val = map.read(index); // Value from full resolution map
                //            if(val[0] > currMax) currMax = val[0];
                if(val[0] > 0.0) val[0] = max(val[0],1.8);
                avgValue += val[0];
            }
        }
        
        // Average out sum of occupancy value
        outValue = avgValue / (uniforms.pfmapDiv * uniforms.pfmapDiv);
    }

    // Take the larger of the occupancy value.
    scaleDownMap.write(float4(outValue,0.0,0.0,0.0),threadPosition);
    scaleDownMap_buffer[threadPosition.y * scaleDownMap.get_width() + threadPosition.x] = outValue;
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
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewProjectionMatrix;
    matrix_float4x4 mapScaleMatrix;
};

vertex MapVertex pfmapVertex(device MapVertex *verticies [[buffer(0)]],
                           constant PathUniforms &uniforms [[buffer(1)]],
                           uint vid [[vertex_id]]) {
    
    MapVertex out;
    
    out.position = uniforms.projectionMatrix * verticies[vid].position;
    out.textureCoordinate = verticies[vid].textureCoordinate;
    
    return out;
}

fragment float4 pfmapFragment(MapVertex v [[stage_in]],
                            texture2d<float> mapTexture [[texture(0)]],
                              constant PathUniforms &uniforms [[buffer(0)]]) {
    float sample = mapTexture.sample(mapSampler, v.textureCoordinate).r;
    
    if (sample == INFINITY) {
        discard_fragment();
    } else {
        float color = 0.5 - 0.5 * sample;
        return float4(color, color, color, 1.0);
    }
}

vertex float4 pathVertex(device MapVertex *verticies [[buffer(0)]],
//                         device uint2 *pointBuffer [[buffer(1)]],
                             constant PathUniforms &uniforms [[buffer(1)]],
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


