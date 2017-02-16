//
//  Shaders.metal
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    
    float4 position;
};

struct ColorVertex {
    
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    
    float4x4 projectionMatrix;
};

vertex ColorVertex laserDistanceVertex(device Vertex *verticies [[buffer(0)]],
                                       constant Uniforms &uniforms [[buffer(1)]],
                                       uint vid [[vertex_id]]) {
    
    ColorVertex colorVertex;
    colorVertex.position = uniforms.projectionMatrix * verticies[vid].position;
    colorVertex.color = mix(float4(0.0, 0.5, 1.0, 1.0), float4(1.0, 1.0, 1.0, 1.0), 0.5);
    
    return colorVertex;
}

fragment float4 colorFragment(ColorVertex colorVertex [[stage_in]]) {
    
    return colorVertex.color;
}

vertex ColorVertex odometryVertex(device Vertex *verticies [[buffer(0)]],
                                       constant Uniforms &uniforms [[buffer(1)]],
                                       uint vid [[vertex_id]]) {
    
    ColorVertex colorVertex;
    colorVertex.position = uniforms.projectionMatrix * verticies[vid].position;
    colorVertex.color = float4(0.0, 0.0, 0.0, 1.0);
    
    return colorVertex;
}
