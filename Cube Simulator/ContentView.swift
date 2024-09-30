//
//  ContentView.swift
//  Cube Simulator
//
//  Created by hagata
//

import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var scene: SCNScene?
    @State private var cameraNode: SCNNode?
    @State private var cuboidNode: SCNNode?
    @State private var previousTranslation: CGSize = .zero
    @State private var cuboidType: CuboidType = .cube
    
    enum CuboidType: String, CaseIterable {
        case cube = "Cube"
        case cuboid = "Cuboid"
    }
    
    var body: some View {
        ZStack {
            SceneView(
                scene: scene,
                pointOfView: cameraNode,
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .gesture(DragGesture()
                .onChanged { value in
                    rotateCuboid(translation: value.translation)
                }
                .onEnded { value in
                    applyInertia(velocity: value.velocity)
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                Picker("Cuboid Type", selection: $cuboidType) {
                    ForEach(CuboidType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: cuboidType) {
                    updateCuboidGeometry()
                }
                
                Spacer()
            }
        }
        .onAppear {
            setupScene()
        }
    }
    
    func setupScene() {
        scene = SCNScene()
        
        cameraNode = SCNNode()
        cameraNode?.camera = SCNCamera()
        cameraNode?.position = SCNVector3(x: 0, y: 0, z: 15)
        scene?.rootNode.addChildNode(cameraNode!)
        
        updateCuboidGeometry()
    }
    
    func updateCuboidGeometry() {
        cuboidNode?.removeFromParentNode()
        
        let geometry: SCNGeometry
        switch cuboidType {
        case .cube:
            geometry = SCNBox(width: 2, height: 2, length: 2, chamferRadius: 0.1)
        case .cuboid:
            geometry = SCNBox(width: 3, height: 2, length: 1, chamferRadius: 0.1)
        }
        
        cuboidNode = SCNNode(geometry: geometry)
        scene?.rootNode.addChildNode(cuboidNode!)
        
        cuboidNode?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        cuboidNode?.physicsBody?.mass = 1.0
        cuboidNode?.physicsBody?.friction = 0.5
        cuboidNode?.physicsBody?.restitution = 0.5
        cuboidNode?.physicsBody?.isAffectedByGravity = false
        
        let (width, height, length) = getDimensions()
        let ix = (1.0 / 12.0) * Float(height * height + length * length)
        let iy = (1.0 / 12.0) * Float(width * width + length * length)
        let iz = (1.0 / 12.0) * Float(width * width + height * height)
        cuboidNode?.physicsBody?.momentOfInertia = SCNVector3(ix, iy, iz)
    }
    
    func getDimensions() -> (width: Float, height: Float, length: Float) {
        switch cuboidType {
        case .cube:
            return (2, 2, 2)
        case .cuboid:
            return (3, 2, 1)
        }
    }
    
    func rotateCuboid(translation: CGSize) {
        guard let cuboidNode = cuboidNode, let cameraNode = cameraNode else { return }
        
        let sensitivity: Float = 0.01
        let deltaX = Float(translation.width - previousTranslation.width) * sensitivity
        let deltaY = Float(translation.height - previousTranslation.height) * sensitivity
        
        // Compute direction vector from camera to cuboid
        let cameraPosition = cameraNode.worldPosition
        let cuboidPosition = cuboidNode.worldPosition
        let directionVector = SCNVector3(
            x: cuboidPosition.x - cameraPosition.x,
            y: cuboidPosition.y - cameraPosition.y,
            z: cuboidPosition.z - cameraPosition.z
        )
        
        // Obtain the camera's upward vector
        let cameraUp = cameraNode.worldUp
        
        // Calculate axis of rotation
        let rightAxis = cameraUp.cross(directionVector).normalized()
        let upAxis = directionVector.cross(rightAxis).normalized()
        
        // Apply rotation
        let rotationX = SCNQuaternion(axis: rightAxis, angle: deltaY)
        let rotationY = SCNQuaternion(axis: upAxis, angle: -deltaX)
        let rotation = rotationX * rotationY
        
        cuboidNode.rotation = rotation * cuboidNode.rotation
        
        previousTranslation = translation
    }
    
    func applyInertia(velocity: CGSize) {
        guard let cuboidNode = cuboidNode else { return }
        
        let sensitivity: Float = 0.0005
        let angularVelocity = SCNVector4(
            x: Float(velocity.height) * sensitivity,
            y: -Float(velocity.width) * sensitivity,
            z: 0,
            w: 1.0
        )
        
        cuboidNode.physicsBody?.angularVelocity = angularVelocity
        
        previousTranslation = .zero
    }
}

extension SCNVector3 {
    func cross(_ vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            y * vector.z - z * vector.y,
            z * vector.x - x * vector.z,
            x * vector.y - y * vector.x
        )
    }
    
    func normalized() -> SCNVector3 {
        let length = sqrt(x*x + y*y + z*z)
        return SCNVector3(x / length, y / length, z / length)
    }
}

extension SCNQuaternion {
    init(axis: SCNVector3, angle: Float) {
        let halfAngle = angle * 0.5
        let sinHalfAngle = sin(halfAngle)
        self.init(
            x: axis.x * sinHalfAngle,
            y: axis.y * sinHalfAngle,
            z: axis.z * sinHalfAngle,
            w: cos(halfAngle)
        )
    }
    
    static func * (left: SCNQuaternion, right: SCNQuaternion) -> SCNQuaternion {
        return SCNQuaternion(
            x: left.w * right.x + left.x * right.w + left.y * right.z - left.z * right.y,
            y: left.w * right.y - left.x * right.z + left.y * right.w + left.z * right.x,
            z: left.w * right.z + left.x * right.y - left.y * right.x + left.z * right.w,
            w: left.w * right.w - left.x * right.x - left.y * right.y - left.z * right.z
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
