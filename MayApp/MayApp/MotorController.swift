//
//  MotorController.swift
//  MayApp
//
//  Created by Yanqi Liu on 4/18/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import MayAppCommon

class RobotAction{
    var targetX: Float = 0
    var targetY: Float = 0
    var targetAngle: Float = 0
    var isRotation: Bool = false
    
    init(){
        
    }
    init(_ x: Float, _ y: Float, _ angle: Float, _ rot: Bool){
        targetX = x
        targetY = y
        targetAngle = angle
        isRotation = rot
    }
}


final class MotorController: NSObject{
    
    let turningPID: PIDController
    let movingPID: PIDController
    var actionQueue = [RobotAction]()
    var robotPath = [Pose]()
    var currentPose = Pose()
    var liveAction = RobotAction()
    
    
    init(_ turning: PIDController, _ moving: PIDController){
        turningPID = turning
        movingPID = moving
        
    }
    
    func findError(_ target: RobotAction, _ current: Pose) -> Float{
        if target.isRotation {
            var error = liveAction.targetAngle - currentPose.angle
            error = fmodf(error + Float.pi, 2 * Float.pi)
            return error
        }
        else{
            let error = sqrt(pow((target.targetX - current.position.x),2)  + pow((target.targetY - current.position.y),2))
            return error
        }
    }
    
    func updateMotorCommand(){
        let error = findError(liveAction, currentPose)

        if liveAction.isRotation {
            var turning:Float = 0.0
            if error > 0.1{
                turning = turningPID.nextState(error: error, deltaT: 1)
            }
            if turning == 0{
                startNewAction()
            }
            
        }
        else{
            var straight:Float = 0.0
            if error > 0.1{
                straight = movingPID.nextState(error: error, deltaT: 1)
            }
            
            if straight == 0 {
                startNewAction()
            }
            
        }
        //TODO: call send motor command through arduino controller
        
    }
    
    func startNewPose() -> Bool{
        //calculate the difference between current pose and the target pose
        //create robotAction as rot1, trans, rot2
        if robotPath.isEmpty {
            return false
        }
        let targetPose = robotPath.first!
        robotPath.removeFirst()
        
        let angle: Float = atan((targetPose.position.y - currentPose.position.y)/(targetPose.position.x - currentPose.position.x))
        
        let rot1 = RobotAction(currentPose.position.x, currentPose.position.y, angle, true)
        let trans = RobotAction(targetPose.position.x, targetPose.position.y, angle, false)
        let rot2 = RobotAction(targetPose.position.x, targetPose.position.y, targetPose.angle, true)
        
        actionQueue.append(rot1)
        actionQueue.append(trans)
        actionQueue.append(rot2)
        
        return true

    }
    

    func startNewAction() {
        if actionQueue.isEmpty {
            if robotPath.isEmpty{
                print("finish path")
                return
            }
        }
        liveAction = actionQueue.first!
        actionQueue.removeFirst()
        
        turningPID.reset()
        movingPID.reset()
        
    }
    
    //receive the robot current pose
    func handlePose(_ position: float2, _ angle: Float){
        currentPose.position = [position.x, position.y, 0.0, 0.0]
        currentPose.angle = angle
        
    }
    
    //receive the commanded path, current just receive one target pose at a time
    //should handle an array of target pose
    //generate corespondence action to add into ActionQueue
    func handlePath(_ position: float2, _ angle: Float){
        var targetPose = Pose()
        targetPose.position = [position.x, position.y, 0.0, 0.0]
        targetPose.angle = angle
        robotPath.append(targetPose)
    }
    
    
}
