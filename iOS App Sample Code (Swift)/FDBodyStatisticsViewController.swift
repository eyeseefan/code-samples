//
//  FDBodyStatisticsViewController.swift
//  Fitness Diary
//
//  Created by Fan Bu on 18/06/2017.
//  Copyright © 2017 FanStudio. All rights reserved.
//

/* This is a code sample from my iOS App "Fitness Diary" that I wrote in 2017 and 2018.
 * The code below is responsible for 4 pages in the app, which serve to show the statistics
 * of the user. The user can scoll left and right to navigate between the pages. The first
 * page shows the general statistics of the user, such as weight, height, BMI, etc. The second
 * page shows the measurements of the user, which has different UI for male and female. The
 * third page shows the lifting records of the user. The background of the 4 pages is a single
 * giant 3D scene that has an 3D avatar with similar shape as the user (changes according to the
 * user's statistics) and some dumbbells. As the user scrolls left and right and navigate among the
 * 3 pages, the camera for the 3D scene changes angle and position to focus on different contents.
 * For example, when the user scroll to the thrid page with the lifts, the camera angle will
 * move smoothly from the 3D avatar to focus on the dumbells. On the 4th page, the camera
 * will only focus on the giant 3D avatar. The user is able to scoll the avatar to look at it
 * from 360 degrees. The app is already off App Store, as I have unsuscribed from Apple's Developer
 * Program. However, the snapshots of the app are included in the same folder of this source code, which
 * demonstrates some of the functionalities mentioned above.
 */

import UIKit
import SceneKit
import SceneKit.ModelIO

class FDBodyStatisticsViewController: UIViewController,UIScrollViewDelegate, FDMotionEffectDelegate,FDTableViewCellBackgroundViewDelegate {
    
    @IBOutlet var coverView: UIView!
    @IBOutlet var scnView: SCNView!
    @IBOutlet var scrollView: UIScrollView!
    
    var statisticsTableViews = [UITableView]()
    
    lazy var generalStatsController = FDGeneralStatsController()
    lazy var measurementStatsController = FDMeasurementStatsController()
    lazy var liftStatsController = FDLiftStatsController()
    
    var sceneCameraNode : SCNNode!
    var modelNode : SCNNode!
    var focusedModelNode : SCNNode!
    var currentModelName = ""
    let loadModelQueue = DispatchQueue(label: "loadModelQueue", attributes: [])

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Statistics"
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.scnViewTapped(_:)))
        scnView.addGestureRecognizer(tapGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.scnViewPanned(_:)))
        scnView.addGestureRecognizer(panGestureRecognizer)
        
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        for _ in 0...2{
            let tableView = FDCancelTouchTableView(frame: CGRect(), style: .grouped)
            tableView.separatorStyle = .none
            tableView.bounces = false
            tableView.showsVerticalScrollIndicator = false
            tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 18))
            tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
            tableView.sectionHeaderHeight = 10
            tableView.sectionFooterHeight = 10
            tableView.backgroundColor = UIColor.clear
            statisticsTableViews.append(tableView)
            scrollView.addSubview(tableView)
        }
        
        //Page 0
        generalStatsController.bodyStatsViewController = self
        statisticsTableViews[0].dataSource = generalStatsController
        statisticsTableViews[0].delegate = generalStatsController
        statisticsTableViews[0].register(UINib(nibName: "GeneralStatsTableViewCell", bundle: nil), forCellReuseIdentifier: "generalStats")
        statisticsTableViews[0].register(UINib(nibName: "GeneralStatsExtendedTableViewCell", bundle: nil), forCellReuseIdentifier: "generalStatsExtended")
        statisticsTableViews[0].register(UINib(nibName: "BodyFatTableViewCell", bundle: nil), forCellReuseIdentifier: "bodyFat")
        
        //Page 1
        measurementStatsController.bodyStatsViewController = self
        statisticsTableViews[1].dataSource = measurementStatsController
        statisticsTableViews[1].delegate = measurementStatsController
        statisticsTableViews[1].register(UINib(nibName: "MeasurementStatsTableViewCell", bundle: nil), forCellReuseIdentifier: "measurementStats")
        if UIScreen.main.bounds.width < 375{
            statisticsTableViews[1].register(UINib(nibName: "MeasurementStatsBigTableViewCell-Small", bundle: nil), forCellReuseIdentifier: "measurementStatsBig")
        }else{
            statisticsTableViews[1].register(UINib(nibName: "MeasurementStatsBigTableViewCell", bundle: nil), forCellReuseIdentifier: "measurementStatsBig")
        }
        
        if UIScreen.main.bounds.width == 375{
            statisticsTableViews[1].isScrollEnabled = false
        }
        
        //Page 2
        liftStatsController.bodyStatsViewController = self
        statisticsTableViews[2].dataSource = liftStatsController
        statisticsTableViews[2].delegate = liftStatsController
        statisticsTableViews[2].register(UINib(nibName:"LiftStatsTableViewCell",bundle: nil), forCellReuseIdentifier: "liftStatsCell")
        
        loadModelQueue.async {
            let scene = SCNScene(named: "art.scnassets/avatar.scn")!
            let gender = self.generalStatsController.userGender!
            let heightRecord = self.generalStatsController.latestHeightRecord
            let weightRecord = self.generalStatsController.latestWeightRecord
            let bodyFatRecord = self.generalStatsController.latestBodyFatRecord
            self.currentModelName = modelNodeNameFor(gender: gender, heightRecord: heightRecord, weightRecord: weightRecord, bodyFatRecord: bodyFatRecord)
            let path = Bundle.main.url(forResource: self.currentModelName, withExtension: "obj")!
            let asset = MDLAsset(url: path)
            let obj = asset.object(at: 0)
            let node = SCNNode(mdlObject: obj)
            for material in node.geometry!.materials{
                material.lightingModel = .blinn
            }
            if UserDefaults.standard.integer(forKey: "AvatarColor") != 1{
                let avatarColor = FDAvatarColor(rawValue: UserDefaults.standard.integer(forKey: "AvatarColor"))!
                for material in node.geometry!.materials{
                    if material.diffuse.contents is String{
                        var mapString = material.diffuse.contents as! String
                        let index = mapString.index(mapString.endIndex, offsetBy: -5)
                        if mapString.substring(from: index) == "y.jpg"{
                            mapString.replaceSubrange(index...index, with: avatarColor.shortString)
                            material.diffuse.contents = mapString
                        }
                    }
                }
            }
            if gender == .male{
                node.scale = SCNVector3Make(0.095, 0.095, 0.095)
            }else{
                node.scale = SCNVector3Make(0.022, 0.022, 0.022)
            }
            DispatchQueue.main.sync {
                self.scnView.scene = scene
                self.sceneCameraNode = scene.rootNode.childNode(withName: "camera", recursively: false)!
                self.modelNode = scene.rootNode.childNode(withName: "model", recursively: false)!
                self.focusedModelNode = scene.rootNode.childNode(withName: "model-focus", recursively: false)!
                self.modelNode.addChildNode(node)
                let clonedNode = node.clone()
                self.focusedModelNode.addChildNode(clonedNode)
                self.resetCameraNodePosition()
                self.scrollView.delegate = self
                if UserDefaults.standard.bool(forKey: "PerspectiveUI"){
                    let motionEffect = FDMotionEffect()
                    motionEffect.delegate = self
                    self.view.addMotionEffect(motionEffect)
                }
                UIView.animate(withDuration: 1, animations: {
                    self.coverView.alpha = 0
                }, completion: { (_) in
                    self.coverView.isHidden = true
                })
            }
        }
    }
    
    func addMotionEffect(){
        let motionEffect = FDMotionEffect()
        motionEffect.delegate = self
        self.view.addMotionEffect(motionEffect)
    }
    
    func resetAndRemoveMotionEffect(){
        resetMotionEffectOffset()
        self.view.motionEffects.forEach { (m) in
            self.view.removeMotionEffect(m)
        }
    }
    
    func reloadModel(){
        let gender = self.generalStatsController.userGender!
        let heightRecord = self.generalStatsController.latestHeightRecord
        let weightRecord = self.generalStatsController.latestWeightRecord
        let bodyFatRecord = self.generalStatsController.latestBodyFatRecord
        loadModelQueue.async {
            let nodeName = modelNodeNameFor(gender: gender, heightRecord: heightRecord, weightRecord: weightRecord, bodyFatRecord: bodyFatRecord)
            if nodeName == self.currentModelName{
                return
            }else{
                self.currentModelName = nodeName
            }
            let path = Bundle.main.url(forResource: self.currentModelName, withExtension: "obj")!
            let asset = MDLAsset(url: path)
            let obj = asset.object(at: 0)
            let node = SCNNode(mdlObject: obj)
            for material in node.geometry!.materials{
                material.lightingModel = .blinn
            }
            if UserDefaults.standard.integer(forKey: "AvatarColor") != 1{
                let avatarColor = FDAvatarColor(rawValue: UserDefaults.standard.integer(forKey: "AvatarColor"))!
                for material in node.geometry!.materials{
                    if material.diffuse.contents is String{
                        var mapString = material.diffuse.contents as! String
                        let index = mapString.index(mapString.endIndex, offsetBy: -5)
                        if mapString.substring(from: index) == "y.jpg"{
                            mapString.replaceSubrange(index...index, with: avatarColor.shortString)
                            material.diffuse.contents = mapString
                        }
                    }
                }
            }
            if gender == .male{
                node.scale = SCNVector3Make(0.095, 0.095, 0.095)
            }else{
                node.scale = SCNVector3Make(0.022, 0.022, 0.022)
            }
            DispatchQueue.main.sync {
                self.modelNode.childNodes[0].removeFromParentNode()
                self.focusedModelNode.childNodes[0].removeFromParentNode()
                if self.modelNode.childNodes.count != 0 || self.focusedModelNode.childNodes.count != 0{
                    print("ERROR!!!!!! MORE THAN 0 CHILD NODES AFTER REMOVING")
                }
                self.modelNode.addChildNode(node)
                self.focusedModelNode.addChildNode(node.clone())
                self.scnView.setNeedsDisplay()
            }
        }
    }
    
    func reloadModelColor(){
        let avatarColor = FDAvatarColor(rawValue: UserDefaults.standard.integer(forKey: "AvatarColor"))!
        loadModelQueue.async {
            for material in self.modelNode.childNodes.first!.geometry!.materials{
                if material.diffuse.contents is String{
                    var mapString = material.diffuse.contents as! String
                    let index = mapString.index(mapString.endIndex, offsetBy: -5)
                    if mapString.substring(from: index) == "y.jpg" || mapString.substring(from: index) == "b.jpg" || mapString.substring(from: index) == "w.jpg"{
                        mapString.replaceSubrange(index...index, with: avatarColor.shortString)
                        material.diffuse.contents = mapString
                    }
                }
            }
            DispatchQueue.main.sync {
                self.scnView.setNeedsDisplay()
            }
        }
    }

    func reloadAllTableViews(){
        statisticsTableViews.forEach { (tableView) in
            tableView.reloadData()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for i in 0...statisticsTableViews.count-1{
            statisticsTableViews[i].frame = CGRect(x: CGFloat(i)*scrollView.bounds.width, y: 0, width: scrollView.bounds.width, height: scrollView.bounds.height)
        }
        scrollView.contentSize.height = scrollView.bounds.height
        scrollView.contentSize.width = scrollView.bounds.width*CGFloat(statisticsTableViews.count+1)
    }
    
    func didSelectBackgroundViewAt(page: Int, indexPath: IndexPath, identifierTag: Int) {
        print("Page: ",page,", IndexPath: ",indexPath,", identifierTag: ",identifierTag)
        switch page {
        case 0:
            switch indexPath.section {
            case 0:
                switch indexPath.row {
                case 0:
                    let birthdayTableViewController = FDBirthdayTableViewController(style: .grouped)
                    self.navigationController!.pushViewController(birthdayTableViewController, animated: true)
                case 1:
                    let genderTableViewController = FDGenderTableViewController(style: .grouped)
                    self.navigationController!.pushViewController(genderTableViewController, animated: true)
                case 2:
                    let heightRecordsViewController = FDStatisticsRecordsViewController(recordsType: .height)
                    heightRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(heightRecordsViewController, animated: true)
                case 3:
                    let weightRecordsViewController = FDStatisticsRecordsViewController(recordsType: .weight)
                    weightRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(weightRecordsViewController, animated: true)
                default: break
                }
            case 1:
                switch indexPath.row {
                case 0:
                    let BMIInfoViewController : FDBMIInfoViewController
                    if UIScreen.main.bounds.width < 375{
                        BMIInfoViewController = FDBMIInfoViewController(nibName: "FDBMIInfoViewController-Small", bundle: nil)
                    }else{
                        BMIInfoViewController = FDBMIInfoViewController()
                    }
                    BMIInfoViewController.UserBMI = generalStatsController.userBMI
                    self.navigationController!.pushViewController(BMIInfoViewController, animated: true)
                case 1:
                    let BMRInfoViewController : FDBMRInfoViewController
                    if UIScreen.main.bounds.width < 375{
                        BMRInfoViewController = FDBMRInfoViewController(nibName: "FDBMRInfoViewController-Small", bundle: nil)
                    }else{
                        BMRInfoViewController = FDBMRInfoViewController()
                    }
                    BMRInfoViewController.UserBMR = generalStatsController.userBMR
                    self.navigationController!.pushViewController(BMRInfoViewController, animated: true)
                default: break
                }
            case 2:
                switch indexPath.row {
                case 0:
                    let bodyFatRecordsViewController = FDStatisticsRecordsViewController(recordsType: .bodyFat)
                    bodyFatRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(bodyFatRecordsViewController, animated: true)
                case 1:
                    let FFMIInfoViewController : FDFFMIInfoViewController
                    if UIScreen.main.bounds.width < 375{
                        FFMIInfoViewController = FDFFMIInfoViewController(nibName: "FDFFMIInfoViewController-Small", bundle: nil)
                    }else{
                        FFMIInfoViewController = FDFFMIInfoViewController()
                    }
                    FFMIInfoViewController.UserFFMI = generalStatsController.userFFMI
                    self.navigationController!.pushViewController(FFMIInfoViewController, animated: true)
                default: break
                }
            default: break
            }
        case 1:
            switch indexPath.section{
            case 0:
                switch identifierTag{
                case 0:
                    let measurementRecordsViewController = FDStatisticsRecordsViewController(recordsType: .measurement("Chest"))
                    measurementRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(measurementRecordsViewController, animated: true)
                case 1:
                    let measurementRecordsViewController = FDStatisticsRecordsViewController(recordsType: .measurement("Waist"))
                    measurementRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(measurementRecordsViewController, animated: true)
                default: break
                }
            case 1:
                let measurementRecordsViewController = FDStatisticsRecordsViewController(recordsType: .measurement("Hips"))
                measurementRecordsViewController.bodyStatisticsViewController = self
                self.navigationController!.pushViewController(measurementRecordsViewController, animated: true)
            case 2:
                switch indexPath.row{
                case 0:
                    let measurementRecordsViewController = FDStatisticsRecordsViewController(recordsType: .measurement("Arms"))
                    measurementRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(measurementRecordsViewController, animated: true)
                case 1:
                    let measurementRecordsViewController = FDStatisticsRecordsViewController(recordsType: .measurement("Thighs"))
                    measurementRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(measurementRecordsViewController, animated: true)
                case 2:
                    let measurementRecordsViewController = FDStatisticsRecordsViewController(recordsType: .measurement("Calves"))
                    measurementRecordsViewController.bodyStatisticsViewController = self
                    self.navigationController!.pushViewController(measurementRecordsViewController, animated: true)
                default: break
                }
            default: break
            }
        case 2:
            switch indexPath.row{
            case 0:
                let liftRecordsViewController = FDStatisticsRecordsViewController(recordsType: .lift("Bench Press"))
                liftRecordsViewController.bodyStatisticsViewController = self
                self.navigationController!.pushViewController(liftRecordsViewController, animated: true)
            case 1:
                let liftRecordsViewController = FDStatisticsRecordsViewController(recordsType: .lift("Squat"))
                liftRecordsViewController.bodyStatisticsViewController = self
                self.navigationController!.pushViewController(liftRecordsViewController, animated: true)
            case 2:
                let liftRecordsViewController = FDStatisticsRecordsViewController(recordsType: .lift("Deadlift"))
                liftRecordsViewController.bodyStatisticsViewController = self
                self.navigationController!.pushViewController(liftRecordsViewController, animated: true)
            default: break
            }
        default: break
        }
    }
    
    //MARK: Animations

    var startAnimation = true
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        guard startAnimation else {
            return
        }
        
        if let bodyfat = generalStatsController.latestBodyFatRecord?.bodyFatPercentage!.doubleValue {
            if let cell = statisticsTableViews[0].cellForRow(at: IndexPath(row: 0, section: 2)){
                let duration : Double = 1
                let progressView = cell.viewWithTag(1) as! FDCircleProgressView
                let endProgress = min(bodyfat/50,1)
                progressView.progressPercentage = 0
                progressView.setProgressPercentage(endProgress, animated: true,duration:duration)
                let bfLabel = cell.viewWithTag(3) as! UILabel
                animateLabelNumber(label: bfLabel, startNumber: max(0,bodyfat-10), endNumber: bodyfat, suffix: "%", duration: duration)
            }
        }
        
        startAnimation = false
    }
    
    let horizontalMotionEffectMaxAngle: Float = 8
    let verticalMotionEffectMaxAngle: Float = 5
    
    func motionEffect(forViwerOffset viewerOffset: UIOffset) {
        verticalMotionEffectCameraOffsetAngle = verticalMotionEffectMaxAngle*Float(viewerOffset.vertical)
        horizontalMotionEffectCameraOffsetAngle = horizontalMotionEffectMaxAngle*Float(viewerOffset.horizontal)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.06
        
        if scrollView.contentOffset.x <= 0{
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19+horizontalMotionEffectCameraOffsetAngle)
            
        }else if scrollView.contentOffset.x <= scrollView.bounds.width{
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19-44*Float(scrollView.contentOffset.x/scrollView.bounds.width)+horizontalMotionEffectCameraOffsetAngle)
        }else if scrollView.contentOffset.x <= scrollView.bounds.width*2{
            
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 1)
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6-10*progress+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-25+22*progress+horizontalMotionEffectCameraOffsetAngle)
            
        }else if scrollView.contentOffset.x < scrollView.bounds.width*3{
            
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 2)
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-16-1*progress+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-3+3*progress+horizontalMotionEffectCameraOffsetAngle)
            
        }else{
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-17+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(0+horizontalMotionEffectCameraOffsetAngle)
        }

        SCNTransaction.commit()
    }
    
    func resetMotionEffectOffset(){
        verticalMotionEffectCameraOffsetAngle = 0
        horizontalMotionEffectCameraOffsetAngle = 0
        
        if scrollView.contentOffset.x <= 0{
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19)
        }else if scrollView.contentOffset.x <= scrollView.bounds.width{
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19-44*Float(scrollView.contentOffset.x/scrollView.bounds.width))
        }else if scrollView.contentOffset.x <= scrollView.bounds.width*2{
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 1)
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6-10*progress)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-25+22*progress)
            
        }else if scrollView.contentOffset.x < scrollView.bounds.width*3{
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 2)
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-16-1*progress)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-3+3*progress)
        }else{
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-17)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(0)
        }
    }
    
    var horizontalMotionEffectCameraOffsetAngle : Float = 0
    var verticalMotionEffectCameraOffsetAngle : Float = 0
    
    func resetCameraNodePosition(){
        if scrollView.contentOffset.x <= 0{
            
            sceneCameraNode.position.x = 1
            sceneCameraNode.position.y = 1.5
            sceneCameraNode.position.z = 3.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19+horizontalMotionEffectCameraOffsetAngle)
            
        }else if scrollView.contentOffset.x <= scrollView.bounds.width{
            
            sceneCameraNode.position.x = 1 - Float(scrollView.contentOffset.x/scrollView.bounds.width)
            sceneCameraNode.position.y = 1.5
            sceneCameraNode.position.z = 3.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19-44*Float(scrollView.contentOffset.x/scrollView.bounds.width)+horizontalMotionEffectCameraOffsetAngle)
        }else if scrollView.contentOffset.x <= scrollView.bounds.width*2{
            
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 1)
            sceneCameraNode.position.x = progress*3
            sceneCameraNode.position.y = 1.5 - 0.5*progress
            sceneCameraNode.position.z = 3.5 - progress
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6-10*progress+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-25+22*progress+horizontalMotionEffectCameraOffsetAngle)
            
        }else if scrollView.contentOffset.x < scrollView.bounds.width*3{
            
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 2)
            
            sceneCameraNode.position.x = 3+progress*2
            sceneCameraNode.position.y = 1+progress*0.2
            sceneCameraNode.position.z = 2.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-16-1*progress+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-3+3*progress+horizontalMotionEffectCameraOffsetAngle)
            
        }else{
            sceneCameraNode.position.x = 5
            sceneCameraNode.position.y = 1.2
            sceneCameraNode.position.z = 2.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-17+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(0+horizontalMotionEffectCameraOffsetAngle)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.06
        if scrollView.contentOffset.x <= 0{
            
            sceneCameraNode.position.x = 1
            sceneCameraNode.position.y = 1.5
            sceneCameraNode.position.z = 3.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19+horizontalMotionEffectCameraOffsetAngle)
            
        }else if scrollView.contentOffset.x <= scrollView.bounds.width{
            
            sceneCameraNode.position.x = 1 - Float(scrollView.contentOffset.x/scrollView.bounds.width)
            sceneCameraNode.position.y = 1.5
            sceneCameraNode.position.z = 3.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(19-44*Float(scrollView.contentOffset.x/scrollView.bounds.width)+horizontalMotionEffectCameraOffsetAngle)
        }else if scrollView.contentOffset.x <= scrollView.bounds.width*2{
            
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 1)
            sceneCameraNode.position.x = progress*3
            sceneCameraNode.position.y = 1.5 - 0.5*progress
            sceneCameraNode.position.z = 3.5 - progress
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-6-10*progress+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-25+22*progress+horizontalMotionEffectCameraOffsetAngle)
            
        }else if scrollView.contentOffset.x < scrollView.bounds.width*3{
            
            let progress = Float(scrollView.contentOffset.x/scrollView.bounds.width - 2)
            
            sceneCameraNode.position.x = 3+progress*2
            sceneCameraNode.position.y = 1+progress*0.2
            sceneCameraNode.position.z = 2.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-16-1*progress+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(-3+3*progress+horizontalMotionEffectCameraOffsetAngle)
            
        }else{
            sceneCameraNode.position.x = 5
            sceneCameraNode.position.y = 1.2
            sceneCameraNode.position.z = 2.5
            
            sceneCameraNode.eulerAngles.x = GLKMathDegreesToRadians(-17+verticalMotionEffectCameraOffsetAngle)
            sceneCameraNode.eulerAngles.y = GLKMathDegreesToRadians(0+horizontalMotionEffectCameraOffsetAngle)
        }
        SCNTransaction.commit()
    }
    
    var edgeIndicatorShown = false
    
    func showEdgeIndicatorIfNeeded(){
        if !edgeIndicatorShown{
            let edgeIndicator = FDEdgeIndicatorView(frame: CGRect(x: 0, y: 0, width: scnView.bounds.width/4, height: scnView.bounds.height))
            edgeIndicator.isUserInteractionEnabled = false
            edgeIndicator.alpha = 0
            edgeIndicator.isOpaque = false
            self.scnView.addSubview(edgeIndicator)
            UIView.animate(withDuration: 0.5, delay: 0, options: [.allowUserInteraction], animations: {
                edgeIndicator.alpha = 1
            }, completion: { (_) in
                UIView.animate(withDuration: 1.5, animations: {
                    edgeIndicator.alpha = 0
                }, completion: { (_) in
                    edgeIndicator.removeFromSuperview()
                })
            })
            self.edgeIndicatorShown = true
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate{
            if scrollView.contentOffset.x >= scrollView.bounds.width*3 {
                scrollView.isUserInteractionEnabled = false
                showEdgeIndicatorIfNeeded()
            }else{
                scrollView.isUserInteractionEnabled = true
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x >= scrollView.bounds.width*3 {
            scrollView.isUserInteractionEnabled = false
            showEdgeIndicatorIfNeeded()
        }else{
            scrollView.isUserInteractionEnabled = true
        }
    }
    
    func scnViewTapped(_ sender: UITapGestureRecognizer){
        if sender.location(in: scnView).x <= scnView.bounds.width/4 {
            scrollView.isUserInteractionEnabled = true
            scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width*2,y: 0), animated: true)
        }
    }
    
    var scnViewPanFirstLocationX : CGFloat = 0
    var scnViewPanModelFirstRotationY: Float = 0
    var fromScreenEdge : Bool = false
    var screenEdgeThreshold : CGFloat = UIScreen.main.bounds.width/5
    func scnViewPanned(_ sender: UIPanGestureRecognizer){
        switch sender.state {
        case .began:
            if sender.location(in: scnView).x <= screenEdgeThreshold {
                fromScreenEdge = true
                scnViewPanFirstLocationX = sender.location(in: scnView).x
            }else{
                fromScreenEdge = false
                scnViewPanFirstLocationX = sender.location(in: scnView).x
                scnViewPanModelFirstRotationY = focusedModelNode.eulerAngles.y
            }
        case .changed:
            if fromScreenEdge{
                let contentOffset = CGPoint(x:scrollView.bounds.width*3-sender.location(in: scnView).x + scnViewPanFirstLocationX, y: 0)
                self.scrollView.setContentOffset(contentOffset, animated: false)
            }else{
                let offsetAngle = (sender.location(in: scnView).x - scnViewPanFirstLocationX)/scnView.bounds.width*CGFloat.pi
                focusedModelNode.eulerAngles.y = scnViewPanModelFirstRotationY + Float(offsetAngle)
            }
        case .ended, .cancelled:
            if fromScreenEdge{
                if sender.velocity(in: scnView).x >= 500 || (self.scrollView.contentOffset.x / scrollView.bounds.width) < 2.5{
                    self.scrollView.setContentOffset(CGPoint(x: self.scrollView.bounds.width*2, y: 0), animated: true)
                    self.scrollView.isUserInteractionEnabled = true
                }else{
                    self.scrollView.setContentOffset(CGPoint(x: self.scrollView.bounds.width*3, y: 0), animated: true)
                    self.scrollView.isUserInteractionEnabled = false
                }
            }
        default:
            break
        }
    }
    
    func animateLabelNumber(label: UILabel, startNumber:Double,endNumber:Double,suffix: String = "",duration : Double = 1){
        
        let displayLink = CADisplayLink(target: self, selector: #selector(self._animate(_:)))
        animationStartTime = CACurrentMediaTime()
        animationLabel = label
        animationStartNumber = startNumber
        animationEndNumber = endNumber
        animationSuffix = suffix
        animationDuration = duration
        label.text = formattedStringFrom(double: startNumber)+animationSuffix
        displayLink.add(to: .current, forMode: .defaultRunLoopMode)
        
    }
    
    var animationStartTime : CFTimeInterval!
    var animationLabel : UILabel!
    var animationStartNumber: Double!
    var animationEndNumber : Double!
    var animationSuffix : String!
    var animationDuration: Double!
    
    func _animate(_ displayLink:CADisplayLink){
        
        let timeInterval = displayLink.timestamp-animationStartTime
        
        if timeInterval >= animationDuration{
            animationLabel.text = formattedStringFrom(double: animationEndNumber)+animationSuffix
            displayLink.invalidate()
            return
        }
        
        let newNumber = animationStartNumber + (animationEndNumber-animationStartNumber)*timeInterval/animationDuration
        animationLabel.text = formattedStringFrom(double: newNumber)+animationSuffix
    }
    
}

class FDTableViewCellBackgroundView: UIButton {
    var pageNumber : Int = 0
    var assignedIndexPath : IndexPath?
    var identifierTag : Int = 0
    var delegate : FDTableViewCellBackgroundViewDelegate?
    var highLightOverlay = UIView()
    
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    func initialize(){
        self.clipsToBounds = true
        self.layer.cornerRadius = 10
        highLightOverlay.clipsToBounds = true
        highLightOverlay.layer.cornerRadius = 10
        highLightOverlay.backgroundColor = UIColor(white: 0, alpha: 0.3)
        highLightOverlay.isUserInteractionEnabled = false
        self.addSubview(highLightOverlay)
        highLightOverlay.isHidden = true
        self.addTarget(self, action: #selector(self.buttonTouchedDown(_:event:)), for: .touchDown)
        self.addTarget(self, action: #selector(self.buttonTouchedUpInside(_:event:)), for: .touchUpInside)
        self.addTarget(self, action: #selector(self.buttonTouchedUpOutside(_:event:)), for: .touchUpOutside)
        self.addTarget(self, action: #selector(self.buttonTouchCancelled(_:event:)), for: .touchCancel)
        self.addTarget(self, action: #selector(self.buttonTouchDragEnter(_:event:)), for: .touchDragEnter)
        self.addTarget(self, action: #selector(self.buttonTouchDragExit(_:event:)), for: .touchDragExit)
    }
    
    func superTableViewCell(view: UIView) -> UITableViewCell{
        if view.superview is UITableViewCell{
            return view.superview as! UITableViewCell
        }else{
            return superTableViewCell(view: self.superview!)
        }
    }
    
    func buttonTouchedDown(_ button : UIButton,event: UIEvent) {
        highLightOverlay.frame = button.bounds
        highLightOverlay.isHidden = false
    }
    
    func buttonTouchedUpInside(_ button: UIButton,event: UIEvent){
        UIView.animate(withDuration: 0.4, animations: {
            self.highLightOverlay.alpha = 0
        }) { (completed) in
            self.highLightOverlay.isHidden = true
            self.highLightOverlay.alpha = 1
        }
        
        self.delegate?.didSelectBackgroundViewAt?(page: pageNumber, indexPath: assignedIndexPath!, identifierTag: identifierTag)
        self.delegate?.didSelectBackgroundViewOf?(cell: superTableViewCell(view: self))
    }
    
    func buttonTouchedUpOutside(_ button: UIButton,event: UIEvent){
        highLightOverlay.isHidden = true
    }
    
    func buttonTouchDragEnter(_ button: UIButton,event: UIEvent){
        highLightOverlay.isHidden = false
    }
    
    func buttonTouchDragExit(_ button: UIButton,event: UIEvent){
        highLightOverlay.isHidden = true
    }
    
    func buttonTouchCancelled(_ button: UIButton,event: UIEvent){
        highLightOverlay.isHidden = true
    }
}

@objc protocol FDTableViewCellBackgroundViewDelegate : NSObjectProtocol {
    @objc optional func didSelectBackgroundViewAt(page: Int, indexPath: IndexPath,identifierTag: Int)
    @objc optional func didSelectBackgroundViewOf(cell: UITableViewCell)
}

class FDCancelTouchTableView : UITableView{
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
}