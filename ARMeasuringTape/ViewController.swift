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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    /*
     * The measure will be dropped from center point of the device
     * You may change that distance (it is in meter, 0.2 = 0.2meter)
     */
    var MeasureDistanceFromCenterPoint: Float = 0.2

    enum MeasureMode {
        case none, measuring
    }

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var cirImgV: UIImageView!

    fileprivate var measureMode = MeasureMode.none
    fileprivate var measuringRuler: RulerNode? = nil
    fileprivate var startPoint: SCNVector3?

    fileprivate var rulerArray = [RulerNode]()
    
    var isFeature: Bool = false {
        didSet {
            cirImgV.image = isFeature == true ? UIImage.init(named: "circle") : UIImage.init(named: "circle_dis")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true

        setupBtns()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.planeDetection = .horizontal
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.automaticallyUpdatesLighting = true
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
        else if let line = lines.last {
            if currentLine == nil {
                line.removeFromParentNode()
                lines.removeLast()
            }
        }
        
        measuringRuler?.removeFromParentNode()
        measuringRuler = nil
        startPoint = nil
        currentLine?.removeFromParentNode()
        currentLine = nil

        measureMode = .none
        setupBtns()
        showInfo()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    @IBAction func startBtnTouchUp(_ sender: Any) {
        if isFeature == false {
            HUG.show(title: "正在获取焦点", inSource: self)
            return
        }
        
        if let ruler = measuringRuler {
            rulerArray.append(ruler)
        }
        else if let line = currentLine {
            lines.append(line)
        }

        measuringRuler = nil
        currentLine = nil
        startPoint = nil
        endPoint = SCNVector3()

        measureMode = measureMode == .none ? .measuring : .none
        setupBtns()
        showInfo()
    }

    fileprivate func setupBtns() {
        startBtn.isSelected = measureMode == .none ? false : true
    }


    // MARK: - ARSCNViewDelegate
    fileprivate lazy var lines: [Line] = []
    fileprivate var currentLine: Line?
    fileprivate var endPoint =  SCNVector3()

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.measureKK()
        }
    }
    
    func measureKK() {
        guard sceneView.pointOfView != nil else {
            isFeature = false
            return
        }
        
        guard let current = sceneView.realWorldVector(screenPosition: view.center) else {
            isFeature = false
            return
        }
        
        isFeature = true
        guard measureMode == .measuring else {return}
        let currentPoint = current.0
        let distance = current.1
        
        func showText() {
            if let ruler = measuringRuler {
                self.infoLabel.text = ruler.lengthString()
            }
            else if let line = currentLine {
                self.infoLabel.text = line.text.string as? String
            }
        }
        
        func xiantiao() {
            guard let startPoint = startPoint else {
                self.startPoint = currentPoint
                return
            }
            
            if currentLine == nil {
                currentLine = Line(sceneView: sceneView, startVector: startPoint, unit: .centimeter)
            }
            else {
                endPoint = currentPoint
                currentLine?.update(to: currentPoint)
            }
            
            showText()
        }
        
        func juanchi() {
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
            
            showText()
        }
        
        if measuringRuler != nil {
            juanchi()
            return
        }
        else if currentLine != nil {
            xiantiao()
            return
        }

        if distance > 0.5 {//超过20cm使用
            xiantiao()
        }
        else {
            juanchi()
        }

    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .restricted || status == .denied {
            let vc = UIAlertController.init(title: "应用相机权限受限，请选择允许。", message: nil, preferredStyle: .alert)
            let action = UIAlertAction.init(title: "确定", style: .default) { (_) in
                guard let url = URL.init(string: UIApplicationOpenSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            vc.addAction(action)
            self.present(vc, animated: true, completion: nil)
            return
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
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
                    HUG.show(title: "AR功能正在初始化", message: "请左右晃动设备以获取更多特征点", inSource: self)
                case .insufficientFeatures:
                    HUG.show(title: "AR功能受限", message: "请左右晃动设备以获取更多特征点", inSource: self)
                case .excessiveMotion:
                    HUG.show(title: "AR功能受限", message: "设备移动过快", inSource: self)
                default:
                    break
                }
            case .normal:
                HUG.dismiss()
                if infoLabel.text == "Loading" {
                    infoLabel.text = ""
                }
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

