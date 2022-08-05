//
//  ContentView.swift
//  SampleDefault
//
//  Created by Rinks (lincoms69) on 2022/06/22.
//

import SwiftUI
import RealityKit
import ARKit

struct ContentView : View {
    var body: some View {
        return ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    // Display AR space
    func makeUIView(context: Context) -> ARView {
        
        // RealityKit's Main view
        // let arView = ARView(frame: .zero)
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: true)
        arView.addTapGesture()
        
        // デバッグ用設定
        // 処理の統計情報と、検出した3D空間の特徴点を表示する。
        arView.debugOptions = [.showStatistics, .showFeaturePoints]
        
        // オクルージョンを有効化
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        // メッシュ表示の有効化
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        return arView
        
    }
    
    // Update AR space
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

extension ARView {

    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        self.addGestureRecognizer(tapGesture)
    }

    @objc func handleTap(recognizer: UITapGestureRecognizer) {

        snapshot(saveToHDR: false, completion: { (image) in
            // Compress the image
            let compressedImage = UIImage(data: (image?.jpegData(compressionQuality: 1.0))!)

            // Save in the photo album
            UIImageWriteToSavedPhotosAlbum(compressedImage!, nil, nil, nil)
        })

        let screenBounds = UIScreen.main.bounds
        let screen_width = screenBounds.width
        let screen_height = screenBounds.height
        print("SCN:  \(screen_width),\(screen_height)")
        // タップしたロケーションを取得
        let tapLocation = recognizer.location(in: self)
        print("TAP:  \(tapLocation)")
        
        let frame : ARFrame = session.currentFrame!
        let slide = 50.0
        var points = [simd_float3]()
        for i in 0..<Int(screen_width/slide) {
            for j in 0..<Int(screen_height/slide) {
                //print("\(i), \(j)")
                let pt = CGPoint(x:(Double(i+1)*slide), y:(Double(j+1)*slide))
                var valid = false

                if (i == 3 && (j == 2 || j == 4))
                    || (i == 5 && (j == 2 || j == 4)) {
                    print("\(i), \(j)")
                    valid = true
                    points.append(raycasts(from: pt, fm: frame, vd: valid))
                }

                //raycasts(from: pt, fm: frame, vd: valid)
            }
        }
        
        let area_1 = calHeron(at: [simd_float3](points[0...2]))
        let area_2 = calHeron(at: [simd_float3](points[1...3]))
        let area_all = (area_1 + area_2) * 100 * 100
        print("AREA :  \(area_all)")
        var median = simd_float3(0.0, 0.0, 0.0)
        for pt in points {
            median.x += pt.x
            median.y += pt.y
            median.z += pt.z
        }
        median.x = median.x / Float(points.count)
        median.y = median.y / Float(points.count)
        median.z = median.z / Float(points.count)
        
        placeCanvas(at: median, val: area_all, is: true)
    }
    
    private func raycasts(from point: CGPoint, fm frame: ARFrame, vd valid: Bool) -> simd_float3 {
        // タップした位置に対応する3D空間上の平面とのレイキャスト結果を取得
        //let raycastResults = raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any)
        let raycastResults = raycast(from: point, allowing: .estimatedPlane, alignment: .any)

        //guard let firstResult = raycastResults.first else { return }
        guard let firstResult = raycastResults.first else { return simd_float3(0,0,0)}
        
        // taplocationをワールド座標系に変換
        let tapPosition = simd_make_float3(firstResult.worldTransform.columns.3)
        print("TOUCH:  \(tapPosition)")
        
        //let frame : ARFrame = session.currentFrame!
        //let devicePosition = frame.camera.transform.columns.3
        let devicePosition = simd_make_float3(frame.camera.transform.columns.3)
        print("CAMERA: \(devicePosition)")
        
        let distance = distance(devicePosition, tapPosition)
        print("DIST: \(distance)")
        
        placeCanvas(at: tapPosition, val: distance, is: false)
        
        return tapPosition
    }
    
    /// 3点(三角形)の内部面積を計算する
    private func calHeron(at points: [simd_float3]) -> Float {
        let dist_12 = distance(points[0],points[1])
        let dist_23 = distance(points[1],points[2])
        let dist_31 = distance(points[2],points[0])
        let s_1 = (dist_12 + dist_23 + dist_31)/2.0
        return sqrt(s_1 * (s_1 - dist_12) * (s_1 * dist_23) * (s_1 * dist_31))
    }

    /// キャンバスを配置す
    private func placeCanvas(at position: SIMD3<Float>, val value: Float, is isArea: Bool) {
        // アンカーを作成
        let anchor = AnchorEntity(world: position)

        // テキストを作成
        let textMesh = MeshResource.generateText(
                    "\(String(format: "%.2f", value))\(isArea ? "cm2" : "m")",
                    extrusionDepth: 0.1,
                    font: .systemFont(ofSize: 1.0), // 小さいとフォントがつぶれてしまうのでこれぐらいに設定
                    containerFrame: CGRect.zero,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail)

        if !isArea {
            // 球体を作成
            let sphereMesh = MeshResource.generateSphere(radius: 0.01)
            // 環境マッピングするマテリアルを設定
            let sphereMaterial = SimpleMaterial(color: UIColor.white, roughness: 0.0, isMetallic: true)
            let sphereModel = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
            sphereModel.position = SIMD3<Float>(0.0, 0.0, 0.0)
            anchor.addChild(sphereModel)
        }
        
        // 環境マッピングするマテリアルを設定
        let textMaterial = SimpleMaterial(color: (isArea ? UIColor.green : UIColor.yellow), roughness: 0.0, isMetallic: true)
        let textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textModel.scale = SIMD3<Float>(0.01, 0.01, 0.01) // 10分の1に縮小
        textModel.position = SIMD3<Float>(0.0, 0.02, 0.0) // 奥0.2m
        //textModel.position = SIMD3<Float>(0.0, 0.0, -0.02) // 奥0.2m
        anchor.addChild(textModel)
        
        scene.anchors.append(anchor)

    }

    /// アートマテリアルを取得する
    private func getArtMaterial(name resourceName: String) -> PhysicallyBasedMaterial? {

        guard let texture = try? TextureResource.load(named: resourceName)
        else { return nil }

        var imageMaterial = PhysicallyBasedMaterial()
        let baseColor = MaterialParameters.Texture(texture)
        imageMaterial.baseColor = PhysicallyBasedMaterial.BaseColor(tint: .white, texture: baseColor)
        return imageMaterial
    }
}
