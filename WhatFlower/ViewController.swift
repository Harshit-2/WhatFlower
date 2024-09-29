//
//  ViewController.swift
//  WhatFlower
//
//  Created by Harshit ‎ on 9/22/24.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage
import ColorThiefSwift

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    var classificationResults : [VNClassificationObservation] = []
    
    @IBOutlet weak var infoLabel: UILabel!
    let wikipediaURl = "https://en.wikipedia.org/w/api.php"
    let imagePicker = UIImagePickerController()
    
    // Declare pickedImage
    var pickedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
    }
    
    func detect(image: CIImage) {
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else {
            fatalError("Cannot import model")
        }
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let classifications = request.results as? [VNClassificationObservation],
                  let topResult = classifications.first else {
                fatalError("Cannot classify image.")
            }
            
            DispatchQueue.main.async {
                self.navigationItem.title = topResult.identifier.capitalized
                self.requestInfo(flowerName: topResult.identifier)
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            imagePicker.dismiss(animated: true, completion: nil)
            
            // Set pickedImage when an image is picked
            pickedImage = image
            
            guard let convertedCIImage = CIImage(image: image) else {
                fatalError("Couldn't convert UIImage to CIImage")
            }
            detect(image: convertedCIImage)
        }
    }
    
    func requestInfo(flowerName: String) {
        // https://en.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro=&explaintext=&titles=barberton%20daisy&indexpageids&redirects=1 - This is a sample api url
        let parameters: [String: String] = [
            "format": "json",
            "action": "query",
            "prop": "extracts|pageimages",
            "exintro": "",
            "explaintext": "",
            "titles": flowerName,
            "redirects": "1",
            "pithumbsize": "500",
            "indexpageids": ""
        ]
        
        AF.request(wikipediaURl, method: .get, parameters: parameters).responseJSON { (response) in
            if case .success(let value) = response.result {
                print("Got the flower data")
                let flowerJSON: JSON = JSON(value)
                
                let pageid = flowerJSON["query"]["pageids"][0].stringValue
                let flowerDescription = flowerJSON["query"]["pages"][pageid]["extract"].stringValue
                let flowerImageURL = flowerJSON["query"]["pages"][pageid]["thumbnail"]["source"].stringValue
                
                self.infoLabel.text = flowerDescription
                
                self.imageView.sd_setImage(with: URL(string: flowerImageURL), completed: { (image, error, cache, url) in
                    if let currentImage = self.imageView.image {
                        guard let dominantColor = ColorThief.getColor(from: currentImage) else {
                            fatalError("Can't get dominant color")
                        }
                        
                        DispatchQueue.main.async {
                            self.navigationController?.navigationBar.isTranslucent = true
                            self.navigationController?.navigationBar.barTintColor = dominantColor.makeUIColor()
                        }
                    } else {
                        // Use pickedImage as a fallback
                        self.imageView.image = self.pickedImage
                        self.infoLabel.text = "Could not get information on flower from Wikipedia."
                    }
                })
            } else if case .failure(let error) = response.result {
                print("Error: \(error)")
                self.infoLabel.text = "Connection Issues"
            }
        }
    }
    
    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        // imagePicker.sourceType = .photoLibrary
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true, completion: nil)
    }
}
