var ref = require("ref");
var ffi = require("ffi");
var ArrayType = require('ref-array');

var longArray = ArrayType(ref.types.long);
var longPtr = ref.refType(ref.types.long);

var UrgLibrary = ffi.Library('./liburg_c', {
  "urg_calculate_xy": [ 'int', [ longArray, longArray ] ],
  "freeData": ['void', [ longPtr ]]
});

var x_arr = new longArray(1081)
var y_arr = new longArray(1081)

var dataSize = UrgLibrary.urg_calculate_xy(x_arr, y_arr)

console.assert(dataSize, 1081)

console.log(Array.from(x_arr))
