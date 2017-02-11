import math from 'mathjs';

function generateMatrix(x, y, theta){
    return [[Math.cos(theta), -Math.sin(theta), x], 
            [Math.sin(theta), Math.cos(theta), y],
            [0, 0, 1]
    ];
}

export {generateMatrix};
