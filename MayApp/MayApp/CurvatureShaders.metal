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

kernel void computeCurvature(device float *distances [[buffer(0)]],
                             device float *curvatures [[buffer(1)]],
                             constant CurvatureUniforms &uniforms [[buffer(2)]],
                             ushort i [[thread_position_in_grid]]) {
    
    const ushort kernalCount = 4;
    const ushort kernalSpacing = 4;
    const ushort kernalSize = kernalCount * kernalSpacing;
    
    // Ignore edges of vision
    if (i < kernalSize || i >= uniforms.distanceCount - kernalSize) {
        curvatures[i] = NAN;
        return;
    }
    
    // Ignore if any distances in kernal are invalid
    for (ushort j = i - kernalSize; j <= i + kernalSize; ++j) {
        
        if (!validDistance(distances[j], uniforms.minimumDistance, uniforms.maximumDistance)) {
            curvatures[i] = NAN;
            return;
        }
    }
    
    for (ushort j = i - kernalSize; j <= i + kernalSize - 1; ++j) {
        
        if (abs(distances[j] - distances[j + 1]) > 0.05) {
            curvatures[i] = NAN;
            return;
        }
    }
    
    float angle = uniforms.angleStart + float(i) * uniforms.angleIncrement;
    
    float2 point = projectDistance(distances[i], angle);
    
    float2 prevAverageVector = float2(0.0);
    float2 nextAverageVector = float2(0.0);
    
    for (ushort j = i - kernalSize; j < i; j += kernalSpacing) {
        prevAverageVector += point - projectDistance(distances[j], uniforms.angleStart + float(j) * uniforms.angleIncrement);
    }
    
    for (ushort j = i + kernalSize; j > i; j -= kernalSpacing) {
        nextAverageVector += projectDistance(distances[j], uniforms.angleStart + float(j) * uniforms.angleIncrement) - point;
    }
    
    prevAverageVector /= float(kernalCount);
    nextAverageVector /= float(kernalCount);
    
    curvatures[i] = acos(dot(prevAverageVector, nextAverageVector) / (length(prevAverageVector) * length(nextAverageVector)));
    
    /*float prevDistance = distances[i - 1].distance;
    float currDistance = distances[i].distance;
    float nextDistance = distances[i + 1].distance;
    
    // Check for invalid distances
    if (!validDistance(prevDistance, uniforms.minimumDistance, uniforms.maximumDistance) ||
        !validDistance(currDistance, uniforms.minimumDistance, uniforms.maximumDistance) ||
        !validDistance(nextDistance, uniforms.minimumDistance, uniforms.maximumDistance)) {
        curvatures[i] = NAN;
        return;
    }
    
    float distanceD1 = (nextDistance - prevDistance) / (2.0f * uniforms.angleIncrement);
    
    float distanceD2 = (nextDistance - 2.0 * currDistance + prevDistance) / (uniforms.angleIncrement * uniforms.angleIncrement);
    
    curvatures[i] = (currDistance * currDistance + 2.0 * distanceD1 * distanceD1 - currDistance * distanceD2) / pow(currDistance * currDistance + distanceD1 * distanceD1, 1.5);
    */
    
    //float angle = uniforms.angleStart + float(i) * uniforms.angleIncrement;
    
    //float2 p = projectDistance(distance, angle);
    
    //float2 prevP = projectDistance(prevDistance, angle - uniforms.angleIncrement);
    //float2 nextP = projectDistance(nextDistance, angle + uniforms.angleIncrement);
    
    // Anglular curvature
    
    /*
    float2 a = nextP - p;
    float2 b = prevP - p;
    
    curvatures[i] = acos(dot(a, b) / (length(a) * length(b)));
    */
    
    // Polar curvature
    
    // h = 2
    //float distanceD1 = (nextDistance - prevDistance) / (2.0f * uniforms.angleIncrement);
    
    // h = 1
    //float distanceD2 = (nextDistance - (2.0f * currDistance) + prevDistance) / (uniforms.angleIncrement * uniforms.angleIncrement);
    
    //curvatures[i] = ((currDistance * currDistance) + (2.0f * distanceD1 * distanceD1) - (currDistance * distanceD2)) / pow((currDistance * currDistance) + (distanceD1 * distanceD1), 1.5);
    
    // Euclidean curvature
    
    /*
    float2 nextPPrime = nextP - p;
    float2 prevPPrime = p - prevP;
    
    float2 pPrime = 0.5 * (prevPPrime + nextPPrime);
    float2 pPrimePrime = nextPPrime - prevPPrime;
    
    curvatures[i] = (pPrime.x * pPrimePrime.y - pPrime.y * pPrimePrime.x) / pow(length_squared(pPrime), 1.5);
    */
    
    // h = 2
    //float2 pD1 = 0.5 * (nextP - prevP);
    
    // h = 1
    //float2 pD2 = nextP - 2.0 * p + prevP;
    
    //curvatures[i] = (pD1.x * pD2.y - pD1.y * pD2.x) / pow(length_squared(pD1), 1.5);
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
    v.pointSize = uniforms.pointSize;
    
    return v;
}

fragment float4 cornersFragment(IntermediateCornerVertex v [[stage_in]],
                                constant float4 &color [[buffer(0)]]) {
    
    return color;
}
