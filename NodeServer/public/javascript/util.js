import {TRACE_HEIGHT_PPX, TRACE_WIDTH_PPX, TRACE_SCALE} from './const.js'

/**
 * Deprecated
 * @param  {[type]} posArr [description]
 * @return {[type]}        [description]
 */
function pagePosToRealPos(posArr){
    console.assert(posArr.length===2);
    return [posArr[0]-TRACE_WIDTH/2, posArr[1]-TRACE_HEIGHT/2].map(x=>x/TRACE_SCALE);
}

export {pagePosToRealPos}
