#ifndef URG_CALCULATE_XY_H
#define URG_CALCULATE_XY_H

#ifdef __cplusplus
extern "C" {
#endif

#include "urg_sensor.h"
#include "urg_utils.h"

    extern int urg_calculate_xy(long* x_arr, long* y_arr, const char* device);
    extern void freeData(long* arr);

#ifdef __cplusplus
}
#endif

#endif
