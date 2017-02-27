// Every 20 ticks, update pose estimation
const POSE_UPDATE_SIZE = 20;

// Measurement for the car (in meters)
// Stolen from MayApp
const BASELINE = 0.4572;
const TICK_STEP = 0.0003483428571;

// HTML sizing stuff
const TRACE_HEIGHT = 400;
const TRACE_WIDTH = 400;
const TRACE_SCALE = 80;

//Map stuff
const GRIDS_IN_METER = 400;
const MAP_LENGTH = 20;
const GRID_LENGTH = 1 / GRIDS_IN_METER;
const GRIDS_ON_SIDE = GRIDS_IN_METER * MAP_LENGTH; //8000

//Grid SVG stuff
const RECT_PX = 20;
const RECT_ON_SIDE = TRACE_HEIGHT/RECT_PX; //20
const MERGE_DATA_SIZE = GRIDS_ON_SIDE/RECT_ON_SIDE;

export {
    POSE_UPDATE_SIZE,
    BASELINE,
    TICK_STEP,
    TRACE_HEIGHT,
    TRACE_WIDTH,
    TRACE_SCALE,
    GRIDS_ON_SIDE,
    GRID_LENGTH
};
