//
//  PF_Shaders.metal
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/18.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

//kernel void A_star(texture4d<float, access::read> dangerMap[[texture(0)]], uint index [[ thread_position_in_grid]]) {
//    
//}

struct ScaleDownMapUniforms {
    uint32_t pfmapDiv;
    uint32_t pfmapDim;
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
                             
}
