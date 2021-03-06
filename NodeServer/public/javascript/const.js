// Every 20 ticks, update pose estimation
const POSE_UPDATE_SIZE = 20;

// Measurement for the car (in meters)
// Stolen from MayApp
const BASELINE = 0.4572;
const TICK_STEP = 0.0003483428571;

// HTML sizing stuff
const TRACE_HEIGHT_PPX = 400;
const TRACE_WIDTH_PPX = 400;
const TRACE_SCALE = 20;

const MAP_LENGTH_METER = 20;

//GRIDPX stuff
const GRIDPX_PER_METER = 40;
const GRIDPX_LENGTH_METER = 1 / GRIDPX_PER_METER;
const MAP_LENGTH_GRIDPX = GRIDPX_PER_METER * MAP_LENGTH_METER; //8000

//DISPX stuff
const DISPX_LENGTH_PPX = 5;
const DISPX_PER_METER = (TRACE_HEIGHT_PPX/DISPX_LENGTH_PPX)/MAP_LENGTH_METER;
const DISPX_LENGTH_METER = 1/DISPX_PER_METER;
const MAP_LENGTH_DISPX = TRACE_HEIGHT_PPX/DISPX_LENGTH_PPX; //20

//Constants k for Action Model error calculations

const K1_TURN = 0.08;

const K1_STRAIGHT = 0.0001;
const K2 = 0.001;


//Constant for number of Particles
const NUM_PARTICLES = 100;

//Two objects in grid px of display px, similar structure but different constants

const GRIDPX = {
    PX_PER_METER: GRIDPX_PER_METER,
    PX_LENGTH_METER: GRIDPX_LENGTH_METER,
    MAP_LENGTH_PX: MAP_LENGTH_GRIDPX
}

const DISPX = {
    PX_PER_METER: DISPX_PER_METER,
    PX_LENGTH_METER: DISPX_LENGTH_METER,
    MAP_LENGTH_PX: MAP_LENGTH_DISPX,
    PX_LENGTH_PPX: DISPX_LENGTH_PPX
}

//Used in occupacy grid score calculation
const OCCUPY_REWARD = 5;
const UNOCCUPY_REWARD = 1;
const FULLY_OCCUPIED = 1200;
const FULLY_UNOCCUPIED = -400;
const OCCUPY_THRESHOLD = FULLY_UNOCCUPIED + 0.25*(FULLY_OCCUPIED - FULLY_UNOCCUPIED);

export {
    POSE_UPDATE_SIZE,
    BASELINE,
    TICK_STEP,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX,
    TRACE_SCALE,
    MAP_LENGTH_METER,
    GRIDPX,
    DISPX,
    OCCUPY_REWARD,
    UNOCCUPY_REWARD,
    FULLY_OCCUPIED,
    FULLY_UNOCCUPIED,
    OCCUPY_THRESHOLD,
    NUM_PARTICLES,
    K1_TURN,
    K1_STRAIGHT,
    K2
};
