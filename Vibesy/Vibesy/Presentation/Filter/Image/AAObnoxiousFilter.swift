//
//  AAObnoxiousFilter.swift
//  AAObnoxiousFilter
//
//  Created by M. Ahsan Ali on 03/03/2019.
//

import UIKit
import CoreML

@MainActor
open class AAObnoxiousFilter: NSObject {
    
    private override init() {
        super.init()

        DispatchQueue.global(qos: .userInitiated).async {
            guard
                let url = Bundle.main.url(forResource: "nsfw", withExtension: "bin"),
                let compiledURL = try? MLModel.compileModel(at: url),
                let model = try? MLModel(contentsOf: compiledURL)
            else {
                print("Something went wrong with CoreML")
                return
            }

            let loadedModel = nsfw(model: model)

            DispatchQueue.main.async { [weak self] in
                self?._model = loadedModel
                print("NSFW model loaded")
            }
        }
    }

    public static let shared = AAObnoxiousFilter()
    
    private var _model: nsfw?
    
    open func predict(_ image: UIImage) -> Double? {
        
        // Convert UIImage to CVPixelBuffer and predicting
        guard let buffer = image.buffer(),
            let model = _model,
            let output = try? model.prediction(data: buffer) else {
            return nil // Nothing -- as image is not valid
        }

        // Grab the result from prediction
        return output.prob[1].doubleValue
    }
}
