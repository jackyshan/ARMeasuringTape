//
//  ViewController.swift
//  ARMeasuringTape
//
//  Created by NguyenPham on 7/8/17.
//  Copyright © 2017 Softgaroo. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    /*
     * The measure will be dropped from center point of the device
     * You may change that distance (it is in meter, 0.2 = 0.2meter)
     */
    let MeasureDistanceFromCenterPoint: Float = 0.2

    enum MeasureMode {
        case none, measuring
    }

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!

    fileprivate var measureMode = MeasureMode.none
    fileprivate var measuringRuler: RulerNode? = nil
    fileprivate var startPoint: SCNVector3?

    fileprivate var rulerArray = [RulerNode]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true

        setupBtns()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        sceneView.debugOptions = [.showFeaturePoints]
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    @IBAction func copyInfo(_ sender: Any) {
        UIPasteboard.general.string = infoLabel.text
        HUG.show(title: "已复制到剪贴版", inSource: self)
    }
    
    @IBAction func cancelBtnTouchUp(_ sender: Any) {
        
        if let ruler = rulerArray.last {
            if measuringRuler == nil {
                ruler.removeFromParentNode()
                rulerArray.removeLast()
            }
        }
        
        measuringRuler?.removeFromParentNode()
        measuringRuler = nil
        startPoint = nil

        measureMode = .none
        setupBtns()
        showInfo()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    @IBAction func startBtnTouchUp(_ sender: Any) {
        if let ruler = measuringRuler {
            rulerArray.append(ruler)
        }

        measuringRuler = nil
        startPoint = nil

        measureMode = measureMode == .none ? .measuring : .none
        setupBtns()
        showInfo()
    }

    fileprivate func setupBtns() {
        startBtn.isSelected = measureMode == .none ? false : true
    }


    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {

        guard measureMode == .measuring,
            let pointOfView = sceneView.pointOfView else {
            return
        }

        let mat = pointOfView.transform
        let delta = SCNVector3(-MeasureDistanceFromCenterPoint * mat.m31, -MeasureDistanceFromCenterPoint * mat.m32, -MeasureDistanceFromCenterPoint * mat.m33)
        let currentPoint = pointOfView.position + delta

        guard let startPoint = startPoint else {
            self.startPoint = currentPoint
            return
        }

        if measuringRuler == nil {
            measuringRuler = RulerNode(startPoint: startPoint, endPoint: currentPoint)
            self.sceneView.scene.rootNode.addChildNode(self.measuringRuler!)
        } else {
            measuringRuler?.update(endPoint: currentPoint)
        }

        showInfo()
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    private var lastState: ARCamera.TrackingState = .notAvailable {
        didSet {
            switch lastState {
            case .notAvailable:
                guard HUG.isVisible else { return }
                HUG.show(title: "AR不可用")
            case .limited(let reason):
                switch reason {
                case .initializing:
                    HUG.show(title: "AR功能正在初始化", message: "请左右晃动设备以获取更多特征点", inSource: self, autoDismissDuration: 5)
                case .insufficientFeatures:
                    HUG.show(title: "AR功能受限", message: "请左右晃动设备以获取更多特征点", inSource: self, autoDismissDuration: 5)
                case .excessiveMotion:
                    HUG.show(title: "AR功能受限", message: "设备移动过快", inSource: self, autoDismissDuration: 5)
                default:
                    break
                }
            case .normal:
                HUG.dismiss()
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        DispatchQueue.main.async {
            self.lastState = state
        }
    }

    fileprivate func showInfo() {
        if let ruler = measuringRuler {
            DispatchQueue.main.async {
                self.infoLabel.text = ruler.lengthString()
            }
        }
    }

}

struct HUG {
    
    private static var _alertController: UIAlertController?
    
    static var isVisible: Bool {
        return _alertController != nil
    }
    
    static func show(title: String?,
                     message: String? = nil,
                     inSource viewController: UIViewController? = nil ,
                     autoDismissDuration duration: TimeInterval? = 2) {
        
        let vc = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        guard let source = viewController else { return }
        _alertController?.dismiss(animated: false, completion: nil)
        _alertController = nil
        _alertController = vc
        source.presentedViewController?.dismiss(animated: false, completion: nil)
        source.present(vc, animated: true, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + (duration ?? 2), execute: {
            vc.dismiss(animated: true, completion: nil)
            _alertController = nil
        })
    }
    
    static func dismiss() {
        _alertController?.dismiss(animated: true, completion: nil)
        _alertController = nil
    }
    
}