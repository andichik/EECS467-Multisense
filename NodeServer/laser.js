const ref = require("ref");
const ffi = require("ffi");
const ArrayType = require('ref-array');


const MM_TO_M = 0.001;

var getXY = function(portName) {
    var longArray = ArrayType(ref.types.long);
    var longPtr = ref.refType(ref.types.long);

    var UrgLibrary = ffi.Library('./liburg_c', {
        "urg_calculate_xy": ['int', [longArray, longArray, 'CString']],
    });

    var x_arr = new longArray(1081)
    var y_arr = new longArray(1081)

    var device = ref.allocCString(portName);

    var dataSize = UrgLibrary.urg_calculate_xy(x_arr, y_arr, device)


    if (dataSize!=1081) {
        console.error('Bad laser data');
        return [];
    }


    var xArr = Array.from(x_arr);
    var yArr = Array.from(y_arr);

    return xArr.map((v_x, idx) => [v_x * MM_TO_M, yArr[idx] * MM_TO_M])
                .filter(tuple=>Math.abs(tuple[0])<30&&Math.abs(tuple[1]<30))

}

module.exports = {
    getXY
}
