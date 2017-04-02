//
//  VectorMapTypes.h
//  MayApp
//
//  Created by Russell Ladd on 4/2/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#ifndef VectorMapTypes_h
#define VectorMapTypes_h

#include <simd/SIMD.h>

struct MapPoint {
    vector_float4 position;
    vector_float2 stddev;
    float orientation;  // center of angle (in degrees from home/0/X-axis)
    float width;        // width of free space
    ushort count;
};

struct MapPointVertexUniforms {
    
    matrix_float4x4 projectionMatrix;
    float pointSize;
};

#endif /* VectorMapTypes_h */
