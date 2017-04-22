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


final class MotorController: NSObject {
    
    var turningPID: PIDController
    var movingPID: PIDController
    var tuningPID: PIDController
    var actionQueue = [RobotAction]()
    var robotPath = [Pose]()
    public var currentPose = Pose()
    var liveAction = RobotAction()
    var counter = 0
    
    override init(){
        turningPID = PIDController()
        movingPID = PIDController()
        tuningPID = PIDController()
    }
    
    func setTurningController(_ kp: Float, _ ki: Float, _ kd: Float){
        turningPID.resetPIDVal(K_p: 12, K_i: ki, K_d: kd)
    }
    
    func setMovingController(_ kp: Float, _ ki: Float, _ kd: Float){
        movingPID.resetPIDVal(K_p: 12, K_i: ki, K_d: kd)
        tuningPID.resetPIDVal(K_p: 7, K_i: 0, K_d: 0)
    }
    
    func wrapToPi(_ angle: Float) -> Float{
        var result: Float = 0.0
            if(angle >= 0){
                if angle>Float.pi {
                    result = angle-2 * Float.pi
                }
                else{
                    result = angle
                }
            }
            else{
                if angle < -Float.pi {
                    result = angle+2 * Float.pi;
                }
                else{
                    result = angle
                }
            }
            return result;
    }
    
    func wrapSpeed(_ speed: Float, upperBound: Float, lowerBound:Float) -> Float{
        var result: Float = 0.0
        if abs(speed) < lowerBound{
            if speed > 0{
                result = lowerBound
            }
            else{
                result = -lowerBound
            }
        }
        
        if speed > upperBound{
            result = upperBound
        }
        if speed < -upperBound{
            result = -upperBound
        }
        return result
    }
    
    func findError(_ target: RobotAction, _ current: Pose) -> (Float, Float){
        if target.isRotation {
            var error = liveAction.targetAngle - wrapToPi(currentPose.angle)
            error = wrapToPi(error)
            return (0.0,error)
        }
        else{
            let error = sqrt(pow((target.targetX - current.position.x),2)  + pow((target.targetY - current.position.y),2))
            var angle_error = liveAction.targetAngle - currentPose.angle
            angle_error = wrapToPi(angle_error)
            return (error,angle_error)
        }
    }
    
    
    
    func updateMotorCommand() -> (Float, Float) {
        let error = findError(liveAction, currentPose)
        print("LIVE ACTION: isRotation: \(liveAction.isRotation) targetX: \(liveAction.targetX), targetY: \(liveAction.targetY), targetAngle: \(liveAction.targetAngle)")
        print("ERROR: \(error)")
        if liveAction.isRotation {
            var turning:Float = 0.0
            if abs(error.1) > 0.1{
                turning = turningPID.nextState(error: error.1, deltaT: 1)
            
                turning = wrapSpeed(turning, upperBound: 50, lowerBound: 40)
            }
            if turning == 0.0{
                startNewAction()
            }
            
//            if turning > 0 {
//                return (leftVel: 0, rightVel: turning)
//            }
//            else{
//                return (leftVel: -turning, rightVel: 0)
//            }
            return (leftVel: -turning, rightVel: turning)
        }
            
        else{
            var left_straight:Float = 0.0
            var right_straight: Float = 0.0
            var straight: Float = 0.0
            
            if abs(error.0) > 0.25{
                straight = movingPID.nextState(error: error.0, deltaT: 1)
                let heading = tuningPID.nextState(error: error.1, deltaT: 1)
                
                left_straight = straight
                right_straight = straight
                left_straight = wrapSpeed(left_straight, upperBound: 40, lowerBound: 30)
                right_straight = wrapSpeed(right_straight, upperBound: 40, lowerBound: 30)
            }
            if straight == 0 {
                startNewAction()
            }
            return (leftVel: left_straight, rightVel: right_straight)
        }
    }
    
    func startNewPose() -> Bool{
        //calculate the difference between current pose and the target pose
        //create robotAction as rot1, trans, rot2
        print("-----------START NEW POSE------------")
        if robotPath.isEmpty {
            return false
        }
        let targetPose = robotPath.first!
        print("TARGET POSE x: \(targetPose.position.x), y: \(targetPose.position.y), angle: \(targetPose.angle)")
        robotPath.removeFirst()
        var angle:Float = 0.0
        angle = atan((targetPose.position.y - currentPose.position.y)/(targetPose.position.x - currentPose.position.x))
        if targetPose.position.x < currentPose.position.x {
            angle = wrapToPi(angle-Float.pi)
        }
        //let angle: Float = atan((targetPose.position.x - currentPose.position.x)/(targetPose.position.y - currentPose.position.y))
        
        let rot1 = RobotAction(currentPose.position.x, currentPose.position.y, angle, true)
        let trans = RobotAction(targetPose.position.x, targetPose.position.y, angle, false)
        //let rot2 = RobotAction(targetPose.position.x, targetPose.position.y, targetPose.angle, true)
        
        print("first rot: \(angle)")
        actionQueue.append(rot1)
        actionQueue.append(trans)
        //actionQueue.append(rot2)
        
        return true

    }
    


    func startNewAction() {
        if actionQueue.isEmpty {
            if !startNewPose(){
                print("finish path")
                return
            }
        }
        print("-----------start new action------------")
        liveAction = actionQueue.first!
        actionQueue.removeFirst()
        
        turningPID.reset()
        movingPID.reset()
        
    }
    
    //receive the robot current pose
    func handlePose(_ pose: Pose){
        currentPose = pose
        
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
    
    func addSquare(){
        if(counter == 0){
            var targetPose1 = Pose()
            targetPose1.position.x = 0.7
            targetPose1.position.y = 0
            targetPose1.angle = -Float.pi/2
            var targetPose2 = Pose()
            targetPose2.position.x = 0.7
            targetPose2.position.y = -0.7
            targetPose2.angle = -Float.pi
            var targetPose3 = Pose()
            targetPose3.position.x = 0
            targetPose3.position.y = -0.7
            targetPose3.angle = Float.pi/2
            var targetPose4 = Pose()
            targetPose4.position.x = 0
            targetPose4.position.y = 0
            targetPose4.angle = 0
            robotPath.append(targetPose1)
            robotPath.append(targetPose2)
            robotPath.append(targetPose3)
            robotPath.append(targetPose4)
        }
        counter += 1
    }
    
    func handleMotorCommand(robotCommand: RobotCommand){
        if robotCommand.destination.x != 0 && robotCommand.destination.y != 0{
            currentPose.position = [robotCommand.currentPosition.x, robotCommand.currentPosition.y, 0.0, 0.0]
            currentPose.angle = robotCommand.currentAngle
            var targetPose = Pose()
            targetPose.position = [robotCommand.destination.x, robotCommand.destination.y, 0.0, 0.0]
            print("ADD ROBOTPATH: destination x: \(robotCommand.destination.x) y: \(robotCommand.destination.y)")
            robotPath.append(targetPose)
        }
    }
    
}
