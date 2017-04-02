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
    
                                // The start and end angles sweep counterclockwise through free space
                                // Either may be NAN to indicate unknown
    float startAngle;           // angle in world space with occupied space on right and free space on left
    float endAngle;             // angle in world space with occupied space on left and free space on right
    
    ushort count;
};

struct MapPointVertexUniforms {
    
    matrix_float4x4 projectionMatrix;
    float pointSize;
};

#endif /* VectorMapTypes_h */
