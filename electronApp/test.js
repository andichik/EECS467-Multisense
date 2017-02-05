var ref = require("ref");
var ffi = require("ffi");
var ArrayType = require('ref-array');
var StructType = require('ref-struct');

// typedefs
//var urg_t = ref.types.void // we don't know what the layout of "urg_t" looks like
var longArray = ArrayType(ref.types.long);
var longPtr = ref.refType(ref.types.long);

var urg_connection_t = ref.types.int;
var urg_range_data_byte_t = ref.types.int;
//var urg_error_handler = ref.types.void;
var charArray80 = ArrayType('char', 80);

var urg_t = StructType({
    is_active: 'int',
    last_errno: 'int',
    connection: urg_connection_t,
    first_data_index: 'int',
    last_data_index: 'int',
    front_data_index: 'int',
    area_resolution: 'int',
    scan_usec: 'long',
    min_distance: 'int',
    max_distance: 'int',
    scanning_first_step: 'int',
    scanning_last_step: 'int',
    scanning_skip_step: 'int',
    scanning_skip_scan: 'int',
    range_data_byte: urg_range_data_byte_t,
    timeout: 'int',
    specified_scan_times: 'int',
    scanning_remain_times: 'int',
    is_laser_on: 'int',
    received_first_index: 'int',
    received_last_index: 'int',
    received_skip_step: 'int',
    received_range_data_byte: urg_range_data_byte_t,
    is_sending: 'int',
    error_handler: 'pointer',
    return_buffer: charArray80
})
var urgPtr = ref.refType(urg_t);

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
var min_distance = ref.alloc('long')
var max_distance = ref.alloc('long')
var device = ref.allocCString('/dev/ttyS1');
var res = UrgLibrary.urg_open(urg, 0, device, 115200);
if (res<0){
    console.error(`Open port fails: ${res}`)
} else {
    console.log('Successfully connect to the serial port')
}

var data = new longArray(UrgLibrary.urg_max_data_size(urg))
//console.log(data)
UrgLibrary.urg_start_measurement(urg, 0, 1, 0)

console.log(ref.deref(urg).is_active)

var n = UrgLibrary.urg_get_distance(urg, data, time_stamp)
//console.log(data)
if (n<0) {
    console.error('Error when getting distance')
    UrgLibrary.urg_close(urg)
}
console.log(`N: ${n}`)
UrgLibrary.urg_distance_min_max(urg, min_distance, max_distance)
for (var i = 0; i<n; ++i) {
    let distance = data[i]
    if ((distance < min_distance) || (distance > max_distance)) {
        continue;
    }
    let radian = UrgLibrary.urg_index2rad(urg, i)
    console.log(distance, radian)
}
UrgLibrary.urg_close(urg);
