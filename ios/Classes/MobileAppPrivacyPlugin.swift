import Flutter
import UIKit
import SVGKit

public class MobileAppPrivacyPlugin: NSObject, FlutterPlugin {
    private var overlayView: UIView?
    private static let imageCache = NSCache<NSString, UIImage>()
    private var registrar: FlutterPluginRegistrar?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "mobile_app_privacy", binaryMessenger: registrar.messenger())
        let instance = MobileAppPrivacyPlugin()
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "enableOverlay":
            let args = call.arguments as? [String: Any]
            let colorValue = args?["color"] as? Int ?? 0xFF00FF00
            let imageInfo = args?["iconAsset"] as? [String: Any]
            let color = uiColor(fromArgb: UInt(colorValue))
            
            guard let registrar = self.registrar else {
                result(FlutterError(code: "UNAVAILABLE", message: "Registrar not available", details: nil))
                return
            }
            
            enableOverlay(color: color, imageInfo: imageInfo, registrar: registrar)
            result(nil)
            
        case "disableOverlay":
            disableOverlay()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Overlay Handling with Optional Custom Image
    
    private func enableOverlay(color: UIColor, imageInfo: [String:Any]?, registrar: FlutterPluginRegistrar) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first else { return }
        
        // Prevent multiple overlays
        if overlayView != nil { return }
        
        let container = UIView(frame: window.bounds)
        container.isUserInteractionEnabled = true
        container.backgroundColor = color
        container.alpha = 0.0  // start invisible
        
        // If an image path is provided, load the image and display it
        // If an image path is provided, load the image and display it
        if let imageInfo = imageInfo {
            // Safely extract and cast values for imagePath, width, and height
            if let imagePath = imageInfo["assetPath"] as? String,
               let widthValue = imageInfo["width"],
               let heightValue = imageInfo["height"] {
                
                // Try to cast width and height to CGFloat
                let imageWidth = widthValue as? CGFloat ?? CGFloat(exactly: widthValue as? Int ?? 0) ?? CGFloat(exactly: widthValue as? Double ?? 0) ?? 0
                let imageHeight = heightValue as? CGFloat ?? CGFloat(exactly: heightValue as? Int ?? 0) ?? CGFloat(exactly: heightValue as? Double ?? 0) ?? 0
                
                print("Loading image for path: \(imagePath) with width: \(imageWidth) and height: \(imageHeight)")
                
                // Check if the image is already cached
                if let cachedImage = MobileAppPrivacyPlugin.imageCache.object(forKey: imagePath as NSString) {
                    print("Using cached image")
                    addImageToContainer(image: cachedImage, container: container, width: imageWidth, height: imageHeight)
                } else {
                    // Load the image from Flutter assets
                    if let image = loadFlutterAsset(imagePath, registrar: registrar) {
                        // Cache the image for later use
                        MobileAppPrivacyPlugin.imageCache.setObject(image, forKey: imagePath as NSString)
                        print("Image successfully loaded and cached")
                        addImageToContainer(image: image, container: container, width: imageWidth, height: imageHeight)
                    } else {
                        print("Failed to load image from asset")
                    }
                }
            } else {
                print("Invalid imageInfo data: missing or invalid 'iconAsset', 'width', or 'height'.")
            }
        }

        
        window.addSubview(container)
        overlayView = container
        
        // Animate the container to fade in
        UIView.animate(withDuration: 0.25, animations: {
            container.alpha = 1.0
        })
    }
    
    private func disableOverlay() {
        guard let overlay = overlayView else { return }
        
        UIView.animate(withDuration: 0.25, animations: {
            overlay.alpha = 0.0
        }, completion: { _ in
            overlay.removeFromSuperview()
            self.overlayView = nil
        })
    }
    
    // MARK: - Load Flutter Asset
    
    private func loadFlutterAsset(_ assetPath: String, registrar: FlutterPluginRegistrar) -> UIImage? {
        let assetManager = registrar.lookupKey(forAsset: assetPath)
        
        // Fetch the asset data from the Flutter asset bundle
        guard let assetPathInBundle = Bundle.main.path(forResource: assetManager, ofType: nil) else {
            print("Asset path not found in Flutter bundle: \(assetPath)")
            return nil
        }
        
        // Load the asset data
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: assetPathInBundle)) else {
            print("Failed to load asset data from path: \(assetPathInBundle)")
            return nil
        }
        
        // Process the image data (either SVG or PNG)
        if let image = processImageData(data) {
            return image
        } else {
            print("Failed to process image from data")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func uiColor(fromArgb argb: UInt) -> UIColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    // Process image data and return UIImage
    private func processImageData(_ data: Data) -> UIImage? {
        if let svgImage = SVGKImage(data: data) {
            return svgImage.uiImage
        } else {
            return UIImage(data: data)
        }
    }
    
    // Add image to container with specific width and height
    private func addImageToContainer(image: UIImage, container: UIView, width: CGFloat, height: CGFloat) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        // Add constraints to center the imageView and use provided width and height
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: width),
            imageView.heightAnchor.constraint(equalToConstant: height)
        ])
        
        // Ensure layout is updated after constraints are added
        container.layoutIfNeeded()
    }
}
