//
//  ShaderTypes.h
//  MayApp
//
//  Created by Russell Ladd on 3/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

// MARK: - Types

struct Pose {
    
    float4 position;
    float angle;
};

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

// MARK: - Samplers

constexpr sampler mapSampler;

#endif /* ShaderTypes_h */
