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

struct IntermediateMapPointVertex {
    
    float4 position [[position]];
    float pointSize [[point_size]];
};

vertex IntermediateMapPointVertex mapPointVertex(device MapPoint *mapPoints [[buffer(0)]],
                                                 constant MapPointVertexUniforms &uniforms,
                                                 ushort vid [[vertex_id]]) {
    
    IntermediateMapPointVertex v;
    v.position = uniforms.projectionMatrix * mapPoints[vid].position;
    v.pointSize = uniforms.pointSize;
    
    return v;
}

fragment float4 mapPointFragment(IntermediateMapPointVertex v [[stage_in]],
                                 constant float4 &color [[buffer(0)]]) {
    
    return color;
}
