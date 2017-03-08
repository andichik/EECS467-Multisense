//
//  File.metal
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/18.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void A_star(texture4d<float, access::read> dangerMap[[texture(0)]], uint index [[ thread_position_in_grid]]) {
    
}
