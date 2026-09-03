#!/usr/bin/env swift

import CoreGraphics
import CoreText
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let requiredRendererID = "host-coretext-forensic"
private let devicePixelRatio = 1.5
private let lockedReferenceSHA256 =
  "5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc"
private let lockedRoleManifestSHA256 =
  "6eafbb63c29a8313df4ec9ffa6f0a2afa455b0e5c7fffd4d2d3ef85183c9f2d0"
private let retainedReferenceFile = "references/trade-light.jpg"

private enum HorizontalLayout: String {
  case leading
  case center
  case trailing
}

private enum SourceBoundaryPolicy: String {
  case directGuard
  case trailingBeforeScrollbar
  case leadingBeforeArrowJpegNoise
}

private struct CropRect {
  let left: Int
  let top: Int
  let width: Int
  let height: Int

  var json: [String: Int] {
    ["left": left, "top": top, "width": width, "height": height]
  }
}

private struct Padding {
  let left: Int
  let top: Int
  let right: Int
  let bottom: Int

  var json: [String: Int] {
    ["left": left, "top": top, "right": right, "bottom": bottom]
  }
}

private struct ReferenceEvidence {
  let sourceCrop: CropRect
  let padding: Padding
  let boundaryPolicy: SourceBoundaryPolicy

  var outputWidth: Int {
    padding.left + sourceCrop.width + padding.right
  }

  var outputHeight: Int {
    padding.top + sourceCrop.height + padding.bottom
  }
}

private struct SpecimenDefinition {
  let id: String
  let text: String
  let pointSize: Double
  let physicalWidth: Int
  let physicalHeight: Int
  let purpose: String
  let comparisonID: String
  let roleID: String?
  let physicalBaselineFromTop: Double?
  let sourceNominalWeight: Int?
  let letterSpacing: Double
  let tabularFigures: Bool
  let horizontalLayout: HorizontalLayout
  let candidateAnchorX: Double?
  let referenceEvidence: ReferenceEvidence?

  init(
    id: String,
    text: String,
    pointSize: Double,
    physicalWidth: Int,
    physicalHeight: Int,
    purpose: String = "exact-six-coverage",
    comparisonID: String? = nil,
    roleID: String? = nil,
    physicalBaselineFromTop: Double? = nil,
    sourceNominalWeight: Int? = nil,
    letterSpacing: Double = 0,
    tabularFigures: Bool = false,
    horizontalLayout: HorizontalLayout = .center,
    candidateAnchorX: Double? = nil,
    referenceEvidence: ReferenceEvidence? = nil
  ) {
    self.id = id
    self.text = text
    self.pointSize = pointSize
    self.physicalWidth = physicalWidth
    self.physicalHeight = physicalHeight
    self.purpose = purpose
    self.comparisonID = comparisonID ?? id
    self.roleID = roleID
    self.physicalBaselineFromTop = physicalBaselineFromTop
    self.sourceNominalWeight = sourceNominalWeight
    self.letterSpacing = letterSpacing
    self.tabularFigures = tabularFigures
    self.horizontalLayout = horizontalLayout
    self.candidateAnchorX = candidateAnchorX
    self.referenceEvidence = referenceEvidence
  }
}

private let specimens = [
  SpecimenDefinition(
    id: "navigation-labels",
    text: "Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt",
    pointSize: 12,
    physicalWidth: 590,
    physicalHeight: 72
  ),
  SpecimenDefinition(
    id: "account-metric-labels",
    text: "Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):",
    pointSize: 11,
    physicalWidth: 590,
    physicalHeight: 72
  ),
  SpecimenDefinition(
    id: "order-label",
    text: "XAUUSD buy 1",
    pointSize: 14,
    physicalWidth: 590,
    physicalHeight: 72
  ),
  SpecimenDefinition(
    id: "numeric-price-arrow",
    text: "4637.05 → 4640.81",
    pointSize: 26,
    physicalWidth: 590,
    physicalHeight: 96
  ),
  SpecimenDefinition(
    id: "numeric-summary-values",
    text: "376.00  -341.00  103 310.00  203.24",
    pointSize: 16,
    physicalWidth: 590,
    physicalHeight: 84
  ),
  SpecimenDefinition(
    id: "chart-history-labels",
    text: "L:  H:  M1  Orders  Deals",
    pointSize: 12,
    physicalWidth: 590,
    physicalHeight: 72
  ),
  SpecimenDefinition(
    id: "numeric-price-open",
    text: "4637.05",
    pointSize: 16,
    physicalWidth: 112,
    physicalHeight: 35,
    purpose: "role-comparison",
    roleID: "tradePositionSecondary",
    physicalBaselineFromTop: 30,
    sourceNominalWeight: 400,
    letterSpacing: 0.98,
    tabularFigures: true,
    horizontalLayout: .leading,
    candidateAnchorX: 7,
    referenceEvidence: ReferenceEvidence(
      sourceCrop: CropRect(left: 1, top: 401, width: 99, height: 35),
      padding: Padding(left: 0, top: 0, right: 13, bottom: 0),
      boundaryPolicy: .leadingBeforeArrowJpegNoise
    )
  ),
  SpecimenDefinition(
    id: "numeric-price-close",
    text: "4640.81",
    pointSize: 16,
    physicalWidth: 112,
    physicalHeight: 35,
    purpose: "role-comparison",
    roleID: "tradePositionSecondary",
    physicalBaselineFromTop: 30,
    sourceNominalWeight: 400,
    letterSpacing: 0.98,
    tabularFigures: true,
    horizontalLayout: .leading,
    candidateAnchorX: 5,
    referenceEvidence: ReferenceEvidence(
      sourceCrop: CropRect(left: 123, top: 401, width: 107, height: 35),
      padding: Padding(left: 0, top: 0, right: 5, bottom: 0),
      boundaryPolicy: .directGuard
    )
  ),
  SpecimenDefinition(
    id: "trade-profit-positive",
    text: "376.00",
    pointSize: 21,
    physicalWidth: 115,
    physicalHeight: 46,
    purpose: "role-comparison",
    roleID: "tradePositionProfit",
    physicalBaselineFromTop: 34,
    sourceNominalWeight: 550,
    letterSpacing: 0.17,
    tabularFigures: true,
    horizontalLayout: .trailing,
    candidateAnchorX: 107,
    referenceEvidence: ReferenceEvidence(
      sourceCrop: CropRect(left: 475, top: 375, width: 107, height: 46),
      padding: Padding(left: 0, top: 0, right: 8, bottom: 0),
      boundaryPolicy: .trailingBeforeScrollbar
    )
  ),
  SpecimenDefinition(
    id: "trade-profit-negative",
    text: "-341.00",
    pointSize: 21,
    physicalWidth: 136,
    physicalHeight: 42,
    purpose: "role-comparison",
    roleID: "tradePositionProfit",
    physicalBaselineFromTop: 30,
    sourceNominalWeight: 550,
    letterSpacing: 0.17,
    tabularFigures: true,
    horizontalLayout: .trailing,
    candidateAnchorX: 123,
    referenceEvidence: ReferenceEvidence(
      sourceCrop: CropRect(left: 467, top: 857, width: 115, height: 42),
      padding: Padding(left: 8, top: 0, right: 13, bottom: 0),
      boundaryPolicy: .trailingBeforeScrollbar
    )
  ),
  SpecimenDefinition(
    id: "trade-balance-value",
    text: "103 310.00",
    pointSize: 16,
    physicalWidth: 140,
    physicalHeight: 40,
    purpose: "role-comparison",
    roleID: "tradeMetricValue",
    physicalBaselineFromTop: 29,
    sourceNominalWeight: 450,
    letterSpacing: 0.2,
    tabularFigures: true,
    horizontalLayout: .trailing,
    candidateAnchorX: 134,
    referenceEvidence: ReferenceEvidence(
      sourceCrop: CropRect(left: 448, top: 156, width: 134, height: 40),
      padding: Padding(left: 0, top: 0, right: 6, bottom: 0),
      boundaryPolicy: .trailingBeforeScrollbar
    )
  ),
  SpecimenDefinition(
    id: "trade-margin-level-value",
    text: "203.24",
    pointSize: 16,
    physicalWidth: 96,
    physicalHeight: 37,
    purpose: "role-comparison",
    roleID: "tradeMetricValue",
    physicalBaselineFromTop: 23,
    sourceNominalWeight: 450,
    letterSpacing: 0.2,
    tabularFigures: true,
    horizontalLayout: .trailing,
    candidateAnchorX: 90,
    referenceEvidence: ReferenceEvidence(
      sourceCrop: CropRect(left: 492, top: 291, width: 90, height: 37),
      padding: Padding(left: 0, top: 0, right: 6, bottom: 0),
      boundaryPolicy: .trailingBeforeScrollbar
    )
  ),
]

private struct Arguments {
  let fontURL: URL
  let referenceSourceURL: URL
  let outputURL: URL
  let rendererID: String

  static func parse(_ values: [String]) throws -> Arguments {
    var font: String?
    var referenceSource: String?
    var output: String?
    var renderer: String?
    var index = 0
    while index < values.count {
      let argument = values[index]
      guard ["--font", "--reference-source", "--output", "--renderer-id"].contains(argument)
      else {
        throw ToolError.usage("Unknown argument: \(argument)")
      }
      index += 1
      guard index < values.count else {
        throw ToolError.usage("Missing value for \(argument)")
      }
      let value = values[index]
      switch argument {
      case "--font":
        font = value
      case "--reference-source":
        referenceSource = value
      case "--output":
        output = value
      case "--renderer-id":
        renderer = value
      default:
        preconditionFailure("Validated argument was not handled")
      }
      index += 1
    }
    guard let font, !font.isEmpty else {
      throw ToolError.usage("--font is required")
    }
    guard let referenceSource, !referenceSource.isEmpty else {
      throw ToolError.usage("--reference-source is required")
    }
    guard let output, !output.isEmpty else {
      throw ToolError.usage("--output is required")
    }
    guard let renderer, !renderer.isEmpty else {
      throw ToolError.usage("--renderer-id is required")
    }
    return Arguments(
      fontURL: URL(fileURLWithPath: font),
      referenceSourceURL: URL(fileURLWithPath: referenceSource),
      outputURL: URL(fileURLWithPath: output),
      rendererID: renderer
    )
  }

  static let usage = """
    Usage: xcrun swift tool/render_forensic_font_specimens.swift \\
      --font PRIVATE_TEMP_FONT_PATH --reference-source LOCKED_SOURCE_PATH \\
      --output EMPTY_OUTPUT_DIRECTORY \\
      --renderer-id host-coretext-forensic
    """
}

private enum ToolError: Error, CustomStringConvertible {
  case usage(String)
  case validation(String)
  case rendering(String)

  var description: String {
    switch self {
    case .usage(let message), .validation(let message), .rendering(let message):
      return message
    }
  }
}

private struct FontMetadata {
  let postScriptName: String
  let familyName: String
  let fullName: String
  let subfamilyName: String?
  let versionName: String?
  let unitsPerEm: UInt32
  let os2WeightClass: UInt16
  let symbolicTraits: UInt32
  let coreTextWeightTrait: Double?

  var json: [String: Any] {
    var result: [String: Any] = [
      "postScriptName": postScriptName,
      "familyName": familyName,
      "fullName": fullName,
      "unitsPerEm": unitsPerEm,
      "os2WeightClass": os2WeightClass,
      "symbolicTraits": symbolicTraits,
    ]
    if let subfamilyName {
      result["subfamilyName"] = subfamilyName
    }
    if let versionName {
      result["versionName"] = versionName
    }
    if let coreTextWeightTrait {
      result["coreTextWeightTrait"] = rounded(coreTextWeightTrait)
    }
    return result
  }
}

private struct LineMetrics {
  let advance: Double
  let ascent: Double
  let descent: Double
  let leading: Double
  let capHeight: Double
  let xHeight: Double
  let baselineFromTop: Double

  var json: [String: Any] {
    [
      "advancePx": rounded(advance),
      "ascentPx": rounded(ascent),
      "descentPx": rounded(descent),
      "leadingPx": rounded(leading),
      "capHeightPx": rounded(capHeight),
      "xHeightPx": rounded(xHeight),
      "baselinePx": rounded(baselineFromTop),
      "baselineOrigin": "top",
    ]
  }
}

private struct RenderedSpecimen {
  let definition: SpecimenDefinition
  let filename: String
  let sha256: String
  let metrics: LineMetrics
  let arrowRenderedAsVector: Bool
  let referenceFilename: String?
  let referenceSHA256: String?

  func json(fontSHA256: String, metadata: FontMetadata) -> [String: Any] {
    var result: [String: Any] = [
      "id": definition.id,
      "comparisonId": definition.comparisonID,
      "roleId": definition.roleID ?? definition.id,
      "purpose": definition.purpose,
      "crossSizeComparisonAllowed": false,
      "candidateId": metadata.postScriptName,
      "text": definition.text,
      "strings": [definition.text],
      "file": filename,
      "sha256": sha256,
      "sourceClass": definition.referenceEvidence == nil
        ? "controlledSpecimen" : "jpegCrop",
      "rendererId": requiredRendererID,
      "font": [
        "family": metadata.familyName,
        "postScriptName": metadata.postScriptName,
        "faceSha256": fontSHA256,
        "weight": metadata.os2WeightClass,
        "selectable": false,
      ],
      "pointSize": definition.pointSize,
      "physicalFontSize": definition.pointSize * devicePixelRatio,
      "devicePixelRatio": devicePixelRatio,
      "textScale": 1.0,
      "locale": "vi-VN",
      "textDirection": "ltr",
      "width": definition.physicalWidth,
      "height": definition.physicalHeight,
      "physicalWidth": definition.physicalWidth,
      "physicalHeight": definition.physicalHeight,
      "candidateBaseline": rounded(metrics.baselineFromTop),
      "baselineOrigin": "top",
      "letterSpacing": definition.letterSpacing,
      "tabularFigures": definition.tabularFigures,
      "fontFeatures": definition.tabularFigures ? ["tnum"] : [],
      "horizontalLayout": definition.horizontalLayout.rawValue,
      "candidateAnchorX": rounded(
        definition.candidateAnchorX ?? Double(definition.physicalWidth) / 2
      ),
      "vectorPolicy": arrowRenderedAsVector
        ? "keyed-deterministic-vector-shape-no-font-fallback" : "none",
      "scored": definition.referenceEvidence != nil,
      "crossRendererComparable": definition.referenceEvidence != nil,
      "grayscaleOnly": true,
      "parameterEvidence": [
        "provenance": "currentAppHypothesis",
        "lockEligible": false,
        "scope": "pointSize-letterSpacing-features-sourceNominalWeight",
      ],
      "opaque": true,
      "arrowRenderedAsVector": arrowRenderedAsVector,
      "metrics": metrics.json,
    ]
    if let sourceNominalWeight = definition.sourceNominalWeight {
      result["sourceNominalWeight"] = sourceNominalWeight
    }
    if let evidence = definition.referenceEvidence,
       let referenceFilename,
       let referenceSHA256,
       let baseline = definition.physicalBaselineFromTop,
       let anchor = definition.candidateAnchorX
    {
      let fullCrop = CropRect(
        left: 0,
        top: 0,
        width: definition.physicalWidth,
        height: definition.physicalHeight
      )
      var transform: [String: Any] = [
        "kind": "whitePaddingNoResample",
        "boundaryPolicy": evidence.boundaryPolicy.rawValue,
        "sourceFile": retainedReferenceFile,
        "sourceSha256": lockedReferenceSHA256,
        "sourceCrop": evidence.sourceCrop.json,
        "padding": evidence.padding.json,
      ]
      if evidence.boundaryPolicy == .trailingBeforeScrollbar {
        transform["sourceRightExclusiveBoundaryX"] = 582
        transform["coordinateSpace"] = "sourceImagePhysicalPixels"
        transform["exclusive"] = true
      }
      if evidence.boundaryPolicy == .leadingBeforeArrowJpegNoise {
        transform["sourceRightExclusiveBoundaryX"] = 100
        transform["coordinateSpace"] = "sourceImagePhysicalPixels"
        transform["exclusive"] = true
        transform["lastStrongInkX"] = 90
        transform["blankGuardStartX"] = 91
        transform["blankGuardWidth"] = 9
        transform["excludedNeighborStartX"] = 100
        transform["excludedNeighborKind"] = "vectorArrow"
      }
      result["referenceFile"] = referenceFilename
      result["referenceSha256"] = referenceSHA256
      result["referenceCrop"] = fullCrop.json
      result["candidateCrop"] = fullCrop.json
      result["sourceFile"] = retainedReferenceFile
      result["sourceSha256"] = lockedReferenceSHA256
      result["sourceCrop"] = evidence.sourceCrop.json
      result["referenceTransform"] = transform
      result["annotations"] = [
        "baselineOrigin": "top",
        "baseline": [
          "referenceY": Int(baseline),
          "candidateY": Int(baseline),
        ],
        "landmarks": [
          [
            "id": "horizontal-anchor",
            "reference": ["x": Int(anchor), "y": Int(baseline)],
            "candidate": ["x": Int(anchor), "y": Int(baseline)],
          ]
        ],
      ]
    }
    return result
  }
}

private func execute() throws {
  let arguments = try Arguments.parse(Array(CommandLine.arguments.dropFirst()))
  guard arguments.rendererID == requiredRendererID else {
    throw ToolError.validation(
      "Renderer id must be exactly \(requiredRendererID); found \(arguments.rendererID)."
    )
  }

  let fileManager = FileManager.default
  let fontURL = arguments.fontURL.standardizedFileURL.resolvingSymlinksInPath()
  let temporaryRoot = fileManager.temporaryDirectory.standardizedFileURL
    .resolvingSymlinksInPath()
  let sharedTemporaryRoot = URL(fileURLWithPath: "/tmp").standardizedFileURL
    .resolvingSymlinksInPath()
  guard isDescendant(fontURL, of: temporaryRoot)
          || isDescendant(fontURL, of: sharedTemporaryRoot)
  else {
    throw ToolError.validation(
      "The requested external font must be supplied from a private temporary path."
    )
  }
  var isDirectory: ObjCBool = false
  guard fileManager.fileExists(atPath: fontURL.path, isDirectory: &isDirectory),
        !isDirectory.boolValue
  else {
    throw ToolError.validation("The requested external font is not a regular file.")
  }

  let outputURL = arguments.outputURL.standardizedFileURL
  var outputIsDirectory: ObjCBool = false
  guard fileManager.fileExists(atPath: outputURL.path, isDirectory: &outputIsDirectory),
        outputIsDirectory.boolValue
  else {
    throw ToolError.validation("The output directory must already exist and be empty.")
  }
  let existing = try fileManager.contentsOfDirectory(
    at: outputURL,
    includingPropertiesForKeys: nil,
    options: []
  )
  guard existing.isEmpty else {
    throw ToolError.validation(
      "The output directory already contains files; forensic outputs are immutable."
    )
  }

  let referenceSourceURL = arguments.referenceSourceURL.standardizedFileURL
    .resolvingSymlinksInPath()
  var referenceIsDirectory: ObjCBool = false
  guard fileManager.fileExists(
    atPath: referenceSourceURL.path,
    isDirectory: &referenceIsDirectory
  ), !referenceIsDirectory.boolValue
  else {
    throw ToolError.validation("The locked reference source is not a regular file.")
  }
  let referenceSourceData = try Data(contentsOf: referenceSourceURL, options: [.mappedIfSafe])
  let referenceSourceSHA256 = SHA256.hash(data: referenceSourceData).hexString
  guard referenceSourceSHA256 == lockedReferenceSHA256 else {
    throw ToolError.validation(
      "The reference source SHA-256 must equal \(lockedReferenceSHA256); found \(referenceSourceSHA256)."
    )
  }
  guard let referenceImageSource = CGImageSourceCreateWithData(
    referenceSourceData as CFData,
    nil
  ), let referenceSourceImage = CGImageSourceCreateImageAtIndex(
    referenceImageSource,
    0,
    nil
  ), referenceSourceImage.width == 590, referenceSourceImage.height == 1280
  else {
    throw ToolError.validation(
      "The locked reference source must decode at exactly 590x1280 pixels."
    )
  }

  let fontData = try Data(contentsOf: fontURL, options: [.mappedIfSafe])
  let fontSHA256 = SHA256.hash(data: fontData).hexString
  let os2WeightClass = try readOS2WeightClass(fontData)
  guard let provider = CGDataProvider(data: fontData as CFData),
        let graphicsFont = CGFont(provider)
  else {
    throw ToolError.validation("The requested external file is not a readable SFNT font.")
  }
  let metadataFont = CTFontCreateWithGraphicsFont(graphicsFont, 12, nil, nil)
  let metadata = fontMetadata(metadataFont, os2WeightClass: os2WeightClass)

  let referencesURL = outputURL.appendingPathComponent("references", isDirectory: true)
  try fileManager.createDirectory(at: referencesURL, withIntermediateDirectories: false)
  let retainedReferenceURL = outputURL.appendingPathComponent(retainedReferenceFile)
  try referenceSourceData.write(to: retainedReferenceURL, options: [.atomic])
  guard SHA256.hash(data: try Data(contentsOf: retainedReferenceURL)).hexString
          == lockedReferenceSHA256
  else {
    throw ToolError.rendering("Retained raw reference SHA-256 verification failed.")
  }

  var rendered: [RenderedSpecimen] = []
  for definition in specimens {
    var referenceFilename: String?
    var referenceSHA256: String?
    if let evidence = definition.referenceEvidence {
      guard evidence.outputWidth == definition.physicalWidth,
            evidence.outputHeight == definition.physicalHeight
      else {
        throw ToolError.validation(
          "Reference transform dimensions disagree for \(definition.id)."
        )
      }
      let reference = try renderReference(
        definition,
        evidence: evidence,
        sourceImage: referenceSourceImage,
        outputURL: outputURL
      )
      referenceFilename = reference.filename
      referenceSHA256 = reference.sha256
    }
    rendered.append(
      try render(
        definition,
        graphicsFont: graphicsFont,
        outputURL: outputURL,
        referenceFilename: referenceFilename,
        referenceSHA256: referenceSHA256
      )
    )
  }

  let manifest: [String: Any] = [
    "schemaVersion": 1,
    "rendererId": requiredRendererID,
    "diagnosticOnly": true,
    "claimLimit": "Host CoreText evidence is diagnostic only and cannot select or claim a primary iOS winner.",
    "referenceRoleManifestSha256": lockedRoleManifestSHA256,
    "parameterPolicy": [
      "provenance": "currentAppHypothesis",
      "lockEligible": false,
      "requiresRasterScoreForWinner": true,
    ],
    "fontSha256": fontSHA256,
    "font": metadata.json,
    "devicePixelRatio": devicePixelRatio,
    "textScale": 1.0,
    "background": "#FFFFFF",
    "foreground": "#000000",
    "opaque": true,
    "grayscaleOnly": true,
    "arrowPolicy": [
      "specimen": "4637.05 → 4640.81",
      "delimiter": "→",
      "owner": "deterministic-vector-shape",
      "fontFallbackAllowed": false,
    ],
    "specimens": rendered.map { $0.json(fontSHA256: fontSHA256, metadata: metadata) },
    "retainedFontBytes": false,
  ]
  let manifestData = try JSONSerialization.data(
    withJSONObject: manifest,
    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  )
  var terminatedManifest = manifestData
  terminatedManifest.append(0x0A)
  let manifestURL = outputURL.appendingPathComponent("manifest.json")
  guard !fileManager.fileExists(atPath: manifestURL.path) else {
    throw ToolError.validation("Refusing to overwrite manifest.json.")
  }
  try terminatedManifest.write(to: manifestURL, options: [.atomic])
  print("Rendered \(rendered.count) deterministic diagnostic specimens.")
  print("Font SHA-256: \(fontSHA256)")
}

private func renderReference(
  _ definition: SpecimenDefinition,
  evidence: ReferenceEvidence,
  sourceImage: CGImage,
  outputURL: URL
) throws -> (filename: String, sha256: String) {
  let crop = evidence.sourceCrop
  guard crop.left >= 0,
        crop.top >= 0,
        crop.width > 0,
        crop.height > 0,
        crop.left + crop.width <= sourceImage.width,
        crop.top + crop.height <= sourceImage.height
  else {
    throw ToolError.validation(
      "Reference source crop is out of bounds for \(definition.id)."
    )
  }
  guard let croppedImage = sourceImage.cropping(
    to: CGRect(x: crop.left, y: crop.top, width: crop.width, height: crop.height)
  ) else {
    throw ToolError.rendering(
      "Unable to crop the reference source for \(definition.id)."
    )
  }
  let width = evidence.outputWidth
  let height = evidence.outputHeight
  guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * 4,
          space: colorSpace,
          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.noneSkipLast.rawValue
        )
  else {
    throw ToolError.rendering(
      "Unable to create reference bitmap for \(definition.id)."
    )
  }
  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  context.interpolationQuality = .none
  context.setShouldAntialias(false)
  context.draw(
    croppedImage,
    in: CGRect(
      x: evidence.padding.left,
      y: evidence.padding.bottom,
      width: crop.width,
      height: crop.height
    )
  )
  guard let renderedImage = context.makeImage() else {
    throw ToolError.rendering(
      "Unable to finalize reference image for \(definition.id)."
    )
  }
  let filename = "references/\(definition.id).png"
  let destinationURL = outputURL.appendingPathComponent(filename)
  guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
    throw ToolError.validation("Refusing to overwrite \(filename).")
  }
  try writePNG(renderedImage, to: destinationURL, label: definition.id)
  let pngData = try Data(contentsOf: destinationURL)
  return (filename, SHA256.hash(data: pngData).hexString)
}

private func render(
  _ definition: SpecimenDefinition,
  graphicsFont: CGFont,
  outputURL: URL,
  referenceFilename: String?,
  referenceSHA256: String?
) throws -> RenderedSpecimen {
  let width = definition.physicalWidth
  let height = definition.physicalHeight
  let bytesPerRow = width * 4
  guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: bytesPerRow,
          space: colorSpace,
          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.noneSkipLast.rawValue
        )
  else {
    throw ToolError.rendering("Unable to create the deterministic bitmap context.")
  }
  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)
  context.setAllowsFontSmoothing(false)
  context.setShouldSmoothFonts(false)
  context.setAllowsFontSubpixelPositioning(false)
  context.setShouldSubpixelPositionFonts(false)
  context.setAllowsFontSubpixelQuantization(false)
  context.setShouldSubpixelQuantizeFonts(false)
  context.textMatrix = .identity

  let physicalFontSize = definition.pointSize * devicePixelRatio
  let baseFont = CTFontCreateWithGraphicsFont(
    graphicsFont,
    CGFloat(physicalFontSize),
    nil,
    nil
  )
  let font: CTFont
  if definition.tabularFigures {
    let descriptor = CTFontDescriptorCreateCopyWithFeature(
      CTFontCopyFontDescriptor(baseFont),
      NSNumber(value: kNumberSpacingType),
      NSNumber(value: kMonospacedNumbersSelector)
    )
    font = CTFontCreateCopyWithAttributes(baseFont, 0, nil, descriptor)
  } else {
    font = baseFont
  }
  let baselineFromTop = definition.physicalBaselineFromTop
    ?? ((Double(height) - Double(CTFontGetAscent(font) + CTFontGetDescent(font))) / 2
      + Double(CTFontGetAscent(font))).rounded()
  let contextBaselineY = Double(height) - baselineFromTop
  let metrics: LineMetrics
  let arrowRenderedAsVector: Bool
  if definition.text.contains("→") {
    metrics = try drawArrowSpecimen(
      definition.text,
      font: font,
      context: context,
      contextBaselineY: contextBaselineY,
      baselineFromTop: baselineFromTop,
      canvasWidth: Double(width),
      horizontalLayout: definition.horizontalLayout,
      candidateAnchorX: definition.candidateAnchorX,
      physicalLetterSpacing: definition.letterSpacing * devicePixelRatio
    )
    arrowRenderedAsVector = true
  } else {
    metrics = try drawFontOnlySpecimen(
      definition.text,
      font: font,
      context: context,
      contextBaselineY: contextBaselineY,
      baselineFromTop: baselineFromTop,
      canvasWidth: Double(width),
      horizontalLayout: definition.horizontalLayout,
      candidateAnchorX: definition.candidateAnchorX,
      physicalLetterSpacing: definition.letterSpacing * devicePixelRatio
    )
    arrowRenderedAsVector = false
  }

  guard let renderedImage = context.makeImage() else {
    throw ToolError.rendering("Unable to finalize specimen \(definition.id).")
  }
  let filename = "\(definition.id).png"
  let destinationURL = outputURL.appendingPathComponent(filename)
  guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
    throw ToolError.validation("Refusing to overwrite \(filename).")
  }
  try writePNG(renderedImage, to: destinationURL, label: definition.id)
  let pngData = try Data(contentsOf: destinationURL)
  return RenderedSpecimen(
    definition: definition,
    filename: filename,
    sha256: SHA256.hash(data: pngData).hexString,
    metrics: metrics,
    arrowRenderedAsVector: arrowRenderedAsVector,
    referenceFilename: referenceFilename,
    referenceSHA256: referenceSHA256
  )
}

private func writePNG(_ image: CGImage, to destinationURL: URL, label: String) throws {
  guard let destination = CGImageDestinationCreateWithURL(
    destinationURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
  ) else {
    throw ToolError.rendering("Unable to create PNG destination for \(label).")
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw ToolError.rendering("Unable to write PNG for \(label).")
  }
}

private func drawFontOnlySpecimen(
  _ text: String,
  font: CTFont,
  context: CGContext,
  contextBaselineY: Double,
  baselineFromTop: Double,
  canvasWidth: Double,
  horizontalLayout: HorizontalLayout,
  candidateAnchorX: Double?,
  physicalLetterSpacing: Double
) throws -> LineMetrics {
  try requireGlyphs(text, in: font)
  let line = makeLine(
    text,
    font: font,
    physicalLetterSpacing: physicalLetterSpacing
  )
  var ascent: CGFloat = 0
  var descent: CGFloat = 0
  var leading: CGFloat = 0
  let advance = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
  let originX = horizontalOrigin(
    advance: advance,
    canvasWidth: canvasWidth,
    layout: horizontalLayout,
    anchorX: candidateAnchorX
  )
  context.textPosition = CGPoint(x: originX, y: contextBaselineY)
  CTLineDraw(line, context)
  return LineMetrics(
    advance: advance,
    ascent: ascent,
    descent: descent,
    leading: leading,
    capHeight: Double(CTFontGetCapHeight(font)),
    xHeight: Double(CTFontGetXHeight(font)),
    baselineFromTop: baselineFromTop
  )
}

private func drawArrowSpecimen(
  _ text: String,
  font: CTFont,
  context: CGContext,
  contextBaselineY: Double,
  baselineFromTop: Double,
  canvasWidth: Double,
  horizontalLayout: HorizontalLayout,
  candidateAnchorX: Double?,
  physicalLetterSpacing: Double
) throws -> LineMetrics {
  let components = text.components(separatedBy: "→")
  guard components.count == 2 else {
    throw ToolError.validation(
      "The arrow specimen must contain exactly one U+2192 delimiter."
    )
  }
  let leftText = components[0]
  let rightText = components[1]
  try requireGlyphs(leftText, in: font)
  try requireGlyphs(rightText, in: font)
  let leftLine = makeLine(
    leftText,
    font: font,
    physicalLetterSpacing: physicalLetterSpacing
  )
  let rightLine = makeLine(
    rightText,
    font: font,
    physicalLetterSpacing: physicalLetterSpacing
  )
  var leftAscent: CGFloat = 0
  var leftDescent: CGFloat = 0
  var leftLeading: CGFloat = 0
  var rightAscent: CGFloat = 0
  var rightDescent: CGFloat = 0
  var rightLeading: CGFloat = 0
  let leftAdvance = CTLineGetTypographicBounds(
    leftLine,
    &leftAscent,
    &leftDescent,
    &leftLeading
  )
  let rightAdvance = CTLineGetTypographicBounds(
    rightLine,
    &rightAscent,
    &rightDescent,
    &rightLeading
  )
  let arrowWidth = Double(CTFontGetSize(font)) * 0.95
  let totalAdvance = leftAdvance + arrowWidth + rightAdvance
  let originX = horizontalOrigin(
    advance: totalAdvance,
    canvasWidth: canvasWidth,
    layout: horizontalLayout,
    anchorX: candidateAnchorX
  )
  context.textPosition = CGPoint(x: originX, y: contextBaselineY)
  CTLineDraw(leftLine, context)

  let arrowStart = originX + leftAdvance + arrowWidth * 0.15
  let arrowEnd = originX + leftAdvance + arrowWidth * 0.85
  let arrowCenterY = contextBaselineY + Double(CTFontGetXHeight(font)) * 0.48
  let head = arrowWidth * 0.22
  context.setStrokeColor(CGColor(gray: 0, alpha: 1))
  context.setLineWidth(max(1, Double(CTFontGetSize(font)) * 0.055))
  context.setLineCap(.square)
  context.setLineJoin(.miter)
  context.beginPath()
  context.move(to: CGPoint(x: arrowStart, y: arrowCenterY))
  context.addLine(to: CGPoint(x: arrowEnd, y: arrowCenterY))
  context.move(to: CGPoint(x: arrowEnd, y: arrowCenterY))
  context.addLine(to: CGPoint(x: arrowEnd - head, y: arrowCenterY + head))
  context.move(to: CGPoint(x: arrowEnd, y: arrowCenterY))
  context.addLine(to: CGPoint(x: arrowEnd - head, y: arrowCenterY - head))
  context.strokePath()

  context.textPosition = CGPoint(
    x: originX + leftAdvance + arrowWidth,
    y: contextBaselineY
  )
  CTLineDraw(rightLine, context)
  return LineMetrics(
    advance: totalAdvance,
    ascent: max(leftAscent, rightAscent),
    descent: max(leftDescent, rightDescent),
    leading: max(leftLeading, rightLeading),
    capHeight: Double(CTFontGetCapHeight(font)),
    xHeight: Double(CTFontGetXHeight(font)),
    baselineFromTop: baselineFromTop
  )
}

private func makeLine(
  _ text: String,
  font: CTFont,
  physicalLetterSpacing: Double
) -> CTLine {
  let attributes: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String):
      CGColor(gray: 0, alpha: 1),
    NSAttributedString.Key(kCTLigatureAttributeName as String): 0,
    NSAttributedString.Key(kCTKernAttributeName as String): physicalLetterSpacing,
  ]
  return CTLineCreateWithAttributedString(
    NSAttributedString(string: text, attributes: attributes)
  )
}

private func horizontalOrigin(
  advance: Double,
  canvasWidth: Double,
  layout: HorizontalLayout,
  anchorX: Double?
) -> Double {
  let anchor = anchorX ?? canvasWidth / 2
  return switch layout {
  case .leading: anchor
  case .center: anchor - advance / 2
  case .trailing: anchor - advance
  }
}

private func requireGlyphs(_ text: String, in font: CTFont) throws {
  let characters = Array(text.utf16)
  var glyphs = [CGGlyph](repeating: 0, count: characters.count)
  let covered = characters.withUnsafeBufferPointer { characterBuffer in
    glyphs.withUnsafeMutableBufferPointer { glyphBuffer in
      CTFontGetGlyphsForCharacters(
        font,
        characterBuffer.baseAddress!,
        glyphBuffer.baseAddress!,
        characters.count
      )
    }
  }
  guard covered, !glyphs.contains(0) else {
    throw ToolError.validation(
      "The requested external face does not cover every code point in \"\(text)\"; font fallback is forbidden."
    )
  }
}

private func fontMetadata(
  _ font: CTFont,
  os2WeightClass: UInt16
) -> FontMetadata {
  let traits = CTFontCopyTraits(font) as NSDictionary
  let weight = traits[kCTFontWeightTrait] as? NSNumber
  return FontMetadata(
    postScriptName: CTFontCopyPostScriptName(font) as String,
    familyName: CTFontCopyFamilyName(font) as String,
    fullName: CTFontCopyFullName(font) as String,
    subfamilyName: CTFontCopyName(font, kCTFontSubFamilyNameKey) as String?,
    versionName: CTFontCopyName(font, kCTFontVersionNameKey) as String?,
    unitsPerEm: CTFontGetUnitsPerEm(font),
    os2WeightClass: os2WeightClass,
    symbolicTraits: CTFontGetSymbolicTraits(font).rawValue,
    coreTextWeightTrait: weight?.doubleValue
  )
}

private func readOS2WeightClass(_ data: Data) throws -> UInt16 {
  guard data.count >= 12 else {
    throw ToolError.validation("SFNT header is truncated.")
  }
  let tableCount = Int(try readUInt16(data, at: 4))
  let directoryEnd = 12 + tableCount * 16
  guard directoryEnd <= data.count else {
    throw ToolError.validation("SFNT table directory is truncated.")
  }
  for index in 0..<tableCount {
    let record = 12 + index * 16
    let tag = data[record..<(record + 4)]
    if Array(tag) != Array("OS/2".utf8) {
      continue
    }
    let offset = Int(try readUInt32(data, at: record + 8))
    let length = Int(try readUInt32(data, at: record + 12))
    guard length >= 6, offset >= 0, offset <= data.count - length else {
      throw ToolError.validation("OS/2 table is truncated.")
    }
    return try readUInt16(data, at: offset + 4)
  }
  throw ToolError.validation("The requested SFNT has no OS/2 weight metadata.")
}

private func readUInt16(_ data: Data, at offset: Int) throws -> UInt16 {
  guard offset >= 0, offset <= data.count - 2 else {
    throw ToolError.validation("SFNT UInt16 read is out of bounds.")
  }
  return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
}

private func readUInt32(_ data: Data, at offset: Int) throws -> UInt32 {
  guard offset >= 0, offset <= data.count - 4 else {
    throw ToolError.validation("SFNT UInt32 read is out of bounds.")
  }
  return UInt32(data[offset]) << 24
    | UInt32(data[offset + 1]) << 16
    | UInt32(data[offset + 2]) << 8
    | UInt32(data[offset + 3])
}

private func isDescendant(_ child: URL, of parent: URL) -> Bool {
  let parentPath = parent.path.hasSuffix("/") ? parent.path : parent.path + "/"
  return child.path.hasPrefix(parentPath)
}

private func rounded(_ value: Double) -> Double {
  (value * 1_000_000).rounded() / 1_000_000
}

extension Digest {
  fileprivate var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}

do {
  try execute()
} catch let error as ToolError {
  fputs("\(error.description)\n", stderr)
  if case .usage = error {
    fputs("\(Arguments.usage)\n", stderr)
  }
  exit(1)
} catch {
  fputs("Unexpected forensic-renderer failure: \(error)\n", stderr)
  exit(1)
}
