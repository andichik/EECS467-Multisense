//
//  Shaders.metal
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Type definitions

// Vertex shader input
struct Vertex {
    
    float4 position;
};

// Vertex shader output / fragment shader input
struct ColorVertex {
    
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

struct Uniforms {
    
    float4x4 projectionMatrix;
};

struct Pose {
    
    float4 position;
    float angle;
};

// MARK: - Samplers

constexpr sampler mapSampler;

constexpr sampler laserDistanceSampler(address::clamp_to_zero, filter::linear);

// MARK: - Laser distance functions

struct LaserDistanceVertex {
    float distance;
};

struct LaserDistanceIntermediateVertex {
    float4 position [[position]];
    float distance;
    float normalizedDistance;
};

struct LaserDistanceVertexUniforms {
    
    float4x4 projectionMatrix;
    
    float angleStart;
    float angleIncrement;
};

struct LaserDistanceFragmentUniforms {
    
    float minimumDistance;  // meters
    float distanceAccuracy; // meters
};

vertex LaserDistanceIntermediateVertex laserDistanceVertex(device LaserDistanceVertex *verticies [[buffer(0)]],
                                                           constant LaserDistanceVertexUniforms &uniforms [[buffer(1)]],
                                                           uint vid [[vertex_id]]) {
    
    float angle = uniforms.angleStart + float(vid) * uniforms.angleIncrement;
    float distance = verticies[vid].distance;
    
    LaserDistanceIntermediateVertex v;
    v.position = uniforms.projectionMatrix * float4(distance * cos(angle), distance * sin(angle), 0.0, 1.0);
    v.distance = distance;
    v.normalizedDistance = (distance == 0.0) ? 0.0 : 1.0;
    
    return v;
}

fragment float4 laserDistanceFragment(LaserDistanceIntermediateVertex v [[stage_in]],
                                      constant LaserDistanceFragmentUniforms &uniforms [[buffer(0)]]) {
    
    return float4(0.5, 0.75, 1.0, 1.0);
}

// MARK: - Odometry functions

vertex ColorVertex odometryVertex(device Vertex *verticies [[buffer(0)]],
                                  constant Uniforms &uniforms [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    
    ColorVertex colorVertex;
    colorVertex.position = uniforms.projectionMatrix * verticies[vid].position;
    colorVertex.color = float4(0.0, 0.0, 0.0, 1.0);
    
    return colorVertex;
}

// MARK: - Map update functions

struct MapUpdateVertex {
    float distance;
};

struct MapUpdateIntermediateVertex {
    float4 position [[position]];
    float distance;
    float normalizedDistance;
};

struct MapUpdateVertexUniforms {
    
    // Moves vertices from origin to robot's pose
    // Scales from meters to texels
    float4x4 projectionMatrix;
    
    float angleStart;
    float angleIncrement;
    
    float obstacleThickness; // meters
};

struct MapUpdateFragmentUniforms {
    
    float minimumDistance;   // meters
    float obstacleThickness; // meters
    
    float updateAmount;
};

vertex MapUpdateIntermediateVertex mapUpdateVertex(device MapUpdateVertex *verticies [[buffer(0)]],
                                                   constant MapUpdateVertexUniforms &uniforms [[buffer(1)]],
                                                   uint vid [[vertex_id]]) {
    
    float angle = uniforms.angleStart + float(vid) * uniforms.angleIncrement;
    float distance = verticies[vid].distance;
    
    if (distance > 0.0) {
        distance += uniforms.obstacleThickness;
    }
    
    MapUpdateIntermediateVertex v;
    v.position = uniforms.projectionMatrix * float4(distance * cos(angle), distance * sin(angle), 0.0, 1.0);
    v.distance = distance;
    v.normalizedDistance = (distance == 0.0) ? 0.0 : 1.0;
    
    return v;
}

fragment float4 mapUpdateFragment(MapUpdateIntermediateVertex v [[stage_in]],
                                  constant MapUpdateFragmentUniforms &uniforms [[buffer(0)]]) {
    
    if (v.distance < uniforms.minimumDistance) {
        
        // Too close to robot
        return float4(0.0, 0.0, 0.0, 0.0);
    } else if (v.distance < v.distance / v.normalizedDistance - uniforms.obstacleThickness) {
        
        // Free
        return float4(-uniforms.updateAmount, 0.0, 0.0, 0.0);
    } else {
        
        // Occupied
        return float4(uniforms.updateAmount, 0.0, 0.0, 0.0);
    }
}


// MARK: - Particle filter functions

struct OdometryUpdates {
    
    float4 dPosition;
    float dAngle;
};

struct ParticleUpdateUniforms {
    
    uint numOfParticles;
    
    uint randSeedR;
    uint randSeedT;
    
    float errRangeR;
    float errRangeT;
    
    OdometryUpdates odometryUpdates;
};

struct SamplingUniforms {
    
    uint numOfParticles;
    
    uint randSeed;
};

float generateUniformRand(uint seed, uint unique);
float2 gaussianFromUniform(float u1, float u2);

float generateUniformRand(uint x, uint y) {
    
    int z = 467;
    
    int seed = x + y * 57 + z * 241;
    seed = (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

float2 gaussianFromUniform(float u1, float u2) {
    
    float z1 = sqrt(-2 * log(u1)) * cos(2 * M_PI_H * u2);
    float z2 = sqrt(-2 * log(u1)) * sin(2 * M_PI_H * u2);
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
    
    float uRandR = generateUniformRand(uniforms.randSeedR, threadPosition);
    float uRandT = generateUniformRand(uniforms.randSeedT, threadPosition);
    float2 gRand = gaussianFromUniform(uRandR, uRandT);
    float gRandR = gRand.x;
    float gRandT = gRand.y;
    
    Pose oldPose = oldParticles[threadPosition];
    OdometryUpdates odometryUpdates = uniforms.odometryUpdates;
    
    odometryUpdates.dPosition.xy = float2x2(float2(cos(oldPose.angle), sin(oldPose.angle)), float2(-sin(oldPose.angle), cos(oldPose.angle))) * odometryUpdates.dPosition.xy;
    
    float alpha;
    if (odometryUpdates.dPosition.x == 0.0) {
        alpha = M_PI_2_F - oldPose.angle;
    } else {
        alpha = atan2(odometryUpdates.dPosition.y, odometryUpdates.dPosition.x) - oldPose.angle;
    }
    
    float ds = length(odometryUpdates.dPosition.xy);
    float beta = odometryUpdates.dAngle - alpha;
    
    float epsilon1 = alpha * uniforms.errRangeR * gRandR;
    float epsilon2 = ds * uniforms.errRangeT * gRandT;
    float epsilon3 = beta * uniforms.errRangeR * gRandR;
    
    float dx = (ds + epsilon2) * cos(oldPose.angle + alpha + epsilon1);
    float dy = (ds + epsilon2) * sin(oldPose.angle + alpha + epsilon1);
    float dAngle = odometryUpdates.dAngle + epsilon1 + epsilon3;
    float4 dPosition = float4(dx, dy, 0.0, 0.0);
    
    Pose newPose = {.position = oldPose.position + dPosition, .angle = oldPose.angle + dAngle };
    newParticles[threadPosition] = newPose;
}

struct WeightUpdateUniforms {
    
    uint numOfParticles;
    uint numOfTests;
    
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
                          texture2d<float, access::sample> map [[texture(0)]],
                          texture1d<uint, access::sample> laserDistances [[texture(1)]],
                          constant WeightUpdateUniforms &uniforms [[buffer(2)]],
                          uint threadPosition [[thread_position_in_grid]]) {
    
    if (threadPosition >= uniforms.numOfParticles) {
        return;
    }
    
    Pose pose = particles[threadPosition];
    
    // Position in normalized texture coordinates in [0, 1]
    float2 position = (pose.position.xy / uniforms.mapSize) + 0.5;
    
    // In normalized texture coordinates
    float minimumLaserDistance = uniforms.minimumLaserDistance / uniforms.mapSize;
    
    // Normalized texel size
    float laserStepSize = 1.0 / float(map.get_width());
    
    // Maximum number of steps for each laser test
    uint maximumSteps = ceil(uniforms.scanThreshold / uniforms.mapSize / laserStepSize);
    
    float totalError = 0.0;
    
    float angle = pose.angle + uniforms.laserAngleStart;
    
    for (uint i = 0; i < uniforms.numOfTests; ++i) {
        
        float2 angleVector = float2(cos(angle), sin(angle));
        
        // Local position for test
        float2 p = position + minimumLaserDistance * angleVector;
        
        for (uint j = 0; j < maximumSteps; ++j) {
            
            float sample = map.sample(mapSampler, p).r;
            
            if (sample > uniforms.occupancyThreshold) {
                
                // Distance of first obstruction in meters
                float estimatedDistance = distance(position, p) * uniforms.mapSize;
                
                float actualDistance = 0.001 * float(laserDistances.sample(laserDistanceSampler, float(i) / float(uniforms.numOfTests - 1)).r);
                
                float error = estimatedDistance - actualDistance;
                
                totalError -= error * error;
                
                break;
            }
            
            p = p + laserStepSize * angleVector;
        }
        
        angle += uniforms.laserAngleIncrement;
    }
    
    weights[threadPosition] = totalError;
}

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

vertex ColorVertex particleVertex(device Pose *particles [[buffer(0)]],
                                  constant Uniforms &uniforms [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    
    ColorVertex colorVertex;
    colorVertex.position = uniforms.projectionMatrix * particles[vid].position;
    colorVertex.color = float4(1.0, 0.0, 0.0, 1.0);
    colorVertex.pointSize = 10.0;
    
    return colorVertex;
}

// Vertex shader input
struct MapVertex {
    
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex MapVertex mapVertex(device MapVertex *verticies [[buffer(0)]],
                           constant Uniforms &uniforms [[buffer(1)]],
                           uint vid [[vertex_id]]) {
    
    MapVertex out;
    
    out.position = uniforms.projectionMatrix * verticies[vid].position;
    out.textureCoordinate = verticies[vid].textureCoordinate;
    
    return out;
}

fragment float4 mapFragment(MapVertex v [[stage_in]],
                            texture2d<float> mapTexture [[texture(0)]]) {
    
    float sample = mapTexture.sample(mapSampler, v.textureCoordinate).r;
    
    float color = 0.5 - 0.5 * sample;
    
    return float4(color, color, color, 1.0);
}

// MARK: - Shared functions

fragment float4 colorFragment(ColorVertex colorVertex [[stage_in]]) {
    
    return colorVertex.color;
}

