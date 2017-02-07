const ref = require("ref");
const ffi = require("ffi");
const ArrayType = require('ref-array');

var getXY = function(portName, shrink, xOffset, yOffset){
    var longArray = ArrayType(ref.types.long);
    var longPtr = ref.refType(ref.types.long);

    var UrgLibrary = ffi.Library('./liburg_c', {
      "urg_calculate_xy": [ 'int', [ longArray, longArray, 'CString' ] ],
    });

    var x_arr = new longArray(1081)
    var y_arr = new longArray(1081)

    var device = ref.allocCString(portName);

    var dataSize = UrgLibrary.urg_calculate_xy(x_arr, y_arr, device)

    console.assert(dataSize, 1081)


    var xArr = Array.from(x_arr);
    var yArr = Array.from(y_arr);

    return xArr.map((v_x, idx)=>[v_x/shrink+xOffset, yArr[idx]/shrink+yOffset])

}

module.exports = {getXY}
