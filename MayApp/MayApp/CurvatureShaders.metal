//
//  CurvatureShaders.metal
//  MayApp
//
//  Created by Russell Ladd on 3/28/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"
#include "CurvatureUniforms.h"

inline float2 projectDistance(float distance, float angle) {
    return float2(distance * cos(angle), distance * sin(angle));
}

inline bool validDistance(float distance, float minimum, float maximum) {
    return distance >= minimum && distance <= maximum;
}

kernel void computeCurvature(device LaserDistanceVertex *distances [[buffer(0)]],
                             device float *curvatures [[buffer(1)]],
                             constant CurvatureUniforms &uniforms [[buffer(2)]],
                             ushort i [[thread_position_in_grid]]) {
    
    if (i < 1 || i >= uniforms.distanceCount - 1) {
        curvatures[i] = NAN;
        return;
    }
    
    float distance = distances[i].distance;
    float prevDistance = distances[i - 1].distance;
    float nextDistance = distances[i + 1].distance;
    
    // Check for invalid distances
    if (!validDistance(distance, uniforms.minimumDistance, uniforms.maximumDistance) ||
        !validDistance(distance, uniforms.minimumDistance, uniforms.maximumDistance) ||
        !validDistance(distance, uniforms.minimumDistance, uniforms.maximumDistance)) {
        curvatures[i] = NAN;
        return;
    }
    
    float angle = uniforms.angleStart + float(i) * uniforms.angleIncrement;
    
    float2 p = projectDistance(distances[i].distance, angle);
    
    float2 prevP = projectDistance(prevDistance, angle - uniforms.angleIncrement);
    float2 nextP = projectDistance(nextDistance, angle + uniforms.angleIncrement);
    
    // Angles
    
    float2 a = nextP - p;
    float2 b = prevP - p;
    
    curvatures[i] = acos(dot(a, b) / (length(a) * length(b)));
    
    // Planar curvature
    
    /*
    float2 nextPPrime = nextP - p;
    float2 prevPPrime = p - prevP;
    
    float2 pPrime = 0.5 * (prevPPrime + nextPPrime);
    float2 pPrimePrime = nextPPrime - prevPPrime;
    
    curvatures[i] = (pPrime.x * pPrimePrime.y - pPrime.y * pPrimePrime.x) / pow(length_squared(pPrime), 1.5);
    */
}

struct IntermediateCornerVertex {
    
    float4 position [[position]];
    float pointSize [[point_size]];
};

vertex IntermediateCornerVertex cornersVertex(device LaserDistanceVertex *distances [[buffer(0)]],
                                              constant CornerUniforms &uniforms,
                                              ushort vid [[vertex_id]]) {
    
    float angle = uniforms.angleStart + float(vid) * uniforms.angleIncrement;
    float distance = distances[vid].distance;
    
    IntermediateCornerVertex v;
    v.position = uniforms.projectionMatrix * float4(distance * cos(angle), distance * sin(angle), 0.0, 1.0);
    v.pointSize = 5.0;
    
    return v;
}

fragment float4 cornersFragment(IntermediateCornerVertex v [[stage_in]]) {
    return float4(1.0, 0.0, 0.0, 1.0);
}
