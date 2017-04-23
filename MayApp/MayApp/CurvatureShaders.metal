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

float angleDifference(float angle1, float angle2);
float vectorAngleDifference(float2 vec1, float2 vec2);

inline float2 projectDistance(float distance, float angle) {
    return float2(distance * cos(angle), distance * sin(angle));
}

inline bool validDistance(float distance, float minimum, float maximum) {
    return distance >= minimum && distance <= maximum;
}

float angleDifference(float angle1, float angle2) {
    
    float angle = angle2 - angle1;
    
    if (angle < -M_PI_F) {
        angle += 2.0f * M_PI_F;
    } else if (angle > M_PI_F) {
        angle -= 2.0f * M_PI_F;
    }
    
    return angle;
}

float vectorAngleDifference(float2 vec1, float2 vec2) {
    
    float angle1 = atan2(vec1.y, vec1.x);
    float angle2 = atan2(vec2.y, vec2.x);
    
    return angleDifference(angle1, angle2);
}

kernel void computeCurvature(device float *distances [[buffer(0)]],
                             device LaserPoint *laserPoints [[buffer(1)]],
                             constant CurvatureUniforms &uniforms [[buffer(2)]],
                             ushort i [[thread_position_in_grid]]) {
    
    if (i >= uniforms.distanceCount) {
        return;
    }
    
    const ushort kernalCount = 10;
    const ushort kernalSpacing = 2;
    const ushort kernalSize = kernalCount * kernalSpacing;
    
    // Ignore edges of vision
    if (i < kernalSize || i >= uniforms.distanceCount - kernalSize) {
        
        laserPoints[i].angleWidth = NAN;
        laserPoints[i].startAngle = NAN;
        laserPoints[i].endAngle = NAN;
        laserPoints[i].averagePrevAngle = NAN;
        laserPoints[i].averageNextAngle = NAN;
        laserPoints[i].prevDiscontinuity = true;
        laserPoints[i].nextDiscontinuity = true;
        //laserPoints[i].prevAngle = NAN;
        //laserPoints[i].nextAngle = NAN;
        
        return;
    }
    
    // Ignore if distances in kernal are invalid
    for (ushort j = i - kernalSize; j <= i + kernalSize; ++j) {
        
        if (!validDistance(distances[j], uniforms.minimumDistance, uniforms.maximumDistance)) {
            
            laserPoints[i].angleWidth = NAN;
            laserPoints[i].startAngle = NAN;
            laserPoints[i].endAngle = NAN;
            laserPoints[i].averagePrevAngle = NAN;
            laserPoints[i].averageNextAngle = NAN;
            laserPoints[i].prevDiscontinuity = true;
            laserPoints[i].nextDiscontinuity = true;
            //laserPoints[i].prevAngle = NAN;
            //laserPoints[i].nextAngle = NAN;
            
            return;
        }
    }
    
    // Ignore if discontinuities on both sides of kernal
    bool prevDiscontinuity = false;
    bool nextDiscontinuity = false;
    
    float discontinuityThreshold = 0.1;
    
    for (ushort j = i - kernalSize; j < i; ++j) {
        
        if (abs(distances[j] - distances[j + 1]) > discontinuityThreshold) {
            prevDiscontinuity = true;
            break;
        }
    }
    
    for (ushort j = i; j < i + kernalSize; ++j) {
        
        if (abs(distances[j] - distances[j + 1]) > discontinuityThreshold) {
            nextDiscontinuity = true;
            break;
        }
    }
    
    laserPoints[i].prevDiscontinuity = prevDiscontinuity;
    laserPoints[i].nextDiscontinuity = nextDiscontinuity;
    
    // Angle angle width, start and end angles
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
    
    // Ave prev angle
    float avePrevAngle = 0.0f;
    
    for (ushort j = 1; j < kernalCount; j++) {
        
        ushort j1 = j - 1;
        ushort j2 = j;
        ushort j3 = j + 1;
        
        float2 point1 = projectDistance(distances[i - j1 * kernalSpacing], uniforms.angleStart + float(i - j1 * kernalSpacing) * uniforms.angleIncrement);
        float2 point2 = projectDistance(distances[i - j2 * kernalSpacing], uniforms.angleStart + float(i - j2 * kernalSpacing) * uniforms.angleIncrement);
        float2 point3 = projectDistance(distances[i - j3 * kernalSpacing], uniforms.angleStart + float(i - j3 * kernalSpacing) * uniforms.angleIncrement);
        
        float2 vec1 = point2 - point1;
        float2 vec2 = point3 - point2;
        
        avePrevAngle += vectorAngleDifference(vec1, vec2);
    }
    
    avePrevAngle /= float(kernalCount - 1);
    
    laserPoints[i].averagePrevAngle = avePrevAngle;
    
    // Ave next angle
    float aveNextAngle = 0.0f;
    
    for (ushort j = 1; j < kernalCount; j++) {
        
        ushort j1 = j - 1;
        ushort j2 = j;
        ushort j3 = j + 1;
        
        float2 point1 = projectDistance(distances[i + j1 * kernalSpacing], uniforms.angleStart + float(i + j1 * kernalSpacing) * uniforms.angleIncrement);
        float2 point2 = projectDistance(distances[i + j2 * kernalSpacing], uniforms.angleStart + float(i + j2 * kernalSpacing) * uniforms.angleIncrement);
        float2 point3 = projectDistance(distances[i + j3 * kernalSpacing], uniforms.angleStart + float(i + j3 * kernalSpacing) * uniforms.angleIncrement);
        
        float2 vec1 = point2 - point1;
        float2 vec2 = point3 - point2;
        
        aveNextAngle += vectorAngleDifference(vec1, vec2);
    }
    
    aveNextAngle /= float(kernalCount - 1);
    
    laserPoints[i].averageNextAngle = aveNextAngle;
    
    // Prev and next angle
    
    /*float2 prevPoint = projectDistance(distances[i - 1], uniforms.angleStart + float(i - 1) * uniforms.angleIncrement);
    float2 nextPoint = projectDistance(distances[i + 1], uniforms.angleStart + float(i + 1) * uniforms.angleIncrement);
    
    float2 prevVec = prevPoint - point;
    float2 nextVec = nextPoint - point;
    
    laserPoints[i].prevAngle = vectorAngleDifference(-nextAverageVector, prevVec);
    laserPoints[i].nextAngle = vectorAngleDifference(-prevAverageVector, nextVec);*/
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
