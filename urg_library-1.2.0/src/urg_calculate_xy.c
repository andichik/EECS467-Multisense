/*!
  \example calculate_xy.c Calculates X-Y coordinates

  Having the X axis aligned to the front step of the sensor, calculates the coordinates for measurement data
  \author Satofumi KAMIMURA

  $Id: calculate_xy.c,v e5d1719877a2 2015/05/07 04:12:14 jun $
*/
#include "urg_calculate_xy.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>


int urg_calculate_xy(long* x_arr, long* y_arr)
{
    urg_t urg;
    long *data;
    long max_distance;
    long min_distance;
    long time_stamp;
    int i;
    int n;

    const char *device = "/dev/ttyS1";

    if (urg_open(&urg, URG_SERIAL, device, 115200) < 0) {
        printf("urg_open: %s, %ld: %s\n",
            URG_SERIAL, 115200, urg_error(&urg));
        return -1;
    }

    data = (long *)malloc(urg_max_data_size(&urg) * sizeof(data[0]));
    if (!data) {
        perror("urg_max_index()");
        return -1;
    }

    // Gets measurement data
    urg_start_measurement(&urg, URG_DISTANCE, 1, 0);
    n = urg_get_distance(&urg, data, &time_stamp);
    if (n < 0) {
        printf("urg_get_distance: %s\n", urg_error(&urg));
        urg_close(&urg);
        return -1;
    }

    // Outputs X-Y coordinates
    urg_distance_min_max(&urg, &min_distance, &max_distance);
    for (i = 0; i < n; ++i) {
        long distance = data[i];
        double radian;
        long x;
        long y;

        if ((distance < min_distance) || (distance > max_distance)) {
            continue;
        }

        radian = urg_index2rad(&urg, i);
        x_arr[i] = (distance * cos(radian));
        y_arr[i] = (long)(distance * sin(radian));

        //printf("%ld, %ld\n", x, y);
    }
    //printf("\n");

    // Disconnects
    free(data);
    urg_close(&urg);

#if defined(URG_MSC)
    getchar();
#endif
    return n;
}

void freeData(long* arr)
{
    free(arr);
}
