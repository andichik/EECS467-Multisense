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
                             device LaserPoint *laserPoints [[buffer(1)]],
                             constant CurvatureUniforms &uniforms [[buffer(2)]],
                             ushort i [[thread_position_in_grid]]) {
    
    if (i >= uniforms.distanceCount) {
        return;
    }
    
    const ushort kernalCount = 4;
    const ushort kernalSpacing = 4;
    const ushort kernalSize = kernalCount * kernalSpacing;
    
    // Ignore edges of vision
    if (i < kernalSize || i >= uniforms.distanceCount - kernalSize) {
        laserPoints[i].angleWidth = NAN;
        return;
    }
    
    // Ignore if any distances in kernal are invalid
    for (ushort j = i - kernalSize; j <= i + kernalSize; ++j) {
        
        if (!validDistance(distances[j], uniforms.minimumDistance, uniforms.maximumDistance)) {
            laserPoints[i].angleWidth = NAN;
            return;
        }
    }
    
    for (ushort j = i - kernalSize; j <= i + kernalSize - 1; ++j) {
        
        if (abs(distances[j] - distances[j + 1]) > 0.05) {
            laserPoints[i].angleWidth = NAN;
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
    
    laserPoints[i].angleWidth = acos(dot(prevAverageVector, nextAverageVector) / (length(prevAverageVector) * length(nextAverageVector)));
    laserPoints[i].startAngle = atan2(nextAverageVector.y, nextAverageVector.x);
    laserPoints[i].endAngle = atan2(-prevAverageVector.y, -prevAverageVector.x);
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
