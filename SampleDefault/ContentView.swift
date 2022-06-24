//
//  ContentView.swift
//  SampleDefault
//
//  Created by shinzator60 on 2022/06/22.
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

        // タップしたロケーションを取得
        let tapLocation = recognizer.location(in: self)

        // タップした位置に対応する3D空間上の平面とのレイキャスト結果を取得
        let raycastResults = raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any)

        guard let firstResult = raycastResults.first else { return }
        
        // taplocationをワールド座標系に変換
        let tapPosition = simd_make_float3(firstResult.worldTransform.columns.3)
        print("TOUCH:  \(tapPosition)")
        
        let frame : ARFrame = session.currentFrame!
        //let devicePosition = frame.camera.transform.columns.3
        let devicePosition = simd_make_float3(frame.camera.transform.columns.3)
        print("CAMERA: \(devicePosition)")
        
        let distance = distance(devicePosition, tapPosition)
        print("DIST: \(distance)")
        
        placeCanvas(at: tapPosition, dist: distance)
    }

    /// キャンバスを配置する
    private func placeCanvas(at position: SIMD3<Float>, dist distance: Float) {
        // アンカーを作成
        let anchor = AnchorEntity(world: position)

        // テキストを作成
        let textMesh = MeshResource.generateText(
                    "d:\(distance * 100)cm",
                    extrusionDepth: 0.1,
                    font: .systemFont(ofSize: 1.0), // 小さいとフォントがつぶれてしまうのでこれぐらいに設定
                    containerFrame: CGRect.zero,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail)

        // 環境マッピングするマテリアルを設定
        let textMaterial = SimpleMaterial(color: UIColor.yellow, roughness: 0.0, isMetallic: true)
        let textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textModel.scale = SIMD3<Float>(0.01, 0.01, 0.01) // 10分の1に縮小
        textModel.position = SIMD3<Float>(0.0, 0.0, -0.02) // 奥0.2m
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
