//
//  ParticleShaders.metal
//  MayApp
//
//  Created by Russell Ladd on 3/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

// MARK: - Moving particles

struct OdometryUpdates {
    
    float4 dPosition;
    float dAngle;
};

struct ParticleUpdateUniforms {
    
    uint numOfParticles;
    
    uint randSeedR1;
    uint randSeedT;
    uint randSeedR2;
    
    float rotationErrorFromRotation;
    float rotationErrorFromTranslation;
    float translationErrorFromRotation;
    float translationErrorFromTranslation;
    
    OdometryUpdates odometryUpdates;
};

float generateUniformRand(uint seed, uint unique);
float2 gaussianFromUniform(float u1, float u2);

// Generates a uniform random number in [0.0, 1.0]
float generateUniformRand(uint x, uint y) {
    
    int z = 467;
    
    int seed = x + y * 57 + z * 241;
    seed = (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

// Box-Muller transform
float2 gaussianFromUniform(float u1, float u2) {
    
    float z1 = sqrt(-2.0f * log(u1)) * cos(2.0f * M_PI_F * u2);
    float z2 = sqrt(-2.0f * log(u1)) * sin(2.0f * M_PI_F * u2);
    return float2(z1, z2);
}

// The action error model is calculated according to Lec 5, EECS467 W15.
kernel void updateParticles(device Pose *oldParticles [[buffer(0)]],
                            device Pose *newParticles [[buffer(1)]],
                            constant ParticleUpdateUniforms &uniforms [[buffer(2)]],
                            uint threadPosition [[thread_position_in_grid]]) {
    
    if (threadPosition >= uniforms.numOfParticles) {
        return;
    }
    
    // Generate random numbers sampled from gaussian distribution
    
    float uRandR1 = generateUniformRand(uniforms.randSeedR1, threadPosition);
    float uRandT = generateUniformRand(uniforms.randSeedT, threadPosition);
    float uRandR2 = generateUniformRand(uniforms.randSeedR2, threadPosition);
    
    float2 gRand1 = gaussianFromUniform(uRandR1, uRandT);
    float2 gRand2 = gaussianFromUniform(uRandR2, uRandT);
    
    float gRandR1 = gRand1.x;
    float gRandT = gRand1.y;
    float gRandR2 = gRand2.x;
    
    // Get current pose
    
    Pose oldPose = oldParticles[threadPosition];
    OdometryUpdates odometryUpdates = uniforms.odometryUpdates;
    
    // Rotate odometryUpdate to match pose
    
    odometryUpdates.dPosition.xy = float2x2(float2(cos(oldPose.angle), sin(oldPose.angle)), float2(-sin(oldPose.angle), cos(oldPose.angle))) * odometryUpdates.dPosition.xy;
    
    // Calculate rot1, trans, and rot2
    
    float rot1 = 0.0;
    if (odometryUpdates.dPosition.x != 0.0 || odometryUpdates.dPosition.y != 0.0) {
        rot1 = atan2(odometryUpdates.dPosition.y, odometryUpdates.dPosition.x) - oldPose.angle;
        rot1 = fmod(rot1 + M_PI_F, 2.0f * M_PI_F) - M_PI_F;
    }
    
    float trans = length(odometryUpdates.dPosition.xy);
    float rot2 = odometryUpdates.dAngle - rot1;
    rot2 = fmod(rot2 + M_PI_F, 2.0f * M_PI_F) - M_PI_F;
    
    // Add noise
    
    float noisyRot1 = rot1 - gRandR1 * 0.03; //- gRandR1 * (uniforms.rotationErrorFromRotation * rot1 + uniforms.rotationErrorFromTranslation * trans);
    float noisyTrans = trans - gRandT * 0.005; //- gRandT * (uniforms.translationErrorFromTranslation * trans + uniforms.translationErrorFromRotation * (rot1 + rot2));
    float noisyRot2 = rot2 - gRandR2 * 0.03; // * (uniforms.rotationErrorFromRotation * rot2 /*+ uniforms.rotationErrorFromTranslation * trans*/);
    
    //float epsilon1 = abs(alpha) * uniforms.errRangeR * gRandR;
    //float epsilon2 = ds * uniforms.errRangeT * gRandT;
    //float epsilon3 = abs(beta) * uniforms.errRangeR * gRandR;
    
    //float dx = (ds + epsilon2) * cos(oldPose.angle + alpha + epsilon1);
    //float dy = (ds + epsilon2) * sin(oldPose.angle + alpha + epsilon1);
    //float dAngle = odometryUpdates.dAngle + epsilon1 + epsilon3;
    
    float4 dPosition = noisyTrans * float4(cos(oldPose.angle + noisyRot1), sin(oldPose.angle + noisyRot1), 0.0, 0.0);
    float dAngle = noisyRot1 + noisyRot2;
    
    // Write pose
    
    Pose newPose = {.position = oldPose.position + dPosition, .angle = oldPose.angle + dAngle };
    newParticles[threadPosition] = newPose;
}

// MARK: - Updating weights

struct WeightUpdateUniforms {
    
    ushort numberOfParticles;
    ushort laserDistancesCount;
    ushort testIncrement;
    
    float mapTexelsPerMeter;        // texels per meter
    float mapSize;                  // meters
    
    float laserAngleStart;          // radians
    float laserAngleIncrement;      // radians
    
    float minimumLaserDistance;     // meters
    float maximumLaserDistance;     // meters
    
    float occupancyThreshold;
    
    float scanThreshold;            // meters
};

kernel void updateWeights(device Pose *particles [[buffer(0)]],
                          device float *weights [[buffer(1)]],
                          device float *laserDistances [[buffer(2)]],
                          texture2d<float, access::sample> map [[texture(0)]],
                          constant WeightUpdateUniforms &uniforms [[buffer(3)]],
                          uint threadPosition [[thread_position_in_grid]]) {
    
    if (threadPosition >= uniforms.numberOfParticles) {
        return;
    }
    
    Pose pose = particles[threadPosition];
    
    // Position in normalized texture coordinates in [0, 1]
    float2 position = (float2(pose.position.x, -pose.position.y) / uniforms.mapSize) + 0.5;
    
    // TODO: Put all of these in uniforms
    // In normalized texture coordinates
    float minimumLaserDistance = uniforms.minimumLaserDistance / uniforms.mapSize;
    
    float scanThreshold = uniforms.scanThreshold / uniforms.mapSize;
    
    // Normalized texel size
    float laserStepSize = 1.0 / float(map.get_width());
    
    // Maximum number of steps for each laser test
    //uint maximumSteps = ceil(uniforms.scanThreshold / uniforms.mapSize / laserStepSize);
    
    float totalError = 0.0;
    
    // Currently we walk until we hit a wall (if we don't hit scanThreshold first)
    // And then if we do, we add the squared difference between the amount we walked and the real distance
    
    float angle = pose.angle + uniforms.laserAngleStart;
    
    for (uint i = 0; i < uniforms.laserDistancesCount; i += uniforms.testIncrement) {
        
        // Actual desitance read by laser (meters)
        float actualDistance = laserDistances[i];
        
        if (actualDistance < uniforms.minimumLaserDistance || actualDistance > uniforms.scanThreshold) {
            angle += uniforms.laserAngleIncrement;
            continue;
        }
        
        float2 angleVector = float2(cos(angle), -sin(angle));
        
        // Local position for test
        float2 p = position + minimumLaserDistance * angleVector;
        
        // Local accumulated distance (texels)
        float d = minimumLaserDistance;
        
        bool onMap = true;
        
        while (d < scanThreshold) {
            
            if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
                onMap = false;
                break;
            }
            
            float sample = map.sample(mapSampler, p).r;
            
            if (sample > uniforms.occupancyThreshold) {
                break;
            }
            
            p += laserStepSize * angleVector;
            d += laserStepSize;
        }
        
        // Distance of first obstruction in meters
        float estimatedDistance = d * uniforms.mapSize;
        
        if (onMap || actualDistance < estimatedDistance) {
            
            float error = estimatedDistance - actualDistance;
            
            totalError -= error * error;
        }
        
        angle += uniforms.laserAngleIncrement;
    }
    
    weights[threadPosition] = totalError;
}

// MARK: - Sampling

struct SamplingUniforms {
    
    uint numOfParticles;
    
    uint randSeed;
};

kernel void sampling(device Pose *oldParticles [[buffer(0)]],
                     device Pose *newParticles [[buffer(1)]],
                     device uint *indexPool [[buffer(2)]],
                     constant SamplingUniforms &uniforms [[buffer(3)]],
                     uint threadPosition [[thread_position_in_grid]]) {
    
    if (threadPosition >= uniforms.numOfParticles) {
        return;
    }
    
    float rand = generateUniformRand(uniforms.randSeed, threadPosition);
    uint randInt = round(rand * uniforms.numOfParticles);
    newParticles[threadPosition] = oldParticles[indexPool[randInt]];
}

// MARK: - Reset

kernel void resetParticles(device Pose *particles [[buffer(0)]],
                           device float *weights [[buffer(1)]],
                           constant uint &sizeOfBuffer [[buffer(2)]],
                           uint threadPosition [[thread_position_in_grid]]) {
    
    if (threadPosition >= sizeOfBuffer) {
        return;
    }
    
    Pose zeroPose = { .position = float4(0.0, 0.0, 0.0, 1.0), .angle = 0.0 };
    particles[threadPosition] = zeroPose;
    weights[threadPosition] = 1.0 / float(sizeOfBuffer);
}

// MARK: - Rendering

struct particleRenderUniforms {
    
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
    float4x4 mapScaleMatrix;
    float4 color;
};

vertex ColorVertex particleVertex(device Pose *particles [[buffer(0)]],
                                  constant particleRenderUniforms &uniforms [[buffer(1)]],
                                  device Vertex *arrowVertices [[buffer(2)]],
                                  uint vid [[vertex_id]],
                                  uint pid [[instance_id]]) {
    
    ColorVertex colorVertex;
    
    Pose pose = particles[pid];
    float4x4 rotation = float4x4(float4(cos(pose.angle), sin(pose.angle), 0.0, 0.0),
                                 float4(-sin(pose.angle), cos(pose.angle), 0.0, 0.0),
                                 float4(0.0, 0.0, 1.0, 0.0),
                                 float4(0.0, 0.0, 0.0, 1.0));
    
    float4 projectedPositon = rotation * uniforms.modelMatrix * arrowVertices[vid].position + uniforms.mapScaleMatrix * pose.position;
    
    // FIXME: This is necessary because we added two 4D vectors together
    // If we store all poses as matrices, this badness will go away
    projectedPositon.w -= 1.0;
    
    colorVertex.position = uniforms.viewProjectionMatrix * projectedPositon;
    colorVertex.color = uniforms.color;
    
    return colorVertex;
}
