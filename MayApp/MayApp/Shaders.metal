//
//  Shaders.metal
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Type definitions

// Vertex shader input
struct Vertex {
    
    float4 position;
};

// Vertex shader output / fragment shader input
struct ColorVertex {
    
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    
    float4x4 projectionMatrix;
};

// MARK: - Laser distance functions

vertex ColorVertex laserDistanceVertex(device Vertex *verticies [[buffer(0)]],
                                       constant Uniforms &uniforms [[buffer(1)]],
                                       uint vid [[vertex_id]]) {
    
    ColorVertex colorVertex;
    colorVertex.position = uniforms.projectionMatrix * verticies[vid].position;
    colorVertex.color = mix(float4(0.0, 0.5, 1.0, 1.0), float4(1.0, 1.0, 1.0, 1.0), 0.5);
    
    return colorVertex;
}

// MARK: - Odometry functions

vertex ColorVertex odometryVertex(device Vertex *verticies [[buffer(0)]],
                                       constant Uniforms &uniforms [[buffer(1)]],
                                       uint vid [[vertex_id]]) {
    
    ColorVertex colorVertex;
    colorVertex.position = uniforms.projectionMatrix * verticies[vid].position;
    colorVertex.color = float4(0.0, 0.0, 0.0, 1.0);
    
    return colorVertex;
}

// MARK: - Map functions

struct MapUniforms {
    
    float4 robotPosition;
    float robotAngle;
    
    float laserAngleStart;
    float laserAngleIncrement;
    
    uint laserDistancesCount;
};

// Texture objects do not need an address space qualifier - they are assumed to be allocated from *device* memory
// Using the constant address space because many instances will be accessing each distance (see note in section 4.2.3 of Metal Shading Language Spec)
kernel void updateMap(texture2d<float, access::read_write> map [[texture(0)]],
                      constant uint *laserDistances [[buffer(0)]]
                      constant MapUniforms &uniforms [[buffer(1)]],
                      uint2 threadPositon [[thread_position_in_grid]]) {
    
    // Update map
}


// MARK: - Shared functions

fragment float4 colorFragment(ColorVertex colorVertex [[stage_in]]) {
    
    return colorVertex.color;
}

