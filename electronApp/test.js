var ref = require("ref");
var ffi = require("ffi");
var ArrayType = require('ref-array');

// typedefs
var urg_t = ref.types.void // we don't know what the layout of "urg_t" looks like
var urgPtr = ref.refType(urg_t);
var longArray = ArrayType(ref.types.long);
var longPtr = ref.refType(ref.types.long);

var UrgLibrary = ffi.Library('./liburg_c', {
  "urg_open": [ 'int', [ urgPtr, 'int', 'CString', 'long' ] ],
  "urg_max_data_size": [ 'int' , [urgPtr] ],
  "urg_start_measurement": [ 'int', [ urgPtr, 'int', 'int', 'int' ] ],
  "urg_get_distance": [ 'int', [urgPtr, longArray, longPtr]],
  "urg_close": ['void', [urgPtr]],
  "urg_distance_min_max": ['void', [urgPtr, longPtr, longPtr]],
  "urg_index2rad": ['double', [urgPtr, 'int']]
});

var urg = ref.alloc(urgPtr);
var time_stamp = ref.alloc('long')
var max_distance = ref.alloc('long')
var max_distance = ref.alloc('long')
var device = ref.allocCString('/dev/ttyS1');
var res = UrgLibrary.urg_open(urg, 0, device, 115200);
if (res<0){
    console.error(`Open port fails: ${res}`)
} else {
    console.log('Successfully connect to the serial port')
}

// var data = new longArray(UrgLibrary.urg_max_data_size(urg))
//
// UrgLibrary.urg_start_measurement(urg, 0, 1, 0)
//
// var n = UrgLibrary.urg_get_distance(urg, data, time_stamp)
// if (n<0) {
//     console.error('Error')
//     UrgLibrary.urg_close(urg)
// }
// console.log(data)
// UrgLibrary.urg_distance_min_max(urg, min_distance, max_distance)
// for (var i = 0; i<n; ++i) {
//     let distance = data[i]
//     if ((distance < min_distance) || (distance > max_distance)) {
//         continue;
//     }
//     let radian = UrgLibrary.urg_index2rad(urg, i)
//     console.log(radian)
// }
// UrgLibrary.close(urg)
