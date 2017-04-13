//
//  ParticleTypes.h
//  MayApp
//
//  Created by Russell Ladd on 4/9/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#ifndef ParticleTypes_h
#define ParticleTypes_h

#include <simd/SIMD.h>

struct ParticleRenderUniforms {
    
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewProjectionMatrix;
    matrix_float4x4 mapScaleMatrix;
    vector_float4 color;
};

#endif /* ParticleTypes_h */
