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
    
    float4 robotPosition;        // meters
    float robotAngle;            // radians
    
    float mapTexelsPerMeter;     // texels per meter
    
    float laserAngleStart;       // radians
    float laserAngleWidth;       // radians
    
    float minimumLaserDistance;  // meters
    float laserDistanceAccuracy; // meters
    
    float dOccupancy;
};

constexpr sampler laserDistanceSampler(address::clamp_to_zero, filter::linear);

// Texture objects do not need an address space qualifier - they are assumed to be allocated from *device* memory
// Using the constant address space because many instances will be accessing each distance (see note in section 4.2.3 of Metal Shading Language Spec)
kernel void updateMap(texture2d<float, access::read> oldMap [[texture(0)]],
                      texture2d<float, access::write> newMap [[texture(1)]],
                      texture1d<uint, access::sample> laserDistances [[texture(2)]],
                      constant MapUniforms &uniforms [[buffer(0)]],
                      uint2 threadPositon [[thread_position_in_grid]]) {
    
    float occupancy = oldMap.read(threadPositon).r;
    
    float dOccupancy = 0.0;
    
    // Position in meters
    float2 texelPosition = (float2(threadPositon) - 0.5 * float2(oldMap.get_width(), oldMap.get_height()) + float2(0.5)) / uniforms.mapTexelsPerMeter;
    
    float2 offset = texelPosition - uniforms.robotPosition.xy;
    
    float texelDistance = length(offset);
    
    if (texelDistance >= uniforms.minimumLaserDistance) {
        
        float absoluteTexelAngle = atan2(offset.y, offset.x);
        
        // Relative to robot heading, in [-pi, pi]
        float relativeTexelAngle = fmod(absoluteTexelAngle - uniforms.robotAngle, 2.0 * M_PI_F);
        
        // Relative angle [start, start + width] -> [0.0, 1.0]
        float laserSampleCoord = (relativeTexelAngle - uniforms.laserAngleStart) / uniforms.laserAngleWidth;
        
        // Sampler clamps to zero when addressing outside of the distances texture, meaning distances of zero are returned
        // This is the same as ignoring these values, since we do not change the occupancy for texels beyond the distance
        float laserDistance = 0.001 * float(laserDistances.sample(laserDistanceSampler, laserSampleCoord).r);
        
        if (abs(texelDistance - laserDistance) < uniforms.laserDistanceAccuracy) {
            dOccupancy = uniforms.dOccupancy;
        } else if (texelDistance < laserDistance) {
            dOccupancy = -uniforms.dOccupancy;
        }
    }
    
    float newOccupancy = clamp(occupancy + dOccupancy, -1.0, 1.0);
    
    newMap.write(float4(newOccupancy, 0.0, 0.0, 0.0), threadPositon);
}

// Vertex shader input
struct MapVertex {
    
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex MapVertex mapVertex(device MapVertex *verticies [[buffer(0)]],
                           constant Uniforms &uniforms [[buffer(1)]],
                           uint vid [[vertex_id]]) {
    
    MapVertex out;
    
    out.position = uniforms.projectionMatrix * verticies[vid].position;
    out.textureCoordinate = verticies[vid].textureCoordinate;
    
    return out;
}

constexpr sampler mapSampler;

fragment float4 mapFragment(MapVertex v [[stage_in]],
                            texture2d<float> mapTexture [[texture(0)]]) {
    
    float sample = mapTexture.sample(mapSampler, v.textureCoordinate).r;
    
    float color = 0.5 - 0.5 * sample;
    
    return float4(color, color, color, 1.0);
}

// MARK: - Shared functions

fragment float4 colorFragment(ColorVertex colorVertex [[stage_in]]) {
    
    return colorVertex.color;
}

