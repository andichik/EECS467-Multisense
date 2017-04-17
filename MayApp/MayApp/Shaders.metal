//
//  Shaders.metal
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

// MARK: - Laser distance functions

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

//MARK: - Point cloud functions

struct PointCloudVertex {
    ushort depth;
};

struct PointCloudIntermediateVertex {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};


struct PointCloudVertexUniforms {
    float width;
    float height;
    float fx;
    float fy;
    float cx;
    float cy;
    float4x4 projectionMatrix;
};

vertex PointCloudIntermediateVertex pointCloudVertex(device PointCloudVertex *verticies [[buffer(0)]],
                                                     constant PointCloudVertexUniforms &uniforms [[buffer(1)]],
                                                     texture2d<ushort> cameraTexture [[texture(0)]],
                                                     uint vid [[vertex_id]]) {
    
    float depth = verticies[vid].depth * 0.001; //convert mm to m
    float xid = vid % (int)uniforms.width;
    float yid = vid / (int)uniforms.width;
    
    PointCloudIntermediateVertex v;
    float x = (xid - uniforms.cx) * depth*uniforms.fx;
    float y = (-yid + uniforms.cy) * depth*uniforms.fy;
    float z = depth;
    
    v.position = uniforms.projectionMatrix * float4(x, y, z, 1.0);
    v.pointSize = 3.0;
    v.color = float4(cameraTexture.read(ushort2(xid, yid)))/255.0;
    
    return v;
}

fragment float4 pointCloudFragment(PointCloudIntermediateVertex v [[stage_in]]) {
    
    return v.color;
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
    float maximumDistance;   // meters
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
        return float4(-uniforms.updateAmount * exp(-v.distance / uniforms.maximumDistance * 6.0), 0.0, 0.0, 0.0);
        
    } else {
        
        // Occupied_
        return float4(uniforms.updateAmount * exp(-v.distance / uniforms.maximumDistance * 6.0), 0.0, 0.0, 0.0);
    }
}


// MARK: - Map rendering

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

//MARK: Camera functions
struct CameraVertex {
    
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex CameraVertex cameraVertex(device CameraVertex *verticies [[buffer(0)]],
                                 constant Uniforms &uniforms [[buffer(1)]],
                                 uint vid [[vertex_id]]) {
    
    CameraVertex out;
    
    out.position = uniforms.projectionMatrix * verticies[vid].position;
    out.textureCoordinate = verticies[vid].textureCoordinate;
    
    return out;
}

fragment float4 cameraFragment(CameraVertex v [[stage_in]],
                               texture2d<ushort> cameraTexture [[texture(0)]]) {
    
    return float4(cameraTexture.sample(mapSampler, v.textureCoordinate)) / 255.0;
}


fragment float4 cameraFragmentFloat(CameraVertex v [[stage_in]],
                               texture2d<float> cameraTexture [[texture(0)]]) {
    
    return float4(cameraTexture.sample(mapSampler, v.textureCoordinate));
}

// MARK: - Shared functions

fragment float4 colorFragment(ColorVertex colorVertex [[stage_in]]) {
    
    return colorVertex.color;
}



