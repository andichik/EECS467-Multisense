//
//  VectorMapShaders.metal
//  MayApp
//
//  Created by Russell Ladd on 4/2/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"
#include "VectorMapTypes.h"

vertex float4 mapPointVertex(device MapPoint *mapPoints [[buffer(0)]],
                             constant MapPointVertexUniforms &uniforms,
                             ushort vid [[vertex_id]],
                             ushort iid [[instance_id]]) {
    
    MapPoint point = mapPoints[iid];
    
    if (vid == uniforms.outerVertexCount) {
        return uniforms.projectionMatrix * point.position;
    }
    
    float angleIncrement = fmod(point.endAngle - point.startAngle + 2.0f * M_PI_F, 2.0f * M_PI_F) / float(uniforms.outerVertexCount - 1);
    
    float angle = point.startAngle + float(vid) * angleIncrement;
    
    float4 outerPoint = point.position + 0.2 * float4(cos(angle), sin(angle), 0.0, 0.0);
    
    return uniforms.projectionMatrix * outerPoint;
}

fragment float4 mapPointFragment(constant float4 &color [[buffer(0)]]) {
    
    return color;
}
