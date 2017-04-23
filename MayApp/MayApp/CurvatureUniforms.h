//
//  CurvatureUniforms.h
//  MayApp
//
//  Created by Russell Ladd on 3/28/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#ifndef CurvatureUniforms_h
#define CurvatureUniforms_h

#include <simd/SIMD.h>

struct CurvatureUniforms {
    
    ushort distanceCount;
    
    float angleStart;
    float angleIncrement;
    
    float minimumDistance;  // meters
    float maximumDistance;  // meters
};

struct CornerUniforms {
    
    matrix_float4x4 projectionMatrix;
    
    float angleStart;
    float angleIncrement;
    
    float pointSize;
};

struct LaserPoint {
    
    float angleWidth;
    float startAngle;
    float endAngle;
    
    float averagePrevAngle;
    float averageNextAngle;
    
    bool prevDiscontinuity;
    bool nextDiscontinuity;
    
    //float prevAngle;
    //float nextAngle;
};

#endif /* CurvatureUniforms_h */
