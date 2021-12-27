import Foundation
import ImageIO
import UniformTypeIdentifiers

private extension CGRect {
    func scaleToAspectFit(in rtarget: CGRect) -> CGFloat {
        // first try to match width
        let s = rtarget.width / width
        // if we scale the height to make the widths equal, does it still fit?
        if height * s <= rtarget.height {
            return s
        }
        // no, match height instead
        return rtarget.height / height
    }

    func aspectFit(in rtarget: CGRect) -> CGRect {
        let s = scaleToAspectFit(in: rtarget)
        let w = width * s
        let h = height * s
        let x = rtarget.midX - w / 2
        let y = rtarget.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

private struct RGBAImage {
    var cgContext: CGContext

    struct Color {
        let alpha: UInt8
        let red: UInt8
        let green: UInt8
        let blue: UInt8

        var gray: UInt8 {
            UInt8((Int(red) * 19595 + Int(green) * 38469 + Int(blue) * 7472) >> 16)
        }
    }

    init(cgImage: CGImage? = nil, contextSize: CGSize? = nil) {
        var ctxSize: CGSize
        if let contextSize = contextSize {
            ctxSize = contextSize
        } else if let cgImage = cgImage {
            ctxSize = CGSize(width: cgImage.width, height: cgImage.height)
        } else {
            fatalError("CGContextCreate")
        }

        let alphaInfo = CGImageAlphaInfo.premultipliedFirst
        let colorRef = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(ctxSize.width),
            height: Int(ctxSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(ctxSize.width) * 4,
            space: colorRef,
            bitmapInfo: alphaInfo.rawValue
        ) else {
            fatalError("CGContextCreate")
        }
        
        if let cgImage = cgImage {
            context.draw(
                cgImage, in:
                CGRect(
                    x: 0,
                    y: 0,
                    width: cgImage.width,
                    height: cgImage.height
                ).aspectFit(in: CGRect(origin: .zero, size: ctxSize))
            )
        }

        cgContext = context
    }

    func colorAt(coordinateX x: Int, coordinateY y: Int) -> Color {
        let pixels = UnsafeMutablePointer<Color>(cgContext.data!.assumingMemoryBound(to: Color.self))
        return pixels.advanced(by: y * cgContext.width + x).pointee
    }

    func colorAt(point: CGPoint) -> Color {
        return colorAt(coordinateX: Int(point.x), coordinateY: Int(point.y))
    }

    func fillColorAt(_ color: Color, coordinateX x: Int, coordinateY y: Int) {
        cgContext.saveGState()
        cgContext.translateBy(x: 0, y: CGFloat(cgContext.height))
        cgContext.scaleBy(x: 1.0, y: -1.0)
        cgContext.setFillColor(.init(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha) / 255
        ))
        cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
        cgContext.restoreGState()
    }

    func makeImage() -> CGImage? {
        cgContext.makeImage()
    }
}

public struct SwiftGrayscalePNGPacker {
    public static let shared = SwiftGrayscalePNGPacker()

    public enum Error: Swift.Error {
        case cgDataProvider(_ url: URL)
        case cgImageSourceCreate(_ url: URL)
        case cgImageSourceCopyProperties(_ url: URL)
        case cgImageCreate(_ url: URL)
        case cgImageDestinationCreate(_ url: URL)
        case cgContextCreateImage
        case cgImageDestinationFinalize
    }

    public func pack(
        blackImageURL: URL,
        whiteImageURL: URL,
        outputURL: URL,
        blackBrightness: CGFloat = 0.5,
        whiteBrightness: CGFloat = 1.0
    ) throws {
        guard let blackImageDataProvider = CGDataProvider(url: blackImageURL as CFURL) else {
            throw Error.cgDataProvider(blackImageURL)
        }
        guard let blackImageSource = CGImageSourceCreateWithDataProvider(blackImageDataProvider, nil) else {
            throw Error.cgImageSourceCreate(blackImageURL)
        }

        guard let whiteImageDataProvider = CGDataProvider(url: whiteImageURL as CFURL) else {
            throw Error.cgDataProvider(whiteImageURL)
        }
        guard let whiteImageSource = CGImageSourceCreateWithDataProvider(whiteImageDataProvider, nil) else {
            throw Error.cgImageSourceCreate(whiteImageURL)
        }

        guard let blackImage = CGImageSourceCreateImageAtIndex(blackImageSource, 0, nil) else {
            throw Error.cgImageCreate(blackImageURL)
        }

        guard let whiteImage = CGImageSourceCreateImageAtIndex(whiteImageSource, 0, nil) else {
            throw Error.cgImageCreate(whiteImageURL)
        }

        let width = max(blackImage.width, whiteImage.width)
        let height = max(blackImage.height, whiteImage.height)
        let size = CGSize(width: width, height: height)

        let blackRGBAImage = RGBAImage(cgImage: blackImage, contextSize: size)
        let whiteRGBAImage = RGBAImage(cgImage: whiteImage, contextSize: size)
        let newImage = RGBAImage(contextSize: CGSize(width: width, height: height))

        for pixelX in 0 ..< width {
            for pixelY in 0 ..< height {
                let isBlackPixel = (pixelX + pixelY) % 2 == 0

                let origColor = isBlackPixel
                    ? blackRGBAImage.colorAt(coordinateX: pixelX, coordinateY: pixelY)
                    : whiteRGBAImage.colorAt(coordinateX: pixelX, coordinateY: pixelY)
                let gray = min(255.0, isBlackPixel
                    ? CGFloat(origColor.gray) * blackBrightness
                    : CGFloat(origColor.gray) * whiteBrightness)
                let finalColor = isBlackPixel
                    ? RGBAImage.Color(alpha: 255 - UInt8(gray), red: 0, green: 0, blue: 0)
                    : RGBAImage.Color(alpha: UInt8(gray), red: 255, green: 255, blue: 255)
                newImage.fillColorAt(finalColor, coordinateX: pixelX, coordinateY: pixelY)
            }
        }

        guard let dest = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw Error.cgImageDestinationCreate(outputURL)
        }
        guard let destImage = newImage.makeImage() else {
            throw Error.cgContextCreateImage
        }

        CGImageDestinationAddImage(dest, destImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw Error.cgImageDestinationFinalize
        }
    }
}
