
// MARK: AdobeIllustratorESCM
@objc public enum AdobeIllustratorESCM : AEKeyword {
    case desktop = 0x65303032
    case fullScreen = 0x65303033
    case multiwindow = 0x65303031
}

// MARK: AdobeIllustratorECCS
@objc public enum AdobeIllustratorECCS : AEKeyword {
    case cmyk = 0x6543794d
    case rgb = 0x6552624d
}

// MARK: AdobeIllustratorEDPT
@objc public enum AdobeIllustratorEDPT : AEKeyword {
    case basicCMYKDocument = 0x70435052
    case basicRGBDocument = 0x70525052
    case mobileDocumentPreset = 0x704d5052
    case printDocumentPreset = 0x70505052
    case videoDocumentPreset = 0x70565052
    case webDocumentPreset = 0x70575052
}

// MARK: AdobeIllustratorEDCR
@objc public enum AdobeIllustratorEDCR : AEKeyword {
    case highResolution = 0x70485252
    case mediumResolution = 0x704d5252
    case screenResolution = 0x70535252
}

// MARK: AdobeIllustratorEDGR
@objc public enum AdobeIllustratorEDGR : AEKeyword {
    case blueTransparencyGrids = 0x70544742
    case darkColorTransparencyGrids = 0x70544744
    case greenTransparencyGrids = 0x70544747
    case hideTransparencyGrids = 0x7054474e
    case lightColorTransparencyGrids = 0x7054474c
    case mediumColorTransparencyGrids = 0x7054474d
    case orangeTransparencyGrids = 0x7054474f
    case purpleTransparencyGrids = 0x70544750
    case redColorTransparencyGrids = 0x70544752
}

// MARK: AdobeIllustratorEDPM
@objc public enum AdobeIllustratorEDPM : AEKeyword {
    case defaultPreview = 0x7044504d
    case overprintPreview = 0x704f5050
    case pixelPreview = 0x7050504d
}

// MARK: AdobeIllustratorEDAL
@objc public enum AdobeIllustratorEDAL : AEKeyword {
    case column = 0x70436f6c
    case gridByColumn = 0x70477243
    case gridByRow = 0x70477252
    case rlGridByCol = 0x70524743
    case rlGridByRow = 0x70524752
    case rlRow = 0x70525277
    case row = 0x70526f77
}

// MARK: AdobeIllustratorECLS
@objc public enum AdobeIllustratorECLS : AEKeyword {
    case cmyk = 0x6543794d
    case deviceN = 0x6530444e
    case gray = 0x6530474d
    case indexed = 0x65304944
    case lab = 0x65304c62
    case rgb = 0x6552624d
    case separation = 0x65305350
}

// MARK: AdobeIllustratorESTc
@objc public enum AdobeIllustratorESTc : AEKeyword {
    case butted = 0x65303230
    case projecting = 0x65303232
    case rounded = 0x65303231
}

// MARK: AdobeIllustratorESTj
@objc public enum AdobeIllustratorESTj : AEKeyword {
    case beveled = 0x65303331
    case mitered = 0x65303330
    case rounded = 0x65303231
}

// MARK: AdobeIllustratorESGs
@objc public enum AdobeIllustratorESGs : AEKeyword {
    case anchorSelected = 0x65303530
    case leftRightSelected = 0x65303533
    case leftSelected = 0x65303531
    case none = 0x67653031
    case rightSelected = 0x65303532
}

// MARK: AdobeIllustratorEPTy
@objc public enum AdobeIllustratorEPTy : AEKeyword {
    case corner = 0x65303537
    case smooth = 0x65303536
}

// MARK: AdobeIllustratorETXt
@objc public enum AdobeIllustratorETXt : AEKeyword {
    case areaText = 0x65303632
    case pathText = 0x65303631
    case pointText = 0x65303630
}

// MARK: AdobeIllustratorETAa
@objc public enum AdobeIllustratorETAa : AEKeyword {
    case crisp = 0x65303634
    case none = 0x67653031
    case sharp = 0x65303633
    case strong = 0x65303635
}

// MARK: AdobeIllustratorEGDt
@objc public enum AdobeIllustratorEGDt : AEKeyword {
    case linear = 0x65303430
    case radial = 0x65303431
}

// MARK: AdobeIllustratorETXo
@objc public enum AdobeIllustratorETXo : AEKeyword {
    case horizontal = 0x65303730
    case vertical = 0x65303731
}

// MARK: AdobeIllustratorECRs
@objc public enum AdobeIllustratorECRs : AEKeyword {
    case japaneseStyle = 0x65303831
    case standard = 0x65303830
}

// MARK: AdobeIllustratorERLt
@objc public enum AdobeIllustratorERLt : AEKeyword {
    case dataFromFile = 0x65303931
    case modifiedData = 0x65303932
    case noData = 0x65303930
}

// MARK: AdobeIllustratorETBa
@objc public enum AdobeIllustratorETBa : AEKeyword {
    case center = 0x65313232
    case decimal = 0x65313234
    case left = 0x65313231
    case right = 0x65313233
}

// MARK: AdobeIllustratorEPRa
@objc public enum AdobeIllustratorEPRa : AEKeyword {
    case center = 0x65313232
    case fullJustify = 0x65313238
    case fullJustifyLastLineCenter = 0x65313237
    case fullJustifyLastLineLeft = 0x65313235
    case fullJustifyLastLineRight = 0x65313236
    case left = 0x65313231
    case right = 0x65313233
}

// MARK: AdobeIllustratorETRt
@objc public enum AdobeIllustratorETRt : AEKeyword {
    case bottom = 0x65313737
    case bottomLeft = 0x65313734
    case bottomRight = 0x65313741
    case center = 0x65313232
    case documentOrigin = 0x65313731
    case left = 0x65313231
    case right = 0x65313233
    case top = 0x65313735
    case topLeft = 0x65313732
    case topRight = 0x65313738
}

// MARK: AdobeIllustratorEDCc
@objc public enum AdobeIllustratorEDCc : AEKeyword {
    case illustrator10 = 0x65323039
    case illustrator11 = 0x65323061
    case illustrator12 = 0x65323062
    case illustrator13 = 0x65323063
    case illustrator14 = 0x65323064
    case illustrator15 = 0x65323065
    case illustrator16 = 0x65323066
    case illustrator17 = 0x65323067
    case illustrator24 = 0x65323068
    case illustrator3 = 0x65327832
    case illustrator8 = 0x65323037
    case illustrator9 = 0x65323038
    case japanese3 = 0x65323032
}

// MARK: AdobeIllustratorEPdX
@objc public enum AdobeIllustratorEPdX : AEKeyword {
    case pdfx1a2001 = 0x65506431
    case pdfx1a2003 = 0x65506432
    case pdfx32001 = 0x65506433
    case pdfx32002 = 0x65506445
    case pdfx32003 = 0x65506434
    case pdfx42007 = 0x65506435
    case pdfxNone = 0x65506430
}

// MARK: AdobeIllustratorEPDc
@objc public enum AdobeIllustratorEPDc : AEKeyword {
    case acrobat4 = 0x65323331
    case acrobat5 = 0x65323332
    case acrobat6 = 0x65323333
    case acrobat7 = 0x65323334
    case acrobat8 = 0x65323335
}

// MARK: AdobeIllustratorEPSc
@objc public enum AdobeIllustratorEPSc : AEKeyword {
    case photoshop6 = 0x65323431
    case photoshop8 = 0x65323432
}

// MARK: AdobeIllustratorCCcT
@objc public enum AdobeIllustratorCCcT : AEKeyword {
    case automaticJPEGHigh = 0x65353034
    case automaticJPEGLow = 0x65353032
    case automaticJPEGMaximum = 0x65353035
    case automaticJPEGMedium = 0x65353033
    case automaticJPEGMinimum = 0x65353031
    case automaticJPEG2000High = 0x65353065
    case automaticJPEG2000Lossless = 0x65353131
    case automaticJPEG2000Low = 0x65353063
    case automaticJPEG2000Maximum = 0x65353130
    case automaticJPEG2000Medium = 0x65353064
    case automaticJPEG2000Minimum = 0x65353062
    case jpegHigh = 0x65323538
    case jpegLow = 0x65323536
    case jpegMaximum = 0x65323539
    case jpegMedium = 0x65323537
    case jpegMinimum = 0x65323535
    case jpeg2000High = 0x65353135
    case jpeg2000Lossless = 0x65353137
    case jpeg2000Low = 0x65353133
    case jpeg2000Maximum = 0x65353136
    case jpeg2000Medium = 0x65353134
    case jpeg2000Minimum = 0x65353132
    case none = 0x67653031
    case zip4bit = 0x65323561
    case zip8bit = 0x65323562
}

// MARK: AdobeIllustratorEPcC
@objc public enum AdobeIllustratorEPcC : AEKeyword {
    case colorConversionRepurpose = 0x65506333
    case colorConversionToDest = 0x65506332
    case none = 0x67653031
}

// MARK: AdobeIllustratorEDcD
@objc public enum AdobeIllustratorEDcD : AEKeyword {
    case colorDestDocCmyk = 0x65446332
    case colorDestDocRgb = 0x65446334
    case colorDestProfile = 0x65446336
    case colorDestWorkingCmyk = 0x65446333
    case colorDestWorkingRgb = 0x65446335
    case none = 0x67653031
}

// MARK: AdobeIllustratorEDpC
@objc public enum AdobeIllustratorEDpC : AEKeyword {
    case includeAllProfiles = 0x65447032
    case includeAllRgb = 0x65447034
    case includeDestProfile = 0x65447035
    case leaveProfileUnchanged = 0x65447033
    case none = 0x67653031
}

// MARK: AdobeIllustratorCMcQ
@objc public enum AdobeIllustratorCMcQ : AEKeyword {
    case ccit3 = 0x65323732
    case ccit4 = 0x65323731
    case none = 0x67653031
    case runLength = 0x65323734
    case zip = 0x65323733
}

// MARK: AdobeIllustratorCPtW
@objc public enum AdobeIllustratorCPtW : AEKeyword {
    case trimmarkweight0125 = 0x65353730
    case trimmarkweight025 = 0x65353731
    case trimmarkweight05 = 0x65353732
}

// MARK: AdobeIllustratorCPoP
@objc public enum AdobeIllustratorCPoP : AEKeyword {
    case discard = 0x65353431
    case preserve = 0x65353430
}

// MARK: AdobeIllustratorCPpA
@objc public enum AdobeIllustratorCPpA : AEKeyword {
    case pdf128PrintHighRes = 0x65353532
    case pdf128PrintLowRes = 0x65353531
    case pdf128PrintNone = 0x65353530
    case pdf40PrintHighRes = 0x65353534
    case pdf40PrintNone = 0x65353533
}

// MARK: AdobeIllustratorCPcA
@objc public enum AdobeIllustratorCPcA : AEKeyword {
    case pdf128AnyChanges = 0x65353634
    case pdf128CommentingAllowed = 0x65353633
    case pdf128EditPageAllowed = 0x65353631
    case pdf128FillFormAllowed = 0x65353632
    case pdf128NoChanges = 0x65353630
    case pdf40AnyChanges = 0x65353638
    case pdf40CommentingAllowed = 0x65353636
    case pdf40NoChanges = 0x65353635
    case pdf40PageLayoutAllowed = 0x65353637
}

// MARK: AdobeIllustratorCRsT
@objc public enum AdobeIllustratorCRsT : AEKeyword {
    case averageDownsampling = 0x65323931
    case bicubicDownsample = 0x65323933
    case nodownsample = 0x65323930
    case subsampling = 0x65323932
}

// MARK: AdobeIllustratorEEPV
@objc public enum AdobeIllustratorEEPV : AEKeyword {
    case bwMacintosh = 0x65323131
    case bwtiff = 0x65323133
    case colorMacintosh = 0x65323132
    case colorTIFF = 0x65323134
    case none = 0x67653031
    case transparentColorTIFF = 0x65323135
}

// MARK: AdobeIllustratorEPSt
@objc public enum AdobeIllustratorEPSt : AEKeyword {
    case level2 = 0x65323231
    case level3 = 0x65323232
}

// MARK: AdobeIllustratorEPPS
@objc public enum AdobeIllustratorEPPS : AEKeyword {
    case level1 = 0x65323230
    case level2 = 0x65323231
    case level3 = 0x65323232
}

// MARK: AdobeIllustratorSavo
@objc public enum AdobeIllustratorSavo : AEKeyword {
    case ask = 0x61736b20
    case no = 0x6e6f2020
    case yes = 0x79657320
}

// MARK: AdobeIllustratorERUt
@objc public enum AdobeIllustratorERUt : AEKeyword {
    case centimeters = 0x65313833
    case feet = 0x65313863
    case feetinches = 0x65313839
    case inches = 0x65313832
    case meters = 0x65313861
    case millimeters = 0x65313836
    case picas = 0x65313835
    case pixels = 0x65313838
    case points = 0x65313834
    case qs = 0x65313837
    case unknown = 0x65313230
    case yards = 0x65313862
}

// MARK: AdobeIllustratorCBlM
@objc public enum AdobeIllustratorCBlM : AEKeyword {
    case colorBlend = 0x65333134
    case colorBurn = 0x65333037
    case colorDodge = 0x65333036
    case darken = 0x65333038
    case difference = 0x65333130
    case exclusion = 0x65333131
    case hardLight = 0x65333035
    case hue = 0x65333132
    case lighten = 0x65333039
    case luminosity = 0x65333135
    case multiply = 0x65333031
    case normal = 0x65313130
    case overlay = 0x65333033
    case saturationBlend = 0x65333133
    case screen = 0x65333032
    case softLight = 0x65333034
}

// MARK: AdobeIllustratorCKOS
@objc public enum AdobeIllustratorCKOS : AEKeyword {
    case disabled = 0x65333231
    case enabled = 0x65333232
    case inherited = 0x65333233
    case unknown = 0x65313230
}

// MARK: AdobeIllustratorEZOR
@objc public enum AdobeIllustratorEZOR : AEKeyword {
    case moveBackward = 0x65333732
    case moveForward = 0x65333731
    case moveToBack = 0x65333733
    case moveToFront = 0x65333730
}

// MARK: AdobeIllustratorEDTD
@objc public enum AdobeIllustratorEDTD : AEKeyword {
    case svg10 = 0x65334230
    case svg11 = 0x65334231
    case svgBasic11 = 0x65334234
    case svgTiny11 = 0x65334232
    case svgTiny11Plus = 0x65334233
    case svgTiny12 = 0x65334235
}

// MARK: AdobeIllustratorESFT
@objc public enum AdobeIllustratorESFT : AEKeyword {
    case outlineFont = 0x65334132
    case svgFont = 0x65334131
}

// MARK: AdobeIllustratorESFS
@objc public enum AdobeIllustratorESFS : AEKeyword {
    case allGlyphs = 0x65333835
    case commonEnglish = 0x65333831
    case commonRoman = 0x65333833
    case glyphsUsed = 0x65333830
    case glyphsUsedPlusEnglish = 0x65333832
    case glyphsUsedPlusRoman = 0x65333834
    case none = 0x67653031
}

// MARK: AdobeIllustratorESDE
@objc public enum AdobeIllustratorESDE : AEKeyword {
    case ascii = 0x65343030
    case utf16 = 0x65343032
    case utf8 = 0x65343031
}

// MARK: AdobeIllustratorESCS
@objc public enum AdobeIllustratorESCS : AEKeyword {
    case entities = 0x65343130
    case presentationAttributes = 0x65343133
    case styleAttributes = 0x65343131
    case styleElements = 0x65343132
}

// MARK: AdobeIllustratorESIT
@objc public enum AdobeIllustratorESIT : AEKeyword {
    case minimalSvg = 0x65334330
    case regularSvg = 0x65334331
    case uniqueSvg = 0x65334332
}

// MARK: AdobeIllustratorERIL
@objc public enum AdobeIllustratorERIL : AEKeyword {
    case embed = 0x65334430
    case link = 0x65334431
    case preserve = 0x65334432
}

// MARK: AdobeIllustratorEOFl
@objc public enum AdobeIllustratorEOFl : AEKeyword {
    case preserveAppearance = 0x65343231
    case preservePaths = 0x65343230
}

// MARK: AdobeIllustratorECMd
@objc public enum AdobeIllustratorECMd : AEKeyword {
    case processColor = 0x65343236
    case registrationColor = 0x65343235
    case spotColor = 0x65343237
}

// MARK: AdobeIllustratorESCk
@objc public enum AdobeIllustratorESCk : AEKeyword {
    case spotCmykColor = 0x6b434d59
    case spotLabColor = 0x6b4c4142
    case spotRgbColor = 0x6b524742
}

// MARK: AdobeIllustratorEVKd
@objc public enum AdobeIllustratorEVKd : AEKeyword {
    case graph = 0x65343434
    case image = 0x65343433
    case textual = 0x65343432
    case unknown = 0x65313230
    case visibility = 0x65343431
}

// MARK: AdobeIllustratorEAFF
@objc public enum AdobeIllustratorEAFF : AEKeyword {
    case dwg = 0x65414631
    case dxf = 0x65414630
}

// MARK: AdobeIllustratorEAVS
@objc public enum AdobeIllustratorEAVS : AEKeyword {
    case autoCADRelease13 = 0x65415630
    case autoCADRelease14 = 0x65415631
    case autoCADRelease15 = 0x65415632
    case autoCADRelease18 = 0x65415633
    case autoCADRelease21 = 0x65415634
    case autoCADRelease24 = 0x65415635
}

// MARK: AdobeIllustratorEASU
@objc public enum AdobeIllustratorEASU : AEKeyword {
    case autocadCentimeters = 0x65415534
    case autocadInches = 0x65415532
    case autocadMillimeters = 0x65415533
    case autocadPicas = 0x65415531
    case autocadPixels = 0x65415535
    case autocadPoints = 0x65415530
}

// MARK: AdobeIllustratorEACL
@objc public enum AdobeIllustratorEACL : AEKeyword {
    case max16Colors = 0x65414331
    case max256Colors = 0x65414332
    case max8Colors = 0x65414330
    case trueColors = 0x65414333
}

// MARK: AdobeIllustratorEARF
@objc public enum AdobeIllustratorEARF : AEKeyword {
    case jpegRaster = 0x65415231
    case pngRaster = 0x65415230
}

// MARK: AdobeIllustratorEExO
@objc public enum AdobeIllustratorEExO : AEKeyword {
    case maintainAppearance = 0x65457830
    case maximizeEditability = 0x65457831
}

// MARK: AdobeIllustratorEGSO
@objc public enum AdobeIllustratorEGSO : AEKeyword {
    case fitArtboard = 0x65415331
    case originalSize = 0x65415330
    case scaleByValue = 0x65415332
}

// MARK: AdobeIllustratorETbo
@objc public enum AdobeIllustratorETbo : AEKeyword {
    case ibmpc = 0x6b544250
    case macintosh = 0x6b54424d
}

// MARK: AdobeIllustratorEMUI
@objc public enum AdobeIllustratorEMUI : AEKeyword {
    case interactWithAll = 0x65343564
    case interactWithLocal = 0x65343563
    case interactWithSelf = 0x65343562
    case neverInteract = 0x65343561
}

// MARK: AdobeIllustratorEPVu
@objc public enum AdobeIllustratorEPVu : AEKeyword {
    case negative = 0x65616f32
    case positive = 0x65613031
}

// MARK: AdobeIllustratorE940
@objc public enum AdobeIllustratorE940 : AEKeyword {
    case beforeRunning = 0x61393432
    case never = 0x4e657672
    case onRuntimeError = 0x65393431
}

// MARK: AdobeIllustratorECHd
@objc public enum AdobeIllustratorECHd : AEKeyword {
    case kumiMoji = 0x65313132
    case normal = 0x65313130
    case rotated = 0x65313131
}

// MARK: AdobeIllustratorEPBX
@objc public enum AdobeIllustratorEPBX : AEKeyword {
    case pdfArtBox = 0x65504f31
    case pdfBleedBox = 0x65503034
    case pdfBoundingBox = 0x65503036
    case pdfCropBox = 0x65503032
    case pdfMediaBox = 0x65503035
    case pdfTrimBox = 0x65503033
}

// MARK: AdobeIllustratorERAS
@objc public enum AdobeIllustratorERAS : AEKeyword {
    case bitmapRasterization = 0x6b525362
    case defaultRasterization = 0x6b525364
    case grayscaleRasterization = 0x6b525367
}

// MARK: AdobeIllustratorEALS
@objc public enum AdobeIllustratorEALS : AEKeyword {
    case artOptimized = 0x614f5054
    case none = 0x67653031
    case typeOptimized = 0x744f5054
}

// MARK: AdobeIllustratorEFxV
@objc public enum AdobeIllustratorEFxV : AEKeyword {
    case version10 = 0x65353831
    case version20 = 0x65353832
}

// MARK: AdobeIllustratorEFFp
@objc public enum AdobeIllustratorEFFp : AEKeyword {
    case expandFilters = 0x65353931
    case keepFiltersEditable = 0x65353933
    case rasterizeFilters = 0x65353932
}

// MARK: AdobeIllustratorEFTp
@objc public enum AdobeIllustratorEFTp : AEKeyword {
    case autoConvertText = 0x65356134
    case keepTextEditable = 0x65356133
    case outlineText = 0x65356131
    case rasterizeText = 0x65356132
}

// MARK: AdobeIllustratorEFGp
@objc public enum AdobeIllustratorEFGp : AEKeyword {
    case autoConvertGradients = 0x65356234
    case keepGradientsEditable = 0x65356233
}

// MARK: AdobeIllustratorEFBp
@objc public enum AdobeIllustratorEFBp : AEKeyword {
    case autoConvertBlends = 0x65356331
    case rasterizeBlends = 0x65356332
}

// MARK: AdobeIllustratorECoS
@objc public enum AdobeIllustratorECoS : AEKeyword {
    case artboardCoordinateSystem = 0x65436f32
    case documentCoordinateSystem = 0x65436f31
}

// MARK: AdobeIllustratorESRp
@objc public enum AdobeIllustratorESRp : AEKeyword {
    case symbolBottomleftPoint = 0x65535237
    case symbolBottommiddlePoint = 0x65535238
    case symbolBottomrightPoint = 0x65535239
    case symbolCenterPoint = 0x65535235
    case symbolMiddleleftPoint = 0x65535234
    case symbolMiddlerightPoint = 0x65535236
    case symbolTopleftPoint = 0x65535231
    case symbolTopmiddlePoint = 0x65535232
    case symbolToprightPoint = 0x65535233
}

// MARK: AdobeIllustratorEPPt
@objc public enum AdobeIllustratorEPPt : AEKeyword {
    case floorplane = 0x65505034
    case leftplane = 0x65505032
    case noplane = 0x65505031
    case rightplane = 0x65505033
}

// MARK: AdobeIllustratorEDST
@objc public enum AdobeIllustratorEDST : AEKeyword {
    case cascade = 0x6b414364
    case consolidateAll = 0x6b414341
    case floatAll = 0x6b414641
    case horizontalTile = 0x6b414854
    case verticalTile = 0x6b415654
}

// MARK: AdobeIllustratorEJCT
@objc public enum AdobeIllustratorEJCT : AEKeyword {
    case baselineOptimized = 0x65323637
    case baselineStandard = 0x65323636
    case progressive = 0x65323638
}

// MARK: AdobeIllustratorECCP
@objc public enum AdobeIllustratorECCP : AEKeyword {
    case defaultPurpose = 0x6b445055
    case dummyPurposeOption = 0x6b44554d
    case exportPurpose = 0x6b455055
    case previewPurpose = 0x6b505055
}

// MARK: AdobeIllustratorEATK
@objc public enum AdobeIllustratorEATK : AEKeyword {
    case auto = 0x65414530
    case metricsromanonly = 0x65414573
    case none = 0x67653031
    case optical = 0x65414531
}

// MARK: AdobeIllustratorEALD
@objc public enum AdobeIllustratorEALD : AEKeyword {
    case bottomToBottom = 0x65427442
    case topToTop = 0x65547454
}

// MARK: AdobeIllustratorECCT
@objc public enum AdobeIllustratorECCT : AEKeyword {
    case lowerCase = 0x65414534
    case sentenceCase = 0x65414536
    case titleCase = 0x65414535
    case upperCase = 0x65414533
}

// MARK: AdobeIllustratorEFCO
@objc public enum AdobeIllustratorEFCO : AEKeyword {
    case allCaps = 0x65414538
    case allSmallCaps = 0x65414539
    case normal = 0x65313130
    case smallCaps = 0x65414537
}

// MARK: AdobeIllustratorEFBO
@objc public enum AdobeIllustratorEFBO : AEKeyword {
    case normal = 0x65313130
    case `subscript` = 0x704f5438
    case superscript = 0x704f5439
}

// MARK: AdobeIllustratorCOTP
@objc public enum AdobeIllustratorCOTP : AEKeyword {
    case `default` = 0x70465330
    case denominator = 0x704f5437
    case numerator = 0x704f5436
    case `subscript` = 0x704f5438
    case superscript = 0x704f5439
}

// MARK: AdobeIllustratorCFST
@objc public enum AdobeIllustratorCFST : AEKeyword {
    case `default` = 0x70465330
    case proportional = 0x70465333
    case proportionalOldstyle = 0x70465332
    case tabular = 0x70465331
    case tabularOldstyle = 0x70465334
}

// MARK: AdobeIllustratorEBSD
@objc public enum AdobeIllustratorEBSD : AEKeyword {
    case standard = 0x65303830
    case tateChuYoko = 0x65414564
    case verticalRotated = 0x65414563
}

// MARK: AdobeIllustratorELNG
@objc public enum AdobeIllustratorELNG : AEKeyword {
    case arabic = 0x654c3339
    case bengaliIndia = 0x654c3531
    case bokmalNorwegian = 0x654c3039
    case brazillianPortuguese = 0x654c3132
    case bulgarian = 0x654c3231
    case canadianFrench = 0x654c3034
    case catalan = 0x654c3138
    case chinese = 0x654c3330
    case czech = 0x654c3233
    case danish = 0x654c3137
    case dutch = 0x654c3136
    case dutch2005Reform = 0x654c3433
    case english = 0x654c3031
    case farsi = 0x654c3431
    case finnish = 0x654c3032
    case german2006Reform = 0x654c3432
    case greek = 0x654c3236
    case gujarati = 0x654c3533
    case hindi = 0x654c3439
    case hungarian = 0x654c3239
    case icelandic = 0x654c3238
    case italian = 0x654c3038
    case japanese = 0x654c3331
    case kannada = 0x654c3537
    case malayalam = 0x654c3538
    case marathi = 0x654c3530
    case nynorskNorwegian = 0x654c3130
    case oldGerman = 0x654c3036
    case oriya = 0x654c3534
    case polish = 0x654c3234
    case punjabi = 0x654c3532
    case romanian = 0x654c3235
    case russian = 0x654c3139
    case serbian = 0x654c3232
    case spanish = 0x654c3133
    case standardFrench = 0x654c3033
    case standardGerman = 0x654c3035
    case standardPortuguese = 0x654c3131
    case swedish = 0x654c3134
    case swissGerman = 0x654c3037
    case swissGerman2006Reform = 0x654c3434
    case tamil = 0x654c3535
    case telugu = 0x654c3536
    case turkish = 0x654c3237
    case ukEnglish = 0x654c3135
    case ukranian = 0x654c3230
}

// MARK: AdobeIllustratorEAGF
@objc public enum AdobeIllustratorEAGF : AEKeyword {
    case `default` = 0x70465330
    case expert = 0x65414566
    case fullWidth = 0x6541456f
    case halfWidth = 0x65414569
    case jis04 = 0x65414572
    case jis78 = 0x65414567
    case jis83 = 0x65414568
    case jis90 = 0x65414571
    case proportionalWidth = 0x65414570
    case quarterWidth = 0x6541456b
    case thirdWidth = 0x6541456a
    case traditional = 0x65414565
}

// MARK: AdobeIllustratorESRA
@objc public enum AdobeIllustratorESRA : AEKeyword {
    case bottom = 0x65313737
    case center = 0x65313232
    case icfBottom = 0x6541456c
    case icfTop = 0x6541456e
    case romanBaseline = 0x6541456d
    case top = 0x65313735
}

// MARK: AdobeIllustratorEWCJ
@objc public enum AdobeIllustratorEWCJ : AEKeyword {
    case autoJustify = 0x65313239
    case center = 0x65313232
    case fullJustify = 0x65313238
    case fullJustifyLastLineCenter = 0x65313237
    case fullJustifyLastLineLeft = 0x65313235
    case fullJustifyLastLineRight = 0x65313236
    case left = 0x65313231
    case right = 0x65313233
}

// MARK: AdobeIllustratorEKas
@objc public enum AdobeIllustratorEKas : AEKeyword {
    case kashidaDefault = 0x6b4b6444
    case kashidaOff = 0x6b4b4f66
    case kashidaOn = 0x6b4b4f6e
}

// MARK: AdobeIllustratorEDOT
@objc public enum AdobeIllustratorEDOT : AEKeyword {
    case diroverrideDefault = 0x6b446f44
    case diroverrideLtr = 0x6b444c52
    case diroverrideRtl = 0x6b44524c
}

// MARK: AdobeIllustratorEDgS
@objc public enum AdobeIllustratorEDgS : AEKeyword {
    case arabicDigits = 0x6b414474
    case defaultDigits = 0x6b444474
    case farsiDigits = 0x6b464474
    case hindiDigits = 0x6b484474
}

// MARK: AdobeIllustratorEDVP
@objc public enum AdobeIllustratorEDVP : AEKeyword {
    case diacVposLoose = 0x6b44506c
    case diacVposMedium = 0x6b44506d
    case diacVposOff = 0x6b44506f
    case diacVposTight = 0x6b445074
}

// MARK: AdobeIllustratorEKWT
@objc public enum AdobeIllustratorEKWT : AEKeyword {
    case kashidaLong = 0x6b4b614c
    case kashidaMedium = 0x6b4b614d
    case kashidaNone = 0x6b4b614e
    case kashidaSmall = 0x6b4b6153
    case kashidaStylistic = 0x6b4b5379
}

// MARK: AdobeIllustratorECET
@objc public enum AdobeIllustratorECET : AEKeyword {
    case adornment = 0x6b41436f
    case latinCJKComposer = 0x6b4c436f
    case optycaComposer = 0x6b4f436f
}

// MARK: AdobeIllustratorEPDT
@objc public enum AdobeIllustratorEPDT : AEKeyword {
    case leftToRight = 0x6b4c7452
    case rightToLeft = 0x6b52744c
}

// MARK: AdobeIllustratorEPJ0
@objc public enum AdobeIllustratorEPJ0 : AEKeyword {
    case forced = 0x65504a31
    case none = 0x67653031
    case standard = 0x65303830
}

// MARK: AdobeIllustratorEPJ2
@objc public enum AdobeIllustratorEPJ2 : AEKeyword {
    case pushIn = 0x65504a33
    case pushOutFirst = 0x65504a34
    case pushOutOnly = 0x65504a35
}

// MARK: AdobeIllustratorEFBT
@objc public enum AdobeIllustratorEFBT : AEKeyword {
    case baselineAscent = 0x6b424153
    case baselineCapHeight = 0x6b424348
    case baselineEmBoxHeight = 0x6b424548
    case baselineFixed = 0x6b424658
    case baselineLeading = 0x6b424c47
    case baselineLegacy = 0x6b424c59
    case baselineXHeight = 0x6b425848
}

// MARK: AdobeIllustratorELib
@objc public enum AdobeIllustratorELib : AEKeyword {
    case brushesLibrary = 0x65313937
    case graphicStylesLibrary = 0x65313938
    case illustratorArtwork = 0x65313935
    case swatchesLibrary = 0x65313936
    case symbolsLibrary = 0x65313939
}

// MARK: AdobeIllustratorCETE
@objc public enum AdobeIllustratorCETE : AEKeyword {
    case ai = 0x73343430
    case ait = 0x73343432
    case autoCAD = 0x73343531
    case avif = 0x73343535
    case eps = 0x73343431
    case gif = 0x73343530
    case jpeg = 0x73343436
    case pdf = 0x73343433
    case photoshop = 0x73343437
    case png24 = 0x73343439
    case png8 = 0x73343438
    case svg = 0x73343435
    case svgz = 0x73343434
    case tiff = 0x73343532
    case webP = 0x73343534
    case wosvg = 0x73343533
}

// MARK: AdobeIllustratorEDCt
@objc public enum AdobeIllustratorEDCt : AEKeyword {
    case eps = 0x65313932
    case fxg = 0x65313934
    case illustrator = 0x65313931
    case pdf = 0x65313933
}

// MARK: AdobeIllustratorEEST
@objc public enum AdobeIllustratorEEST : AEKeyword {
    case scaleByFactor = 0x65323630
    case scaleByHeight = 0x65323632
    case scaleByResolution = 0x65323633
    case scaleByWidth = 0x65323631
}

// MARK: AdobeIllustratorEEFT
@objc public enum AdobeIllustratorEEFT : AEKeyword {
    case se_avif = 0x65323634
    case se_jpeg100 = 0x65323436
    case se_jpeg20 = 0x65323439
    case se_jpeg50 = 0x65323438
    case se_jpeg80 = 0x65323437
    case se_pdf = 0x65323533
    case se_png24 = 0x65323532
    case se_png8 = 0x65323531
    case se_svg = 0x65323530
    case se_webp = 0x65323534
}

// MARK: AdobeIllustratorCEFT
@objc public enum AdobeIllustratorCEFT : AEKeyword {
    case autoCAD = 0x65333337
    case avif = 0x65333431
    case gif = 0x65333335
    case jpeg = 0x65333330
    case photoshop = 0x65333331
    case png24 = 0x65333334
    case png8 = 0x65333333
    case svg = 0x65333332
    case tiff = 0x65333338
    case webP = 0x65333430
    case wosvg = 0x65333339
}

// MARK: AdobeIllustratorCCRM
@objc public enum AdobeIllustratorCCRM : AEKeyword {
    case adaptive = 0x65333530
    case perceptual = 0x65333532
    case selective = 0x65333531
    case web = 0x65333533
}

// MARK: AdobeIllustratorCDtM
@objc public enum AdobeIllustratorCDtM : AEKeyword {
    case diffusion = 0x65333630
    case noise = 0x65333633
    case none = 0x67653031
    case patternDither = 0x65333631
}

// MARK: AdobeIllustratorEPAD
@objc public enum AdobeIllustratorEPAD : AEKeyword {
    case allLayers = 0x65343633
    case visibleLayers = 0x65343632
    case visiblePrintableLayers = 0x65343631
}

// MARK: AdobeIllustratorEPBD
@objc public enum AdobeIllustratorEPBD : AEKeyword {
    case artboardBounds = 0x65343731
    case artworkBounds = 0x65343732
    case cropBounds = 0x65343733
}

// MARK: AdobeIllustratorEPCS
@objc public enum AdobeIllustratorEPCS : AEKeyword {
    case composite = 0x65343831
    case hostBasedSeparation = 0x65343832
    case inRIPSeparation = 0x65343833
}

// MARK: AdobeIllustratorEPOR
@objc public enum AdobeIllustratorEPOR : AEKeyword {
    case autoRotate = 0x65343935
    case landscape = 0x65343932
    case portrait = 0x65343931
    case reverseLandscape = 0x65343934
    case reversePortrait = 0x65343933
}

// MARK: AdobeIllustratorEPPO
@objc public enum AdobeIllustratorEPPO : AEKeyword {
    case bottom = 0x65313737
    case bottomLeft = 0x65313734
    case bottomRight = 0x65313741
    case center = 0x65313232
    case left = 0x65313231
    case right = 0x65313233
    case top = 0x65313735
    case topLeft = 0x65313732
    case topRight = 0x65313738
}

// MARK: AdobeIllustratorEPTL
@objc public enum AdobeIllustratorEPTL : AEKeyword {
    case fullPages = 0x65346131
    case imageableAreas = 0x65346132
    case singleFullPage = 0x65346130
}

// MARK: AdobeIllustratorEPMS
@objc public enum AdobeIllustratorEPMS : AEKeyword {
    case japaneseStyle = 0x65303831
    case roman = 0x65414532
}

// MARK: AdobeIllustratorEPFD
@objc public enum AdobeIllustratorEPFD : AEKeyword {
    case complete = 0x65346332
    case none = 0x67653031
    case subset = 0x65346331
}

// MARK: AdobeIllustratorEPFS
@objc public enum AdobeIllustratorEPFS : AEKeyword {
    case deviceSubstitution = 0x65346433
    case obliqueSubstitution = 0x65346431
    case tintSubstitution = 0x65346432
}

// MARK: AdobeIllustratorEPIC
@objc public enum AdobeIllustratorEPIC : AEKeyword {
    case jpeg = 0x65333330
    case none = 0x67653031
    case rle = 0x65346531
}

// MARK: AdobeIllustratorEPCP
@objc public enum AdobeIllustratorEPCP : AEKeyword {
    case customProfile = 0x65346634
    case oldstyleProfile = 0x65346631
    case printerProfile = 0x65346633
    case sourceProfile = 0x65346632
}

// MARK: AdobeIllustratorEPCI
@objc public enum AdobeIllustratorEPCI : AEKeyword {
    case absoluteColorimetric = 0x65346733
    case perceptual = 0x65333532
    case relativeColorimetric = 0x65346732
    case saturation = 0x65346731
}

// MARK: AdobeIllustratorEPTY
@objc public enum AdobeIllustratorEPTY : AEKeyword {
    case nonPostScriptPrinter = 0x65346832
    case postScriptPrinter = 0x65346831
    case unknown = 0x65313230
}

// MARK: AdobeIllustratorEPCM
@objc public enum AdobeIllustratorEPCM : AEKeyword {
    case blackAndWhiteOutput = 0x65346933
    case colorOutput = 0x65346931
    case grayscaleOutput = 0x65346932
}

// MARK: AdobeIllustratorEPST
@objc public enum AdobeIllustratorEPST : AEKeyword {
    case convertInk = 0x65346a33
    case disableInk = 0x65346a31
    case enableInk = 0x65346a32
}

// MARK: AdobeIllustratorEPIK
@objc public enum AdobeIllustratorEPIK : AEKeyword {
    case blackInk = 0x70506d62
    case customInk = 0x70506d63
    case cyanInk = 0x70506d38
    case magentaInk = 0x70506d39
    case yellowInk = 0x70506d61
}

// MARK: AdobeIllustratorEPTT
@objc public enum AdobeIllustratorEPTT : AEKeyword {
    case ignoreOpaque = 0x65346c33
    case normal = 0x65313130
    case opaque = 0x65346c32
    case transparent = 0x65346c31
}

// MARK: AdobeIllustratorETet
@objc public enum AdobeIllustratorETet : AEKeyword {
    case abuttingTracingMethod = 0x65544d61
    case overlappingTracingMethod = 0x65544d6f
}

// MARK: AdobeIllustratorETMt
@objc public enum AdobeIllustratorETMt : AEKeyword {
    case bwTracingMode = 0x65544d62
    case colorTracingMode = 0x65544d63
    case grayTracingMode = 0x65544d67
}

// MARK: AdobeIllustratorETCt
@objc public enum AdobeIllustratorETCt : AEKeyword {
    case useFullColors = 0x65544366
    case useLimitedColors = 0x6554436c
}

// MARK: AdobeIllustratorETvv
@objc public enum AdobeIllustratorETvv : AEKeyword {
    case viewOutlines = 0x65547633
    case viewOutlinesWithTracing = 0x65547632
    case viewOutlinesWithTransparentImage = 0x65547634
    case viewSourceImage = 0x65547635
    case viewTracingResult = 0x65547631
}

// MARK: AdobeIllustratorEGSF
@objc public enum AdobeIllustratorEGSF : AEKeyword {
    case horizontalAndVerticalSf = 0x65473033
    case horizontalsf = 0x65473031
    case noShiftOrFlip = 0x65473030
    case verticalsf = 0x65473032
}

// MARK: AdobeIllustratorERRU
@objc public enum AdobeIllustratorERRU : AEKeyword {
    case numberOfInstances = 0x6b525531
    case radialAll = 0x6b525533
    case radiusOfArt = 0x6b525530
    case reverseOverlap = 0x6b525532
}

// MARK: AdobeIllustratorEGRU
@objc public enum AdobeIllustratorEGRU : AEKeyword {
    case gridAll = 0x6b475532
    case horizontalSpacing = 0x6b475530
    case verticalSpacing = 0x6b475531
}

// MARK: AdobeIllustratorESRU
@objc public enum AdobeIllustratorESRU : AEKeyword {
    case axisRotation = 0x6b535530
    case symmetryAll = 0x6b535531
}

// MARK: AdobeIllustratorGenericMethods
@objc public protocol AdobeIllustratorGenericMethods {
    @objc optional func delete() // Remove an element from an object
    @objc optional func duplicateTo(_ to: SBObject!, withProperties: [AnyHashable : Any]!) -> SBObject // Duplicate one or more object(s)
    @objc optional func exists() -> Bool // Verify if an object exists
    @objc optional func moveTo(_ to: SBObject!) -> SBObject // Move object(s) to a new location
}

// MARK: AdobeIllustratorApplication
@objc public protocol AdobeIllustratorApplication: SBApplicationProtocol {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var browserAvailable: Bool { get } // is a web browser available?
    @objc optional var buildNumber: String { get } // the build number of the Adobe Illustrator application
    @objc optional var colorSettings: [Any] { get } // the list of color settings files currently available for use
    @objc optional var coordinateSystem: AdobeIllustratorECoS { get } // Coordinate System used by script
    @objc optional var currentAdobeId: String { get } // The current users adobe id
    @objc optional var currentDocument: AdobeIllustratorDocument { get } // The active document
    @objc optional var currentUserGuid: String { get } // The current user's GUID
    @objc optional var defaultColorSettings: URL { get } // the default color settings file for the current application locale.
    @objc optional var flattenerPresets: [Any] { get } // the list of flattener style names currently available for use
    @objc optional var freeMemory: Int { get } // the amount of unused memory within the Adobe Illustrator partition
    @objc optional var frontmost: Bool { get } // Is this the frontmost application?
    @objc optional var homescreenvisible: Bool { get } // true if home Screen is Visible
    @objc optional var locale: String { get } // the Locale of the Adobe Illustrator application
    @objc optional var name: String { get } // The application's name
    @objc optional var pasteRemembersLayers: Bool { get } // does paste operation remember layers structure?
    @objc optional var PDFPresets: [Any] { get } // the list of PDF preset names currently available for use
    @objc optional var PPDs: [Any] { get } // the list of PPD files currently available for use. For performance reasons, the PPDFile entry only contains the model name and file spec of each PPD file.
    @objc optional var printPresets: [Any] { get } // the list of print preset names currently available for use
    @objc optional var printers: [Any] { get } // the list of installed printers
    @objc optional var scriptingVersion: String { get } // the version of the Scripting plugin
    @objc optional var selection: Any { get } // the selection visible to the user
    @objc optional var settings: AdobeIllustratorIllustratorPreferences { get } // preferences for Illustrator
    @objc optional var startupPresets: [Any] { get } // the list of presets available for creating a new document
    @objc optional var tracingPresets: [Any] { get } // the list of tracing preset names currently available for use
    @objc optional var userInteractionLevel: AdobeIllustratorEMUI { get } // what level of interaction with the user should be allowed when handling script commands
    @objc optional var version: String { get } // the version of the Adobe Illustrator application
    @objc optional func documents() -> SBElementArray
    @objc optional func executeAATFileFile(_ file: URL!) // executes the active session in the sequencer
    @objc optional func getPPDInfoFor(_ `for`: String!) -> AdobeIllustratorPPDProperties // get detailed info from the specified PPD file
    @objc optional func loadColorSettingsFrom(_ from: URL!) // load the color settings from the file. If the file is an empty file spec, the color management will be turned off.
    @objc optional func `open`(_ x: Any!, forcing: AdobeIllustratorECCS, dialogs: Bool, withOptions: Any!) // Open the specified document file(s)
    @objc optional func print(_ x: Any!, options: AdobeIllustratorPrintOptions!) // Print the specified document(s) or file(s)
    @objc optional func quit() // Quit the application
    @objc optional func showPresetsFrom(_ from: URL!) -> [Any] // get presets from the file
    @objc optional func ISInTouchWorkspace() -> Bool // Is In Touch Workspace
    @objc optional func SelectToolToolName(_ toolName: String!) -> Bool // Select tool using toolname
    @objc optional func deleteWorkspaceWorkspaceName(_ workspaceName: String!) -> Bool // Deletes an existing workspace
    @objc optional func getScriptableHelpGroup() -> Any // Get the scriptable help group object that represents the search widget in the app bar
    @objc optional func isusersharingappusagedata() -> Bool // Is user sharing the application usage data
    @objc optional func redraw() // Force Illustrator to redraw its window(s)
    @objc optional func reflectCsawTo(_ to: Any!) // generate Creative Suite ActionScript Wrappers in specified directory
    @objc optional func resetWorkspace() -> Bool // Resets the current workspace
    @objc optional func saveWorkspaceWorkspaceName(_ workspaceName: String!) -> Bool // Saves a new workspace
    @objc optional func showlearnpanelwithcontentManifest(_ manifest: String!, HTMLpage: String!) -> Bool // Display learn panel with specific content
    @objc optional func switchWorkspaceWorkspaceName(_ workspaceName: String!) -> Bool // Switches between workspaces
    @objc optional func convertSampleColorSourceColorSpace(_ sourceColorSpace: AdobeIllustratorECLS, sourceColor: [Any]!, destinationColorSpace: AdobeIllustratorECLS, colorConversionPurpose: AdobeIllustratorECCP, sourceHasAlpha: Bool, destinationHasAlpha: Bool) -> [Any] // Converts a sample-component color from one color space to another.
    @objc optional func translatePlaceholderText(_ x: String!) -> String // translate the placeholder text to regular text. A method to enter unicode points in hex values.
    @objc optional func getIdentityMatrix() -> AdobeIllustratorMatrix // Returns an identity matrix
    @objc optional func getRotationMatrixAngle(_ angle: Double) -> AdobeIllustratorMatrix // Returns a rotation transformation matrix
    @objc optional func getScaleMatrixHorizontalScale(_ horizontalScale: Double, verticalScale: Double) -> AdobeIllustratorMatrix // Returns a scale transformation matrix
    @objc optional func getTranslationMatrixDeltaX(_ deltaX: Double, deltaY: Double) -> AdobeIllustratorMatrix // Returns a translation matrix
    @objc optional func copy() // Copy current selection to the clipboard
    @objc optional func cut() // Cut current selection to the clipboard
    @objc optional func doJavascript(_ x: Any!, withArguments: [Any]!, showDebugger: AdobeIllustratorE940) -> String // execute a javascript
    @objc optional func doScript(_ x: String!, from: String!, dialogs: Bool) // Play an action from the Actions Palette
    @objc optional func executeMenuCommandMenuCommandString(_ menuCommandString: String!) // executes a menu command using the menu shortcut string
    @objc optional func getPresetFileOfPresetType(_ presetType: AdobeIllustratorEDPT) -> URL // given a preset type, returns the full path to the application's default document profile for the type
    @objc optional func getPresetSettingsPreset(_ preset: String!) -> AdobeIllustratorDocumentPreset // given a preset name, tries and retrieves the settings from the preset template
    @objc optional func getSelectedToolName() -> String // return which tool is selected
    @objc optional func isFillActive() -> Bool // Checks if fill is active or not
    @objc optional func isPixelPerfect() -> Bool // check whether given art is pixel perfect or not
    @objc optional func isStrokeActive() -> Bool // Checks if stroke is active or not
    @objc optional func loadActionActionFilePath(_ actionFilePath: URL!) // Load an action into action palette
    @objc optional func openCloudLibraryAssetForEditingAsseturl(_ asseturl: URL!, thumbnailurl: URL!, assettype: String!, options: Any!) -> AdobeIllustratorDocument // For Internal Use
    @objc optional func paste() // Paste clipboard into the current document
    @objc optional func redo() // Redo the last transaction
    @objc optional func setThumbnailOptionsForCloudLibraryOptions(_ options: Any!) // For Internal Use
    @objc optional func undo() // Undo the last transaction
    @objc optional func unloadActionActionFilePath(_ actionFilePath: String!, actionFilePath: String!) // unloads an action into action palette
}
extension SBApplication: AdobeIllustratorApplication {}

// MARK: AdobeIllustratorDocument
@objc public protocol AdobeIllustratorDocument: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var colorProfileName: String { get } // The name of the color profile of the document
    @objc optional var colorSpace: AdobeIllustratorECCS { get } // the color space used for the document
    @objc optional var cropMarks: [Any] { get }
    @objc optional var cropStyle: AdobeIllustratorECRs { get }
    @objc optional var currentDataset: AdobeIllustratorDataset { get } // The active data set
    @objc optional var currentLayer: AdobeIllustratorLayer { get } // The active layer
    @objc optional var currentView: AdobeIllustratorView { get } // the document's current view
    @objc optional var defaultFillColor: AdobeIllustratorColorInfo { get } // default fill color
    @objc optional var defaultFillOverprint: Bool { get } // will art beneath a filled object be overprinted by default?
    @objc optional var defaultFilled: Bool { get } // should a new path be filled?
    @objc optional var defaultStrokeCap: AdobeIllustratorESTc { get } // default type of line capping
    @objc optional var defaultStrokeColor: AdobeIllustratorColorInfo { get } // default stroke color
    @objc optional var defaultStrokeDashOffset: Double { get } // the default distance into the dash pattern at which the pattern should be started
    @objc optional var defaultStrokeDashes: [Any] { get } // default dash lengths (set to {} for a solid line)
    @objc optional var defaultStrokeJoin: AdobeIllustratorESTj { get } // default type of joints
    @objc optional var defaultStrokeMiterLimit: Double { get } // specifies whether a join is mitered (pointed) or beveled (squared-off) by default
    @objc optional var defaultStrokeOverprint: Bool { get } // will art beneath a stroked object be overprinted by default?
    @objc optional var defaultStrokeWidth: Double { get } // default width of stroke
    @objc optional var defaultStroked: Bool { get } // should a new path be stroked?
    @objc optional var documentScaleFactor: Double { get } // The scale factor of the document
    @objc optional var filePath: URL { get } // the file associated with the document
    @objc optional var geometricBounds: [Any] { get } // the bounds of the illustration excluding stroke width
    @objc optional var height: Double { get }
    @objc optional var inks: [Any] { get } // the list of inks in this document
    @objc optional var KinsokuSet: [Any] { get } // the Kinsoku set
    @objc optional var modified: Bool { get } // Has the document been modified since the last save?
    @objc optional var MojikumiSet: [Any] { get } // the Mojikumi set
    @objc optional var name: String { get } // The document's name
    @objc optional var outputResolution: Double { get }
    @objc optional var pageOrigin: [Any] { get }
    @objc optional var printTiles: Bool { get }
    @objc optional var rasterEffectSettings: AdobeIllustratorRasterEffectOptions { get } // The document raster effects settings
    @objc optional var rulerOrigin: [Any] { get }
    @objc optional var rulerUnits: AdobeIllustratorERUt { get }
    @objc optional var selection: Any { get } // the selection within the document
    @objc optional var showPlacedImages: Bool { get }
    @objc optional var splitLongPaths: Bool { get }
    @objc optional var stationery: Bool { get } // Is the file a stationery file?
    @objc optional var tileFullPages: Bool { get }
    @objc optional var useDefaultScreen: Bool { get }
    @objc optional var variablesLocked: Bool { get } // The locked variables
    @objc optional var visibleBounds: [Any] { get } // the visible bounds of the illustration including stroke width
    @objc optional var width: Double { get }
    @objc optional var XMPString: String { get } // The XMP packet string associated with the document
    @objc optional func artboards() -> SBElementArray
    @objc optional func Assets() -> SBElementArray
    @objc optional func brushes() -> SBElementArray
    @objc optional func characterStyles() -> SBElementArray
    @objc optional func compoundPathItems() -> SBElementArray
    @objc optional func datasets() -> SBElementArray
    @objc optional func embededItems() -> SBElementArray
    @objc optional func gradients() -> SBElementArray
    @objc optional func graphicStyles() -> SBElementArray
    @objc optional func graphItems() -> SBElementArray
    @objc optional func gridRepeatItems() -> SBElementArray
    @objc optional func groupItems() -> SBElementArray
    @objc optional func layers() -> SBElementArray
    @objc optional func legacyTextItems() -> SBElementArray
    @objc optional func listStyles() -> SBElementArray
    @objc optional func meshItems() -> SBElementArray
    @objc optional func nonNativeItems() -> SBElementArray
    @objc optional func pageItems() -> SBElementArray
    @objc optional func paragraphStyles() -> SBElementArray
    @objc optional func pathItems() -> SBElementArray
    @objc optional func patterns() -> SBElementArray
    @objc optional func placedItems() -> SBElementArray
    @objc optional func pluginItems() -> SBElementArray
    @objc optional func radialRepeatItems() -> SBElementArray
    @objc optional func rasterItems() -> SBElementArray
    @objc optional func spots() -> SBElementArray
    @objc optional func stories() -> SBElementArray
    @objc optional func swatches() -> SBElementArray
    @objc optional func swatchgroups() -> SBElementArray
    @objc optional func symbolItems() -> SBElementArray
    @objc optional func symbols() -> SBElementArray
    @objc optional func symmetryRepeatItems() -> SBElementArray
    @objc optional func tags() -> SBElementArray
    @objc optional func textFrames() -> SBElementArray
    @objc optional func variables() -> SBElementArray
    @objc optional func views() -> SBElementArray
    @objc optional func closeSaving(_ saving: AdobeIllustratorSavo) // Close the specified document(s)
    @objc optional func converttolargecanvas() // Convert the document to Large Canvas Document
    @objc optional func saveIn(_ `in`: URL!, `as`: AdobeIllustratorEDCt, withOptions: Any!) -> AdobeIllustratorDocument // Save the specified document(s)
    @objc optional func captureTo(_ to: URL!, size: [Any]!) // capture the current document window to the target TIFF image file.
    @objc optional func convertcoordinateCoordinate(_ coordinate: [Any]!, source: AdobeIllustratorECoS, destination: AdobeIllustratorECoS) -> [Any] // Converts the coordinate system of a single point from one coordinate system to another.
    @objc optional func exportTo(_ to: URL!, `as`: AdobeIllustratorCEFT, withOptions: Any!) // Export the specified document(s)
    @objc optional func exportPerspectiveGridPresetTo(_ to: URL!) // saves all perspective grid presets to a file
    @objc optional func exportSelectedArtworkTo(_ to: URL!) // Export the selection as Ai file
    @objc optional func exportSelectionTo(_ to: URL!, withPNG24Options: Any!) // Export the selection as PNG file
    @objc optional func exportforscreensToFolder(_ toFolder: URL!, `as`: AdobeIllustratorEEFT, withOptions: Any!, itemtoexport: AdobeIllustratorItemToExport!, filenameprefix: String!) // Export the specified document/asset(s)/artboard(s)
    @objc optional func fitartboardtoselectedartIndex(_ index: Int) -> Bool // Change the artboard to selected art bounds.
    @objc optional func getPerspectiveActivePlane() -> AdobeIllustratorEPPt // Gets the active plane of the active perspective grid of the document
    @objc optional func hidePerspectiveGrid() -> Bool // Hides the current active perspective grid for the document, if there is visible perspective grid.
    @objc optional func importPerspectiveGridPresetFrom(_ from: URL!, perspectivePreset: String!) // loads mentioned perspective grid preset, if preset name is specified, else loads all(if no preset name is specified) presets, from the specified file
    @objc optional func importFileFrom(_ from: URL!, isLinked: Bool, libraryName: String!, itemName: String!, elementRef: String!, modifiedTime: Double, creationTime: Double, adobeStockId: String!, adobeStockLicense: String!, shouldLoadToPlacegun: Bool) // Import the file into current Ai document
    @objc optional func pageitemUsingUuidUuid(_ uuid: String!) -> AdobeIllustratorPageItem // Retrieves the pageitem using Uuid
    @objc optional func rasterizeSourceArt(_ sourceArt: Any!, inside: [Any]!, withOptions: AdobeIllustratorRasterizeOptions!) -> AdobeIllustratorPageItem // rasterize the source art(s) within the specified clip bounds. The source art(s) are disposed as a result of the rasterization.
    @objc optional func rearrangeartboardsArtboardLayout(_ artboardLayout: AdobeIllustratorEDAL, artboardRowsOrCols: Int, artboardSpacing: Double, artboardMoveArtwork: Bool) -> Bool // Rearrange Artboards in the document
    @objc optional func selectPerspectivePresetPerspectivePreset(_ perspectivePreset: String!) -> Bool // Selects a predefined preset to define grid for the current document.
    @objc optional func selectobjectsonactiveartboard() -> Bool // Select art objects in active artboard.
    @objc optional func setPerspectiveActivePlanePerspectiveGridPlane(_ perspectiveGridPlane: AdobeIllustratorEPPt) -> Bool // Sets the active perspective plane for the active grid of the document.
    @objc optional func showPerspectiveGrid() -> Bool // Shows the current active perspective grid for the document, if no active perspective grid then shows the default perspective grid for the document
    @objc optional func writeAsLibraryTo(_ to: URL!, `as`: AdobeIllustratorELib) // Write the document to a file as a library of specified type
    @objc optional func importCharacterStylesFrom(_ from: URL!) // load the character styles from the Illustrator file
    @objc optional func importParagraphStylesFrom(_ from: URL!) // load the paragraph styles from the Illustrator file
    @objc optional func exportPDFPresetTo(_ to: URL!) // save all PDF presets to a file
    @objc optional func importPDFPresetFrom(_ from: URL!, replacingPreset: Bool) // load all PDF presets from a file
    @objc optional func exportVariablesTo(_ to: URL!) // Save datasets into an XML library. The datasets contain variables and their associated dynamic data
    @objc optional func importVariablesFrom(_ from: URL!) // Import a library containing datasets, variables and their associated dynamic data. Importing variables will overwrite existing variables and datasets
    @objc optional func CheckWhetherViewIsClippedToArtboards() -> Bool // Check whether view is clipped to Artboards
    @objc optional func GetDeHighlightedObjectsCountInSmartEditingMode() -> Int // Get DeHighlighted Objects count in SmartEditing Mode
    @objc optional func GetHighlightedObjectsCountInSmartEditingMode() -> Int // Get Highlighted Objects count in SmartEditing Mode
    @objc optional func ReturnTrueIfSmartEditModeIsEnabledElseReturnFalse() -> Bool // Return true if SmartEdit Mode is enabled else return false
    @objc optional func exitIsolationMode() -> Bool // Exit Isolation Mode
    @objc optional func getPreviewMode() -> String // Returns preview mode
    @objc optional func getScreenModeVisible() -> String // Return which screen mode is visible
    @objc optional func getViewModeVisible() -> String // Returns the current view Mode
    @objc optional func getallbrushes() -> String // returns brushes in the Brush Panel
    @objc optional func getselectedbrushes() -> String // returns brushes selected in the Brush Panel
    @objc optional func isGridVisible() -> Bool // Check whether Grid is visible or not
    @objc optional func isGuideVisible() -> Bool // Check whether Guide is visible or not
    @objc optional func isPixelGridVisible() -> Bool // Check whether Pixel Grid is visible or not
    @objc optional func isSnapToGridEnabled() -> Bool // Check whether the Snap To Grid is enabled or not
    @objc optional func isOutlineMode() -> Bool // Is the outline mode enabled?
    @objc optional func isRulerVisible() -> Bool // Check whether the ruler is visible or not
    @objc optional func isTransparencyGrid() -> Bool // Check whether transparency grid is visible or not
    @objc optional func isTrimViewEnabled() -> Bool // Check whether the trim view is enabled or not
    @objc optional func isolateSelectedArt() -> Bool // Isolate the selected art
    @objc optional func exportPrintPresetTo(_ to: URL!) // export the current print setting to the preset file
    @objc optional func importPrintPresetPrintPreset(_ printPreset: String!, from: URL!) // apply the named print preset from the file to the current print setting
}
extension SBObject: AdobeIllustratorDocument {}

// MARK: AdobeIllustratorArtwork
@objc public protocol AdobeIllustratorArtwork: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var startupPreset: String { get } // The name of a startup document preset
    @objc optional var presetSettings: AdobeIllustratorDocumentPreset { get } // Custom settings to apply to the preset
    @objc optional var presetSettingsDialogOption: Bool { get } // If false, do not show Options dialog
}
extension SBObject: AdobeIllustratorArtwork {}

// MARK: AdobeIllustratorArtboard
@objc public protocol AdobeIllustratorArtboard: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var artboardRectangle: [Any] { get } // size and position of artboard
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The name of the artboard
    @objc optional var rulerOrigin: [Any] { get } // Ruler origin of artboard.It is relative to left-bottom corner of the Artboard.
    @objc optional var rulerPAR: Double { get } // Pixel aspect ratio, used in ruler visualization if the units are pixels ( 0.1 - 10.0 )
    @objc optional var showCenter: Bool { get } // Show center mark
    @objc optional var showCrossHairs: Bool { get } // Show cross hairs
    @objc optional var showSafeAreas: Bool { get } // Show title and action safe areas (for video)
    @objc optional func isArtboardVideoRulerVisible() -> Bool // Check whether the video ruler is visible or not
    @objc optional func isRulerCoordinateSystemChangeable() -> Bool // Check whether the Ruler Coordinate System can be changed or not
}
extension SBObject: AdobeIllustratorArtboard {}

// MARK: AdobeIllustratorBrush
@objc public protocol AdobeIllustratorBrush: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The brush's name
}
extension SBObject: AdobeIllustratorBrush {}

// MARK: AdobeIllustratorDimensionsInfo
@objc public protocol AdobeIllustratorDimensionsInfo: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var width: Double { get } // the Width parameter ( minimum 0.0 )
    @objc optional var height: Double { get } // the Height parameter ( minimum 0.0 )
}
extension SBObject: AdobeIllustratorDimensionsInfo {}

// MARK: AdobeIllustratorDocumentPreset
@objc public protocol AdobeIllustratorDocumentPreset: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var artboardLayout: AdobeIllustratorEDAL { get } // layout for artboards ( default: grid by row )
    @objc optional var artboardRowsOrCols: Int { get } // Number of rows (for rows layout) OR column(for column layouts)of artboards.Range is 1 to (docNumArtboards - 1) or 1 for single row or column layouts ( default: 1 )
    @objc optional var artboardSpacing: Double { get } // spacing between artboards ( default: 20.0 )
    @objc optional var colorMode: AdobeIllustratorECCS { get } // the color mode for the new document ( default: CMYK )
    @objc optional var documentBleedLink: Bool { get } // document link for bleed values ( default: true )
    @objc optional var documentBleedOffset: [Any] { get } // document bleed offset rect
    @objc optional var documentUnits: AdobeIllustratorERUt { get } // the units for the new document ( default: points )
    @objc optional var height: Double { get } // the height for the new document ( default: 792.0 )
    @objc optional var numArtboards: Int { get } // number of artboards for new document.Range (1:100). ( default: 1 )
    @objc optional var previewMode: AdobeIllustratorEDPM { get } // the preview mode for the new document ( default: default preview )
    @objc optional var rasterResolution: AdobeIllustratorEDCR { get } // the raster resolution for the new document ( default: screen resolution )
    @objc optional var title: String { get } // the title for the new document ( default: Untitled )
    @objc optional var transparencyGrid: AdobeIllustratorEDGR { get } // the transparency grid for the new document ( default: hide transparency grids )
    @objc optional var width: Double { get } // the width for the new document ( default: 612.0 )
}
extension SBObject: AdobeIllustratorDocumentPreset {}

// MARK: AdobeIllustratorGradient
@objc public protocol AdobeIllustratorGradient: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var entireGradient: [Any] { get } // all the gradient stops in the gradient
    @objc optional var gradientType: AdobeIllustratorEGDt { get } // the gradient type
    @objc optional var name: String { get } // the gradient's name
    @objc optional func gradientStops() -> SBElementArray
}
extension SBObject: AdobeIllustratorGradient {}

// MARK: AdobeIllustratorGradientStop
@objc public protocol AdobeIllustratorGradientStop: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var color: AdobeIllustratorColorInfo { get } // the color linked to this gradient stop
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var midpoint: Double { get } // midpoint key value in percent ( 13.0 - 87.0 )
    @objc optional var rampPoint: Double { get } // location of color in the blend (in percent) ( 0.0 - 100.0 )
    @objc optional var stopOpacity: Double { get } // The opacity (between 0.0 and 100.0) value for the gradient stop ( 0.0 - 100.0 )
}
extension SBObject: AdobeIllustratorGradientStop {}

// MARK: AdobeIllustratorGradientStopInfo
@objc public protocol AdobeIllustratorGradientStopInfo: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var color: AdobeIllustratorColorInfo { get } // the color linked to this gradient stop
    @objc optional var midpoint: Double { get } // midpoint value in percent ( 13.0 - 87.0; default: 50.0 )
    @objc optional var rampPoint: Double { get } // location of color in the blend in percent ( 0.0 - 100.0; default: 0.0 )
    @objc optional var stopOpacity: Double { get } // The opacity value for the gradient stop ( 0.0 - 100.0; default: 1.0 )
}
extension SBObject: AdobeIllustratorGradientStopInfo {}

// MARK: AdobeIllustratorGraphicStyle
@objc public protocol AdobeIllustratorGraphicStyle: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The art style's name
    @objc optional func applyTo(_ to: Any!) // Apply a brush or art style to object(s)
    @objc optional func mergeTo(_ to: Any!) // Merge an art style to object(s) current style(s)
}
extension SBObject: AdobeIllustratorGraphicStyle {}

// MARK: AdobeIllustratorIllustratorPreferences
@objc public protocol AdobeIllustratorIllustratorPreferences: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var AutoCADFileOptions: AdobeIllustratorAutoCADOptions { get } // options to use when opening or placing a AutoCAD file
    @objc optional var PDFFileOptions: AdobeIllustratorPDFOptions { get } // options to use when opening or placing a PDF file
    @objc optional var PhotoshopFileOptions: AdobeIllustratorPhotoshopOptions { get } // options to use when opening or placing a Photoshop file
    @objc optional func checkPreferenceExistsKey(_ key: String!) -> Bool // checks whether the application preference key exists
    @objc optional func deletePreferenceKey(_ key: String!) // delete the application preference key
    @objc optional func getBooleanPreferenceKey(_ key: String!) -> Bool // retrieve the value of the application preference key as boolean
    @objc optional func getIntegerPreferenceKey(_ key: String!) -> Int // retrieve the value of the application preference key as integer
    @objc optional func getRealPreferenceKey(_ key: String!) -> Double // retrieve the value of the application preference key as real number
    @objc optional func getStringPreferenceKey(_ key: String!) -> String // retrieve the value of the application preference key as string type
    @objc optional func setBooleanPreferenceKey(_ key: String!, to: Bool) // set the value of the application preference key as boolean
    @objc optional func setIntegerPreferenceKey(_ key: String!, to: Int) // set the value of the application preference key as integer
    @objc optional func setRealPreferenceKey(_ key: String!, to: Double) // set the value of the application preference key as real number
    @objc optional func setStringPreferenceKey(_ key: String!, to: String!) // set the value of the application preference key as string type
}
extension SBObject: AdobeIllustratorIllustratorPreferences {}

// MARK: AdobeIllustratorLayer
@objc public protocol AdobeIllustratorLayer: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var blendMode: AdobeIllustratorCBlM { get } // the mode used when compositing an object
    @objc optional var color: AdobeIllustratorRGBColorInfo { get } // color used when outlining artwork in this layer
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var dimPlacedImages: Bool { get } // Is rendered as dimmed in this layer?
    @objc optional var hasSelectedArtwork: Bool { get } // Is any artwork in this layer selected? Setting this property to false deselects all artwork in the layer.
    @objc optional var isolated: Bool { get } // is the artwork isolated
    @objc optional var knockout: AdobeIllustratorCKOS { get } // is the artwork used to create a knockout
    @objc optional var locked: Bool { get } // Is the layer editable?
    @objc optional var name: String { get } // The layer's name
    @objc optional var opacity: Double { get } // The layer's opacity (between 0.0 and 100.0)
    @objc optional var preview: Bool { get } // Is the layer rendered in preview mode?
    @objc optional var printable: Bool { get } // Is the layer printable?
    @objc optional var sliced: Bool { get } // Is the layer sliced (default: false)
    @objc optional var visible: Bool { get } // Is the layer visible?
    @objc optional func compoundPathItems() -> SBElementArray
    @objc optional func graphItems() -> SBElementArray
    @objc optional func gridRepeatItems() -> SBElementArray
    @objc optional func groupItems() -> SBElementArray
    @objc optional func layers() -> SBElementArray
    @objc optional func legacyTextItems() -> SBElementArray
    @objc optional func meshItems() -> SBElementArray
    @objc optional func nonNativeItems() -> SBElementArray
    @objc optional func pageItems() -> SBElementArray
    @objc optional func pathItems() -> SBElementArray
    @objc optional func placedItems() -> SBElementArray
    @objc optional func pluginItems() -> SBElementArray
    @objc optional func radialRepeatItems() -> SBElementArray
    @objc optional func rasterItems() -> SBElementArray
    @objc optional func symbolItems() -> SBElementArray
    @objc optional func symmetryRepeatItems() -> SBElementArray
    @objc optional func textFrames() -> SBElementArray
}
extension SBObject: AdobeIllustratorLayer {}

// MARK: AdobeIllustratorListStyle
@objc public protocol AdobeIllustratorListStyle: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The list style's full name
}
extension SBObject: AdobeIllustratorListStyle {}

// MARK: AdobeIllustratorPageItem
@objc public protocol AdobeIllustratorPageItem: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var blendMode: AdobeIllustratorCBlM { get } // the mode used when compositing an object
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var controlBounds: [Any] { get } // the bounds of the artwork including stroke width and controls
    @objc optional var editable: Bool { get } // can the art item be modified
    @objc optional var geometricBounds: [Any] { get } // the bounds of the artwork excluding stroke width
    @objc optional var height: Double { get } // the height of the art item ( 0.0 - 16348.0 )
    @objc optional var hidden: Bool { get } // is this artwork item hidden?
    @objc optional var isolated: Bool { get } // is the artwork isolated
    @objc optional var knockout: AdobeIllustratorCKOS { get } // is the artwork used to create a knockout
    @objc optional var layer: AdobeIllustratorLayer { get } // the layer to which this artwork belongs
    @objc optional var locked: Bool { get } // is this artwork item locked?
    @objc optional var name: String { get } // The item's name
    @objc optional var note: String { get } // the note assigned to this artwork item
    @objc optional var opacity: Double { get } // the object's opacity (between 0.0 and 100.0) ( 0.0 - 100.0 )
    @objc optional var pixelAligned: Bool { get } // is this artwork item aligned to Pixel Grid?
    @objc optional var position: [Any] { get } // the position of the top left corner of the art item
    @objc optional var selected: Bool { get } // is this artwork item selected?
    @objc optional var sliced: Bool { get } // is the art item sliced (default: false)
    @objc optional var URL: String { get } // the value of the Adobe URL tag assigned to this artwork item
    @objc optional var uuid: String { get } // The item's unique identifier
    @objc optional var visibilityVariable: Any { get } // the visibility variable bound to this page item
    @objc optional var visibleBounds: [Any] { get } // the visible bounds of the artwork including stroke width
    @objc optional var width: Double { get } // the width of the art item ( 0.0 - 16348.0 )
    @objc optional var wrapInside: Bool { get } // should the text frame object be wrapped inside this object?
    @objc optional var wrapOffset: Double { get } // use this offset when wrapping text around this object
    @objc optional var wrapped: Bool { get } // wrap text frame objects around this object (text frame must be above the object)
    @objc optional func tags() -> SBElementArray
    @objc optional func applyeffectLiveeffectxml(_ liveeffectxml: String!) // Apply effect to selected artItem
    @objc optional func bringInPerspectivePositionX(_ positionX: Double, positionY: Double, perspectiveGridPlane: AdobeIllustratorEPPt) // Place art object(s)in perspective grid at spedified perspective plane and coordinate
    @objc optional func canparallelexecutionrunLiveeffectxml(_ liveeffectxml: String!) -> Bool // Apply effect in parallel to supported artItem
    @objc optional func rotateAngle(_ angle: Double, transformingObjects: Bool, transformingFillPatterns: Bool, transformingFillGradients: Bool, transformingStrokePatterns: Bool, about: AdobeIllustratorETRt) // Rotate art object(s)
    @objc optional func scaleHorizontalScale(_ horizontalScale: Double, verticalScale: Double, transformingObjects: Bool, transformingFillPatterns: Bool, transformingFillGradients: Bool, transformingStrokePatterns: Bool, lineScale: Double, about: AdobeIllustratorETRt) // Scale art object(s)
    @objc optional func translateDeltaX(_ deltaX: Double, deltaY: Double, transformingObjects: Bool, transformingFillPatterns: Bool, transformingFillGradients: Bool, transformingStrokePatterns: Bool) // Reposition art object(s)
    @objc optional func transformUsing(_ using: AdobeIllustratorMatrix!, transformingObjects: Bool, transformingFillPatterns: Bool, transformingFillGradients: Bool, transformingStrokePatterns: Bool, lineScale: Double, about: AdobeIllustratorETRt) // Transform art object(s) using a transformation matrix
    @objc optional func SendScriptMessageActionPluginName(_ pluginName: String!, messageSelector: String!, parameterString: String!) -> String // sends the script message to the required plugin
}
extension SBObject: AdobeIllustratorPageItem {}

// MARK: AdobeIllustratorCompoundPathItem
@objc public protocol AdobeIllustratorCompoundPathItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional func pathItems() -> SBElementArray
}
extension SBObject: AdobeIllustratorCompoundPathItem {}

// MARK: AdobeIllustratorEmbeddedItem
@objc public protocol AdobeIllustratorEmbeddedItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var filePath: URL { get } // the file containing the placed artwork
}
extension SBObject: AdobeIllustratorEmbeddedItem {}

// MARK: AdobeIllustratorGraphItem
@objc public protocol AdobeIllustratorGraphItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var contentVariable: Any { get } // the content variable bound to this graph
}
extension SBObject: AdobeIllustratorGraphItem {}

// MARK: AdobeIllustratorGroupItem
@objc public protocol AdobeIllustratorGroupItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var clipped: Bool { get } // are the group elements clipped to the clipping path?
    @objc optional func compoundPathItems() -> SBElementArray
    @objc optional func graphItems() -> SBElementArray
    @objc optional func gridRepeatItems() -> SBElementArray
    @objc optional func groupItems() -> SBElementArray
    @objc optional func legacyTextItems() -> SBElementArray
    @objc optional func meshItems() -> SBElementArray
    @objc optional func nonNativeItems() -> SBElementArray
    @objc optional func pageItems() -> SBElementArray
    @objc optional func pathItems() -> SBElementArray
    @objc optional func placedItems() -> SBElementArray
    @objc optional func pluginItems() -> SBElementArray
    @objc optional func radialRepeatItems() -> SBElementArray
    @objc optional func rasterItems() -> SBElementArray
    @objc optional func symbolItems() -> SBElementArray
    @objc optional func symmetryRepeatItems() -> SBElementArray
    @objc optional func textFrames() -> SBElementArray
    @objc optional func isdimensionart() -> Bool // Is this Dimension Art Group?
}
extension SBObject: AdobeIllustratorGroupItem {}

// MARK: AdobeIllustratorLegacyTextItem
@objc public protocol AdobeIllustratorLegacyTextItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var converted: Bool { get } // has the legacy text item been updated to a native text frame item?
    @objc optional func convert() -> AdobeIllustratorGroupItem // create a native text frame from a legacy text item. The original legacy text item is deleted.
}
extension SBObject: AdobeIllustratorLegacyTextItem {}

// MARK: AdobeIllustratorMeshItem
@objc public protocol AdobeIllustratorMeshItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
}
extension SBObject: AdobeIllustratorMeshItem {}

// MARK: AdobeIllustratorNonNativeItem
@objc public protocol AdobeIllustratorNonNativeItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
}
extension SBObject: AdobeIllustratorNonNativeItem {}

// MARK: AdobeIllustratorPathItem
@objc public protocol AdobeIllustratorPathItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var area: Double { get } // the area of this path in square points
    @objc optional var clipping: Bool { get } // should this be used as a clipping path?
    @objc optional var closed: Bool { get } // is this path closed?
    @objc optional var entirePath: [Any] { get } // all the path item's path points
    @objc optional var evenodd: Bool { get } // should the even-odd rule be used to determine insideness?
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // fill color
    @objc optional var fillOverprint: Bool { get } // will art beneath a filled object be overprinted?
    @objc optional var filled: Bool { get } // should the path be filled?
    @objc optional var guides: Bool { get } // is this path a guide object?
    @objc optional var length: Double { get } // the length of this path in points
    @objc optional var polarity: AdobeIllustratorEPVu { get } // the polarity the path
    @objc optional var resolution: Double { get } // The resolution of the path
    @objc optional var selectedPathPoints: [Any] { get } // all the selected points in the path
    @objc optional var strokeCap: AdobeIllustratorESTc { get } // type of line capping
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // stroke color
    @objc optional var strokeDashOffset: Double { get } // the default distance into the dash pattern at which the pattern should be started
    @objc optional var strokeDashes: [Any] { get } // dash lengths (set to {} for a solid line)
    @objc optional var strokeJoin: AdobeIllustratorESTj { get } // type of joints
    @objc optional var strokeMiterLimit: Double { get } // whether a join is mitered (pointed) or beveled (squared-off)
    @objc optional var strokeOverprint: Bool { get } // will art beneath a stroked object be overprinted?
    @objc optional var strokeWidth: Double { get } // width of stroke
    @objc optional var stroked: Bool { get } // should the path be stroked?
    @objc optional func pathPoints() -> SBElementArray
}
extension SBObject: AdobeIllustratorPathItem {}

// MARK: AdobeIllustratorPathPoint
@objc public protocol AdobeIllustratorPathPoint: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var anchor: [Any] { get } // the position (coordinates) of the anchor point
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var leftDirection: [Any] { get } // location of the left direction point (in position)
    @objc optional var pointType: AdobeIllustratorEPTy { get } // the type of point: smooth/corner
    @objc optional var rightDirection: [Any] { get } // location of the right direction point (out position)
    @objc optional var selected: AdobeIllustratorESGs { get } // the path point selected state
}
extension SBObject: AdobeIllustratorPathPoint {}

// MARK: AdobeIllustratorPathPointInfo
@objc public protocol AdobeIllustratorPathPointInfo: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var anchor: [Any] { get } // the position of the anchor (in coordinates)
    @objc optional var leftDirection: [Any] { get } // location of the left direction point (in position)
    @objc optional var pointType: AdobeIllustratorEPTy { get } // the point type, smooth/corner ( default: smooth )
    @objc optional var rightDirection: [Any] { get } // location of the left direction point (out position)
}
extension SBObject: AdobeIllustratorPathPointInfo {}

// MARK: AdobeIllustratorPlacedItem
@objc public protocol AdobeIllustratorPlacedItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var boundingBox: [Any] { get } // dimensions of placed art object, regardless of transformations
    @objc optional var contentVariable: Any { get } // the content variable bound to this placed art object
    @objc optional var filePath: URL { get } // the file containing the placed artwork
    @objc optional var matrix: AdobeIllustratorMatrix { get } // The transformation matrix of the placed art object
    @objc optional func embed() // Embed the placed art within the illustration
    @objc optional func relinkFrom(_ from: URL!) // Relink the placed art with supplied art from file
    @objc optional func tracePlaced() -> AdobeIllustratorPluginItem // Trace this raster object using default options.  Reorders this placed to the source art.
}
extension SBObject: AdobeIllustratorPlacedItem {}

// MARK: AdobeIllustratorPluginItem
@objc public protocol AdobeIllustratorPluginItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var isTracing: Bool { get } // is the plugin group a tracing?
    @objc optional var tracing: AdobeIllustratorTracingobject { get } // the tracing object associated with this plugin item.
}
extension SBObject: AdobeIllustratorPluginItem {}

// MARK: AdobeIllustratorRasterEffectOptions
@objc public protocol AdobeIllustratorRasterEffectOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: Bool { get } // should the resulting image be antialiased ( default: false )
    @objc optional var clippingMask: Bool { get } // should a clipping mask be created for the resulting image ( default: false )
    @objc optional var colorModel: AdobeIllustratorERAS { get } // The color model for the rasterization ( default: default rasterization )
    @objc optional var convertSpotColors: Bool { get } // whether to convert all spot colors to process colors in the resulting image ( default: false )
    @objc optional var padding: Double { get } // the amount of white space (in points) to be added around the object during rasterization ( default: 0.0 )
    @objc optional var resolution: Double { get } // The rasterization resolution in dots-per-inch (dpi) ( 72.0 - 2400.0; default: 300.0 )
    @objc optional var transparency: Bool { get } // should the resulting image use transparency ( default: false )
}
extension SBObject: AdobeIllustratorRasterEffectOptions {}

// MARK: AdobeIllustratorRasterItem
@objc public protocol AdobeIllustratorRasterItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var bitsPerChannel: Int { get } // the number of bits per channel
    @objc optional var boundingBox: [Any] { get } // dimensions of raster art object regardless of transformations
    @objc optional var channels: Int { get } // the number of image channels
    @objc optional var colorSpace: AdobeIllustratorECLS { get } // the color space of the raster image
    @objc optional var colorants: [Any] { get } // list of colorant names
    @objc optional var colorized: Bool { get } // is the raster art a colorized grayscale image?
    @objc optional var contentVariable: Any { get } // the content variable bound to this raster art object
    @objc optional var embedded: Bool { get } // is the raster art embedded within the illustration?
    @objc optional var filePath: URL { get } // the file containing the raster artwork
    @objc optional var matrix: AdobeIllustratorMatrix { get } // The transformation matrix of the raster art object
    @objc optional var overprint: Bool { get } // is the raster art overprinting?
    @objc optional var status: AdobeIllustratorERLt { get } // status of the linked image
    @objc optional var transparent: Bool { get } // is the raster art transparent?
    @objc optional func colorizeRasterColor(_ rasterColor: AdobeIllustratorColorInfo!) // Colorize the RasterItem with a CMYK or RGB Color
    @objc optional func traceRaster() -> AdobeIllustratorPluginItem // Trace this raster object using default options.  Reorders this raster to the source art.
}
extension SBObject: AdobeIllustratorRasterItem {}

// MARK: AdobeIllustratorRasterizeOptions
@objc public protocol AdobeIllustratorRasterizeOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasingMethod: AdobeIllustratorEALS { get } // the type of antialiasing method ( default: art optimized )
    @objc optional var backgroundBlack: Bool { get } // should rasterize against a black background instead of white ( default: false )
    @objc optional var clippingMask: Bool { get } // should a clipping mask be created for the resulting image ( default: false )
    @objc optional var colorModel: AdobeIllustratorERAS { get } // The color model for the rasterization ( default: default rasterization )
    @objc optional var convertSpotColors: Bool { get } // whether to convert all spot colors to process colors in the resulting image ( default: false )
    @objc optional var convertTextToOutlines: Bool { get } // should all text be converted to outlines before rasterization ( default: false )
    @objc optional var includeLayers: Bool { get } // should the resulting image incorporates the layer attributes (such as opacity and blend mode) ( default: false )
    @objc optional var padding: Double { get } // the amount of white space (in points) to be added around the object during rasterization ( default: 0.0 )
    @objc optional var resolution: Double { get } // The rasterization resolution in dots-per-inch (dpi) ( 72.0 - 2400.0; default: 300.0 )
    @objc optional var transparency: Bool { get } // should the resulting image use transparency ( default: false )
}
extension SBObject: AdobeIllustratorRasterizeOptions {}

// MARK: AdobeIllustratorSymbol
@objc public protocol AdobeIllustratorSymbol: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The symbol's name
    @objc optional var sourceArt: Any { get } // The source art is only used when creating a new symbol
}
extension SBObject: AdobeIllustratorSymbol {}

// MARK: AdobeIllustratorSymbolItem
@objc public protocol AdobeIllustratorSymbolItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var symbol: AdobeIllustratorSymbol { get } // The symbol that was used to create this symbol item
}
extension SBObject: AdobeIllustratorSymbolItem {}

// MARK: AdobeIllustratorTabStopInfo
@objc public protocol AdobeIllustratorTabStopInfo: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var alignment: AdobeIllustratorETBa { get } // the alignment of the tab stop ( default: left )
    @objc optional var decimalCharacter: String { get } // the character used for decimal tab stops ( default: . )
    @objc optional var leader: String { get } // the leader dot
    @objc optional var position: Double { get } // the position of the tab stop expressed in points ( default: 0.0 )
}
extension SBObject: AdobeIllustratorTabStopInfo {}

// MARK: AdobeIllustratorTag
@objc public protocol AdobeIllustratorTag: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The tag's name
    @objc optional var value: String { get } // the data stored in this tag
}
extension SBObject: AdobeIllustratorTag {}

// MARK: AdobeIllustratorTextFrame
@objc public protocol AdobeIllustratorTextFrame: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var anchor: [Any] { get } // the position of the anchor point (start of base line for point text)
    @objc optional var antialias: AdobeIllustratorETAa { get } // the type of a text anti-aliasing on text frame item
    @objc optional var columnCount: Int { get } // the column count in the text frame (area text only)
    @objc optional var columnGutter: Double { get } // the column gutter in the text frame (area text only)
    @objc optional var contentVariable: Any { get } // the content variable bound to this text art item
    @objc optional var contents: String { get } // the text contents of this text frame
    @objc optional var endTValue: Double { get } // the end position of text along a path, as a value relative to the path's segments (path text only)
    @objc optional var firstBaseline: AdobeIllustratorEFBT { get } // the first baseline offset type for text frame item (for Area Text only)
    @objc optional var firstBaselineMin: Double { get } // the first baseline offset minimum value for text frame item (for Area Text only)
    @objc optional var flowLinksHorizontally: Bool { get } // Flow text between linked frame horizontally first. (area text only)
    @objc optional var kind: AdobeIllustratorETXt { get } // the type of a text frame item
    @objc optional var matrix: AdobeIllustratorMatrix { get } // The transformation matrix of the text frame object
    @objc optional var nextFrame: AdobeIllustratorTextFrame { get } // the linked text frame following this one
    @objc optional var opticalAlignment: Bool { get } // is the optical alignment active?
    @objc optional var previousFrame: AdobeIllustratorTextFrame { get } // the linked text frame preceding this one
    @objc optional var rowCount: Int { get } // the row count in the text frame (area text only)
    @objc optional var rowGutter: Double { get } // the row gutter in the text frame (area text only)
    @objc optional var selection: [Any] { get } // the selected text (ranges) in the story
    @objc optional var spacing: Double { get } // the amount of spacing (path text only)
    @objc optional var startTValue: Double { get } // the start position of text along a path, as a value relative to the path's segments (path text only)
    @objc optional var story: AdobeIllustratorStory { get } // the story of the text frame
    @objc optional var textOrientation: AdobeIllustratorETXo { get } // the orientation of the text in the frame
    @objc optional var textPath: AdobeIllustratorTextPath { get } // the path for the text frame (area and path text)
    @objc optional var textRange: AdobeIllustratorText { get } // the text range of the text frame
    @objc optional func characters() -> SBElementArray
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional func convertAreaObjectToPointObject() -> AdobeIllustratorTextFrame // Convert Area Type Text Object To Point Type Object
    @objc optional func convertPointObjectToAreaObject() -> AdobeIllustratorTextFrame // Convert Point Type Text Object To Area Type Object
    @objc optional func convertToPaths() -> AdobeIllustratorGroupItem // Convert text item to path items
    @objc optional func generateThumbnailWithTextFramePropertiesTextString(_ textString: String!, fontSize: Double, textColor: AdobeIllustratorColorInfo!, destinationPath: URL!) // Generates the thumbnail with the properties of first character in the text frame
}
extension SBObject: AdobeIllustratorTextFrame {}

// MARK: AdobeIllustratorView
@objc public protocol AdobeIllustratorView: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var bounds: [Any] { get } // the bounding rectangle of this view
    @objc optional var centerPoint: [Any] { get } // the center point of this view
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var rotateangle: Double { get } // the rotation angle of this view
    @objc optional var screenMode: AdobeIllustratorESCM { get } // the mode of display
    @objc optional var visibleZoom: Double { get } // the zoom factor of this view that is visible to user
    @objc optional var zoom: Double { get } // the zoom factor of this view
    @objc optional func setscreenmodeSmd(_ smd: AdobeIllustratorESCM) -> Bool // set the mode of screen
}
extension SBObject: AdobeIllustratorView {}

// MARK: AdobeIllustratorColorInfo
@objc public protocol AdobeIllustratorColorInfo: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional func showColorPicker() -> AdobeIllustratorColorInfo // Invokes application's color picker
}
extension SBObject: AdobeIllustratorColorInfo {}

// MARK: AdobeIllustratorCMYKColorInfo
@objc public protocol AdobeIllustratorCMYKColorInfo: AdobeIllustratorColorInfo {
    @objc optional var cyan: Double { get } // the cyan color value (between 0.0 and 100.0) ( 0.0 - 100.0; default: 0.0 )
    @objc optional var magenta: Double { get } // the magenta color value (between 0.0 and 100.0) ( 0.0 - 100.0; default: 0.0 )
    @objc optional var yellow: Double { get } // the yellow color value (between 0.0 and 100.0) ( 0.0 - 100.0; default: 0.0 )
    @objc optional var black: Double { get } // the black color value (between 0.0 and 100.0) ( 0.0 - 100.0; default: 0.0 )
}
extension SBObject: AdobeIllustratorCMYKColorInfo {}

// MARK: AdobeIllustratorGradientColorInfo
@objc public protocol AdobeIllustratorGradientColorInfo: AdobeIllustratorColorInfo {
    @objc optional var angle: Double { get } // the gradient vector angle ( default: 0.0 )
    @objc optional var gradient: AdobeIllustratorGradient { get } // reference to the object defining the gradient
    @objc optional var hiliteAngle: Double { get } // the gradient hilite vector angle ( default: 0.0 )
    @objc optional var hiliteLength: Double { get } // the gradient hilite vector length ( default: 0.0 )
    @objc optional var length: Double { get } // the gradient vector length ( default: 0.0 )
    @objc optional var matrix: AdobeIllustratorMatrix { get } // additional transformation arising from manipulating the path
    @objc optional var origin: [Any] { get } // the gradient vector origin
}
extension SBObject: AdobeIllustratorGradientColorInfo {}

// MARK: AdobeIllustratorGrayColorInfo
@objc public protocol AdobeIllustratorGrayColorInfo: AdobeIllustratorColorInfo {
    @objc optional var grayValue: Double { get } // the gray value (between 0.0 and 100.0) ( 0.0 - 100.0; default: 0.0 )
}
extension SBObject: AdobeIllustratorGrayColorInfo {}

// MARK: AdobeIllustratorLabColorInfo
@objc public protocol AdobeIllustratorLabColorInfo: AdobeIllustratorColorInfo {
    @objc optional var l: Double { get } // the L color value (between 0.0 and 100.0) ( 0.0 - 100.0; default: 0.0 )
    @objc optional var a: Double { get } // the a color value (between -128.0 and 127.0) ( -128.0 - 127.0; default: 0.0 )
    @objc optional var b: Double { get } // the b color value (between -128.0 and 127.0) ( -128.0 - 127.0; default: 0.0 )
}
extension SBObject: AdobeIllustratorLabColorInfo {}

// MARK: AdobeIllustratorNoColorInfo
@objc public protocol AdobeIllustratorNoColorInfo: AdobeIllustratorColorInfo {
}
extension SBObject: AdobeIllustratorNoColorInfo {}

// MARK: AdobeIllustratorPattern
@objc public protocol AdobeIllustratorPattern: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The pattern's name
}
extension SBObject: AdobeIllustratorPattern {}

// MARK: AdobeIllustratorPatternColorInfo
@objc public protocol AdobeIllustratorPatternColorInfo: AdobeIllustratorColorInfo {
    @objc optional var matrix: AdobeIllustratorMatrix { get } // additional transformation arising from manipulating the path
    @objc optional var pattern: AdobeIllustratorPattern { get }
    @objc optional var reflect: Bool { get } // whether or not the prototype is reflected before filling ( default: false )
    @objc optional var reflectAngle: Double { get } // the axis around which to reflect ( default: 0.0 )
    @objc optional var rotation: Double { get } // the angle to rotate the before filling ( default: 0.0 )
    @objc optional var scaleFactor: [Any] { get } // the fraction to scale the prototype before filling
    @objc optional var shearAngle: Double { get } // the angle to slant the shear by ( default: 0.0 )
    @objc optional var shearAxis: Double { get } // the axis to shear with respect to ( default: 0.0 )
    @objc optional var shiftAngle: Double { get } // the angle to translate the (unscaled) prototype before filling ( default: 0.0 )
    @objc optional var shiftDistance: Double { get } // the distance to translate the (unscaled) prototype before filling ( default: 0.0 )
}
extension SBObject: AdobeIllustratorPatternColorInfo {}

// MARK: AdobeIllustratorRGBColorInfo
@objc public protocol AdobeIllustratorRGBColorInfo: AdobeIllustratorColorInfo {
    @objc optional var red: Double { get } // the red color value (between 0.0 and 255.0) ( 0.0 - 255.0; default: 0.0 )
    @objc optional var green: Double { get } // the green color value (between 0.0 and 255.0) ( 0.0 - 255.0; default: 0.0 )
    @objc optional var blue: Double { get } // the blue color value (between 0.0 and 255.0) ( 0.0 - 255.0; default: 0.0 )
}
extension SBObject: AdobeIllustratorRGBColorInfo {}

// MARK: AdobeIllustratorSpot
@objc public protocol AdobeIllustratorSpot: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var color: AdobeIllustratorColorInfo { get }
    @objc optional var colorType: AdobeIllustratorECMd { get } // Type of the custom color
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The custom color's name
    @objc optional var spotKind: AdobeIllustratorESCk { get } // Kind of the spot color (i.e. RGB, CMYK or LAB), it is the name of color kind contained in spot
    @objc optional func getInternalColor() -> [Any] // Gets the internal color of a spot.
}
extension SBObject: AdobeIllustratorSpot {}

// MARK: AdobeIllustratorSpotColorInfo
@objc public protocol AdobeIllustratorSpotColorInfo: AdobeIllustratorColorInfo {
    @objc optional var spot: AdobeIllustratorSpot { get }
    @objc optional var tint: Double { get } // percentage level of tint to be applied to the spot color ( 0.0 - 100.0; default: 100.0 )
}
extension SBObject: AdobeIllustratorSpotColorInfo {}

// MARK: AdobeIllustratorSwatch
@objc public protocol AdobeIllustratorSwatch: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var color: AdobeIllustratorColorInfo { get } // the color information of the swatch
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // The swatch's name
}
extension SBObject: AdobeIllustratorSwatch {}

// MARK: AdobeIllustratorSwatchgroup
@objc public protocol AdobeIllustratorSwatchgroup: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // Name of the swatch group
    @objc optional func addSpotSpot(_ spot: AdobeIllustratorSpot!) // Add a spot swatch to the group
    @objc optional func addSwatchSwatch(_ swatch: AdobeIllustratorSwatch!) // Add a swatch to the group
    @objc optional func getAllSwatches() -> [Any] // get all swatches in the swatch group
}
extension SBObject: AdobeIllustratorSwatchgroup {}

// MARK: AdobeIllustratorCharacter
@objc public protocol AdobeIllustratorCharacter: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var OpenTypePosition: AdobeIllustratorCOTP { get } // the OpenType baseline position
    @objc optional var TCYHorizontal: Int { get } // the Tate-Chu-Yoko horizontal adjustment in points
    @objc optional var TCYVertical: Int { get } // the Tate-Chu-Yoko vertical adjustment in points
    @objc optional var Tsume: Double { get } // the percentage of space reduction around a Japanese character (100 = 100%)
    @objc optional var akiLeft: Double { get } // the em amount of left aki
    @objc optional var akiRight: Double { get } // the em amount of right aki amount
    @objc optional var alignment: AdobeIllustratorESRA { get } // the character alignment type
    @objc optional var alternateGlyphs: AdobeIllustratorEAGF { get } // the alternate glyphs form
    @objc optional var autoLeading: Bool { get } // whether to use automatic leading
    @objc optional var baselineDirection: AdobeIllustratorEBSD { get } // the Japanese text baseline direction
    @objc optional var baselinePosition: AdobeIllustratorEFBO { get } // the baseline position of text
    @objc optional var baselineShift: Double { get } // the amount of shift (in points) of the text baseline
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var capitalization: AdobeIllustratorEFCO { get } // the case of text
    @objc optional var characterOffset: Int { get } // offset of the first character of the range from the beginning of the story, in characters.
    @objc optional var connectionForms: Bool { get } // whether the OpenType connection forms should be used
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var contents: String { get } // the text string
    @objc optional var contextualLigature: Bool { get } // whether the contextual ligature should be used
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var diacXOffset: Double { get } // diacritics x offset attribute
    @objc optional var diacYOffset: Double { get } // diacritics y offset attribute
    @objc optional var diacriticsPositioning: AdobeIllustratorEDVP { get } // diacritics positioning attribute
    @objc optional var digitSet: AdobeIllustratorEDgS { get } // digit set attribute
    @objc optional var directionOverride: AdobeIllustratorEDOT { get } // direction override attribute
    @objc optional var discretionaryLigature: Bool { get } // whether the discretionary ligature should be used
    @objc optional var end: Int { get } // end index of the text range
    @objc optional var figureStyle: AdobeIllustratorCFST { get } // which figure style to use in OpenType font
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // the color of the text fill
    @objc optional var fractions: Bool { get } // whether the OpenType fractions should be used
    @objc optional var horizontalScale: Double { get } // character horizontal scaling factor expressed as a percentage (100 = 100%)
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var italics: Bool { get } // does the Japanese OpenType support italics?
    @objc optional var justificationAlternates: Bool { get } // justification alternates attribute
    @objc optional var kana: Bool { get } // does the Japanese OpenType support kana?
    @objc optional var kashidas: AdobeIllustratorEKas { get } // kashidas attribute
    @objc optional var kerning: Int { get } // controls the spacing between two characters (in milli-ems)
    @objc optional var kerningMethod: AdobeIllustratorEATK { get } // the automatic kerning method to use
    @objc optional var language: AdobeIllustratorELNG { get } // the language of text
    @objc optional var leading: Double { get } // the amount of space between two lines of text (in points)
    @objc optional var length: Int { get } // length of text range ( minimum 0 )
    @objc optional var ligature: Bool { get } // whether the ligature should be used
    @objc optional var noBreak: Bool { get } // whether line breaks are allowed
    @objc optional var ordinals: Bool { get } // whether the OpenType ordinals should be used
    @objc optional var ornaments: Bool { get } // whether the OpenType ornaments should be used
    @objc optional var overprintFill: Bool { get } // whether to overprint the fill of the text
    @objc optional var overprintStroke: Bool { get } // whether to overprint the stroke of the text
    @objc optional var proportionalMetrics: Bool { get } // does the Japanese OpenType support proportional font?
    @objc optional var rotation: Double { get } // the character rotation angle (in degrees)
    @objc optional var selection: [Any] { get } // the selected text (ranges) in the text range
    @objc optional var size: Double { get } // font size in points
    @objc optional var start: Int { get } // start index of the text range
    @objc optional var story: AdobeIllustratorStory { get } // the story of the text range
    @objc optional var strikeThrough: Bool { get } // whether to draw a strike through line over the text
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // the color of the text stroke
    @objc optional var strokeWeight: Double { get } // line width of stroke
    @objc optional var stylisticAlternates: Bool { get } // whether the OpenType stylistic alternates should be used
    @objc optional var stylisticSets: Int { get } // stylistic sets attribute
    @objc optional var swash: Bool { get } // whether the OpenType swash should be used
    @objc optional var textFont: Any { get } // the text font
    @objc optional var titling: Bool { get } // whether the OpenType titling alternates should be used
    @objc optional var tracking: Int { get } // the tracking or range kerning amount in thousands of an em
    @objc optional var underline: Bool { get } // whether to underline the text
    @objc optional var verticalScale: Double { get } // character vertical scaling factor expressed as a percentage (100 = 100%)
    @objc optional var warichuCharactersAfterBreak: Int { get }
    @objc optional var warichuCharactersBeforeBreak: Int { get }
    @objc optional var warichuEnabled: Bool { get } // whether WariChu is enabled
    @objc optional var warichuGap: Int { get } // the Wari-Chu line gap
    @objc optional var warichuJustification: AdobeIllustratorEWCJ { get }
    @objc optional var warichuLines: Int { get } // the number of Wari-Chu (multiple text lines fit into a space meant for one) lines
    @objc optional var warichuScale: Double { get } // the Wari-Chu scale
    @objc optional func characterStyles() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphStyles() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AdobeIllustratorCharacter {}

// MARK: AdobeIllustratorCharacterStyle
@objc public protocol AdobeIllustratorCharacterStyle: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var akiLeft: Double { get } // the em amount of left aki
    @objc optional var akiRight: Double { get } // the em amount of right aki amount
    @objc optional var alignment: AdobeIllustratorESRA { get } // the character alignment type
    @objc optional var alternateGlyphs: AdobeIllustratorEAGF { get } // the alternate glyphs form
    @objc optional var autoLeading: Bool { get } // whether to use automatic leading
    @objc optional var baselineDirection: AdobeIllustratorEBSD { get } // the Japanese text baseline direction
    @objc optional var baselinePosition: AdobeIllustratorEFBO { get } // the baseline position of text
    @objc optional var baselineShift: Double { get } // the amount of shift (in points) of the text baseline
    @objc optional var capitalization: AdobeIllustratorEFCO { get } // the case of text
    @objc optional var connectionForms: Bool { get } // whether the OpenType connection forms should be used
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var contextualLigature: Bool { get } // whether the contextual ligature should be used
    @objc optional var diacXOffset: Double { get } // diacritics x offset attribute
    @objc optional var diacYOffset: Double { get } // diacritics y offset attribute
    @objc optional var diacriticsPositioning: AdobeIllustratorEDVP { get } // diacritics positioning attribute
    @objc optional var digitSet: AdobeIllustratorEDgS { get } // digit set attribute
    @objc optional var directionOverride: AdobeIllustratorEDOT { get } // direction override attribute
    @objc optional var discretionaryLigature: Bool { get } // whether the discretionary ligature should be used
    @objc optional var figureStyle: AdobeIllustratorCFST { get } // which figure style to use in OpenType font
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // the color of the text fill
    @objc optional var fractions: Bool { get } // whether the OpenType fractions should be used
    @objc optional var horizontalScale: Double { get } // character horizontal scaling factor expressed as a percentage (100 = 100%)
    @objc optional var italics: Bool { get } // does the Japanese OpenType support italics?
    @objc optional var justificationAlternates: Bool { get } // justification alternates attribute
    @objc optional var kana: Bool { get } // does the Japanese OpenType support kana?
    @objc optional var kashidas: AdobeIllustratorEKas { get } // kashidas attribute
    @objc optional var kerningMethod: AdobeIllustratorEATK { get } // the automatic kerning method to use
    @objc optional var language: AdobeIllustratorELNG { get } // the language of text
    @objc optional var leading: Double { get } // the amount of space between two lines of text (in points)
    @objc optional var ligature: Bool { get } // whether the ligature should be used
    @objc optional var name: String { get } // the character style's name
    @objc optional var noBreak: Bool { get } // whether line breaks are allowed
    @objc optional var OpenTypePosition: AdobeIllustratorCOTP { get } // the OpenType baseline position
    @objc optional var ordinals: Bool { get } // whether the OpenType ordinals should be used
    @objc optional var ornaments: Bool { get } // whether the OpenType ornaments should be used
    @objc optional var overprintFill: Bool { get } // whether to overprint the fill of the text
    @objc optional var overprintStroke: Bool { get } // whether to overprint the stroke of the text
    @objc optional var proportionalMetrics: Bool { get } // does the Japanese OpenType support proportional font?
    @objc optional var rotation: Double { get } // the character rotation angle (in degrees)
    @objc optional var size: Double { get } // font size in points
    @objc optional var strikeThrough: Bool { get } // whether to draw a strike through line over the text
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // the color of the text stroke
    @objc optional var strokeWeight: Double { get } // line width of stroke
    @objc optional var stylisticAlternates: Bool { get } // whether the OpenType stylistic alternates should be used
    @objc optional var stylisticSets: Int { get } // stylistic sets attribute
    @objc optional var swash: Bool { get } // whether the OpenType swash should be used
    @objc optional var TCYHorizontal: Int { get } // the Tate-Chu-Yoko horizontal adjustment in points
    @objc optional var TCYVertical: Int { get } // the Tate-Chu-Yoko vertical adjustment in points
    @objc optional var textFont: Any { get } // the text font
    @objc optional var titling: Bool { get } // whether the OpenType titling alternates should be used
    @objc optional var tracking: Int { get } // the tracking or range kerning amount in thousands of an em
    @objc optional var Tsume: Double { get } // the percentage of space reduction around a Japanese character (100 = 100%)
    @objc optional var underline: Bool { get } // whether to underline the text
    @objc optional var verticalScale: Double { get } // character vertical scaling factor expressed as a percentage (100 = 100%)
    @objc optional var warichuCharactersAfterBreak: Int { get }
    @objc optional var warichuCharactersBeforeBreak: Int { get }
    @objc optional var warichuEnabled: Bool { get } // whether WariChu is enabled
    @objc optional var warichuGap: Int { get } // the Wari-Chu line gap
    @objc optional var warichuJustification: AdobeIllustratorEWCJ { get }
    @objc optional var warichuLines: Int { get } // the number of Wari-Chu (multiple text lines fit into a space meant for one) lines
    @objc optional var warichuScale: Double { get } // the Wari-Chu scale
    @objc optional func applyCharacterStyleTo(_ to: Any!, clearingOverrides: Bool) // Apply the character style to text object(s)
}
extension SBObject: AdobeIllustratorCharacterStyle {}

// MARK: AdobeIllustratorInsertionPoint
@objc public protocol AdobeIllustratorInsertionPoint: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var story: AdobeIllustratorStory { get } // the story of the text range
    @objc optional func characters() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AdobeIllustratorInsertionPoint {}

// MARK: AdobeIllustratorLine
@objc public protocol AdobeIllustratorLine: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var OpenTypePosition: AdobeIllustratorCOTP { get } // the OpenType baseline position
    @objc optional var TCYHorizontal: Int { get } // the Tate-Chu-Yoko horizontal adjustment in points
    @objc optional var TCYVertical: Int { get } // the Tate-Chu-Yoko vertical adjustment in points
    @objc optional var Tsume: Double { get } // the percentage of space reduction around a Japanese character (100 = 100%)
    @objc optional var akiLeft: Double { get } // the em amount of left aki
    @objc optional var akiRight: Double { get } // the em amount of right aki amount
    @objc optional var alignment: AdobeIllustratorESRA { get } // the character alignment type
    @objc optional var alternateGlyphs: AdobeIllustratorEAGF { get } // the alternate glyphs form
    @objc optional var autoLeading: Bool { get } // whether to use automatic leading
    @objc optional var baselineDirection: AdobeIllustratorEBSD { get } // the Japanese text baseline direction
    @objc optional var baselinePosition: AdobeIllustratorEFBO { get } // the baseline position of text
    @objc optional var baselineShift: Double { get } // the amount of shift (in points) of the text baseline
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var capitalization: AdobeIllustratorEFCO { get } // the case of text
    @objc optional var characterOffset: Int { get } // offset of the first character of the range from the beginning of the story, in characters.
    @objc optional var connectionForms: Bool { get } // whether the OpenType connection forms should be used
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var contents: String { get } // the text string
    @objc optional var contextualLigature: Bool { get } // whether the contextual ligature should be used
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var diacXOffset: Double { get } // diacritics x offset attribute
    @objc optional var diacYOffset: Double { get } // diacritics y offset attribute
    @objc optional var diacriticsPositioning: AdobeIllustratorEDVP { get } // diacritics positioning attribute
    @objc optional var digitSet: AdobeIllustratorEDgS { get } // digit set attribute
    @objc optional var directionOverride: AdobeIllustratorEDOT { get } // direction override attribute
    @objc optional var discretionaryLigature: Bool { get } // whether the discretionary ligature should be used
    @objc optional var end: Int { get } // end index of the text range
    @objc optional var figureStyle: AdobeIllustratorCFST { get } // which figure style to use in OpenType font
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // the color of the text fill
    @objc optional var fractions: Bool { get } // whether the OpenType fractions should be used
    @objc optional var horizontalScale: Double { get } // character horizontal scaling factor expressed as a percentage (100 = 100%)
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var italics: Bool { get } // does the Japanese OpenType support italics?
    @objc optional var justificationAlternates: Bool { get } // justification alternates attribute
    @objc optional var kana: Bool { get } // does the Japanese OpenType support kana?
    @objc optional var kashidas: AdobeIllustratorEKas { get } // kashidas attribute
    @objc optional var kerning: Int { get } // controls the spacing between two characters (in milli-ems)
    @objc optional var kerningMethod: AdobeIllustratorEATK { get } // the automatic kerning method to use
    @objc optional var language: AdobeIllustratorELNG { get } // the language of text
    @objc optional var leading: Double { get } // the amount of space between two lines of text (in points)
    @objc optional var length: Int { get } // length of text range ( minimum 0 )
    @objc optional var ligature: Bool { get } // whether the ligature should be used
    @objc optional var noBreak: Bool { get } // whether line breaks are allowed
    @objc optional var ordinals: Bool { get } // whether the OpenType ordinals should be used
    @objc optional var ornaments: Bool { get } // whether the OpenType ornaments should be used
    @objc optional var overprintFill: Bool { get } // whether to overprint the fill of the text
    @objc optional var overprintStroke: Bool { get } // whether to overprint the stroke of the text
    @objc optional var proportionalMetrics: Bool { get } // does the Japanese OpenType support proportional font?
    @objc optional var rotation: Double { get } // the character rotation angle (in degrees)
    @objc optional var selection: [Any] { get } // the selected text (ranges) in the text range
    @objc optional var size: Double { get } // font size in points
    @objc optional var start: Int { get } // start index of the text range
    @objc optional var story: AdobeIllustratorStory { get } // the story of the text range
    @objc optional var strikeThrough: Bool { get } // whether to draw a strike through line over the text
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // the color of the text stroke
    @objc optional var strokeWeight: Double { get } // line width of stroke
    @objc optional var stylisticAlternates: Bool { get } // whether the OpenType stylistic alternates should be used
    @objc optional var stylisticSets: Int { get } // stylistic sets attribute
    @objc optional var swash: Bool { get } // whether the OpenType swash should be used
    @objc optional var textFont: Any { get } // the text font
    @objc optional var titling: Bool { get } // whether the OpenType titling alternates should be used
    @objc optional var tracking: Int { get } // the tracking or range kerning amount in thousands of an em
    @objc optional var underline: Bool { get } // whether to underline the text
    @objc optional var verticalScale: Double { get } // character vertical scaling factor expressed as a percentage (100 = 100%)
    @objc optional var warichuCharactersAfterBreak: Int { get }
    @objc optional var warichuCharactersBeforeBreak: Int { get }
    @objc optional var warichuEnabled: Bool { get } // whether WariChu is enabled
    @objc optional var warichuGap: Int { get } // the Wari-Chu line gap
    @objc optional var warichuJustification: AdobeIllustratorEWCJ { get }
    @objc optional var warichuLines: Int { get } // the number of Wari-Chu (multiple text lines fit into a space meant for one) lines
    @objc optional var warichuScale: Double { get } // the Wari-Chu scale
    @objc optional func characterStyles() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphStyles() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AdobeIllustratorLine {}

// MARK: AdobeIllustratorParagraph
@objc public protocol AdobeIllustratorParagraph: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var BunriKinshi: Bool { get } // is BunriKinshi enabled?
    @objc optional var BurasagariType: AdobeIllustratorEPJ0 { get } // the Burasagari type
    @objc optional var ComposerEngine: AdobeIllustratorECET { get } // composer engine attribute
    @objc optional var KashidaWidth: AdobeIllustratorEKWT { get } // the Kashida Width attribute
    @objc optional var Kinsoku: String { get } // the Kinsoku Shori name
    @objc optional var KinsokuOrder: AdobeIllustratorEPJ2 { get } // the preferred Kinsoku order
    @objc optional var KurikaeshiMojiShori: Bool { get } // is KurikaeshiMojiShori enabled?
    @objc optional var Mojikumi: String { get } // the Mojikumi name
    @objc optional var OpenTypePosition: AdobeIllustratorCOTP { get } // the OpenType baseline position
    @objc optional var ParagraphDirection: AdobeIllustratorEPDT { get } // main writing direction attribute
    @objc optional var TCYHorizontal: Int { get } // the Tate-Chu-Yoko horizontal adjustment in points
    @objc optional var TCYVertical: Int { get } // the Tate-Chu-Yoko vertical adjustment in points
    @objc optional var Tsume: Double { get } // the percentage of space reduction around a Japanese character (100 = 100%)
    @objc optional var akiLeft: Double { get } // the em amount of left aki
    @objc optional var akiRight: Double { get } // the em amount of right aki amount
    @objc optional var alignment: AdobeIllustratorESRA { get } // the character alignment type
    @objc optional var alternateGlyphs: AdobeIllustratorEAGF { get } // the alternate glyphs form
    @objc optional var autoLeading: Bool { get } // whether to use automatic leading
    @objc optional var autoLeadingAmount: Double { get } // auto leading amount (in percentage)
    @objc optional var baselineDirection: AdobeIllustratorEBSD { get } // the Japanese text baseline direction
    @objc optional var baselinePosition: AdobeIllustratorEFBO { get } // the baseline position of text
    @objc optional var baselineShift: Double { get } // the amount of shift (in points) of the text baseline
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var capitalization: AdobeIllustratorEFCO { get } // the case of text
    @objc optional var characterOffset: Int { get } // offset of the first character of the range from the beginning of the story, in characters.
    @objc optional var connectionForms: Bool { get } // whether the OpenType connection forms should be used
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var contents: String { get } // the text string
    @objc optional var contextualLigature: Bool { get } // whether the contextual ligature should be used
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var desiredGlyphScaling: Double { get } // desired glyph scaling expressed as a percentage
    @objc optional var desiredLetterSpacing: Double { get } // desired letter spacing expressed as a percentage
    @objc optional var desiredWordSpacing: Double { get } // desired word spacing expressed as a percentage
    @objc optional var diacXOffset: Double { get } // diacritics x offset attribute
    @objc optional var diacYOffset: Double { get } // diacritics y offset attribute
    @objc optional var diacriticsPositioning: AdobeIllustratorEDVP { get } // diacritics positioning attribute
    @objc optional var digitSet: AdobeIllustratorEDgS { get } // digit set attribute
    @objc optional var directionOverride: AdobeIllustratorEDOT { get } // direction override attribute
    @objc optional var discretionaryLigature: Bool { get } // whether the discretionary ligature should be used
    @objc optional var end: Int { get } // end index of the text range
    @objc optional var everyLineComposer: Bool { get } // whether to enable every line composer (as opposed to single line composer)?
    @objc optional var figureStyle: AdobeIllustratorCFST { get } // which figure style to use in OpenType font
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // the color of the text fill
    @objc optional var firstLineIndent: Double { get } // first line left indent expressed in points
    @objc optional var fractions: Bool { get } // whether the OpenType fractions should be used
    @objc optional var horizontalScale: Double { get } // character horizontal scaling factor expressed as a percentage (100 = 100%)
    @objc optional var hyphenateCapitalizedWords: Bool { get } // is hyphenation enabled for the capitalized words?
    @objc optional var hyphenation: Bool { get } // is hyphenation enabled for the paragraph?
    @objc optional var hyphenationPreference: Double { get } // hyphenation preference scale for better spacing (0) or fewer hyphens (1) ( 0.0 - 1.0 )
    @objc optional var hyphenationZone: Double { get } // size of the hyphenation zone
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var italics: Bool { get } // does the Japanese OpenType support italics?
    @objc optional var justification: AdobeIllustratorEPRa { get } // paragraph justification
    @objc optional var justificationAlternates: Bool { get } // justification alternates attribute
    @objc optional var kana: Bool { get } // does the Japanese OpenType support kana?
    @objc optional var kashidas: AdobeIllustratorEKas { get } // kashidas attribute
    @objc optional var kerning: Int { get } // controls the spacing between two characters (in milli-ems)
    @objc optional var kerningMethod: AdobeIllustratorEATK { get } // the automatic kerning method to use
    @objc optional var language: AdobeIllustratorELNG { get } // the language of text
    @objc optional var leading: Double { get } // the amount of space between two lines of text (in points)
    @objc optional var leadingType: AdobeIllustratorEALD { get } // auto leading type
    @objc optional var leftIndent: Double { get } // left indent of margin expressed in points
    @objc optional var length: Int { get } // length of text range ( minimum 0 )
    @objc optional var ligature: Bool { get } // whether the ligature should be used
    @objc optional var listStyle: AdobeIllustratorListStyle { get } // paragraph list style
    @objc optional var maximumConsecutiveHyphens: Int { get } // maximum number of consecutive hypenated lines
    @objc optional var maximumGlyphScaling: Double { get } // maximum glyph scaling expressed as a percentage
    @objc optional var maximumLetterSpacing: Double { get } // maximum letter spacing expressed as a percentage
    @objc optional var maximumWordSpacing: Double { get } // maximum word spacing expressed as a percentage
    @objc optional var minimumAfterHyphen: Int { get } // minimum number of characters after a hyphen
    @objc optional var minimumBeforeHyphen: Int { get } // minimum number of characters before a hyphen
    @objc optional var minimumGlyphScaling: Double { get } // minimum glyph scaling expressed as a percentage
    @objc optional var minimumHyphenatedWordSize: Int { get } // minimum hyphenated word size
    @objc optional var minimumLetterSpacing: Double { get } // minimum letter spacing expressed as a percentage
    @objc optional var minimumWordSpacing: Double { get } // minimum word spacing expressed as a percentage
    @objc optional var noBreak: Bool { get } // whether line breaks are allowed
    @objc optional var ordinals: Bool { get } // whether the OpenType ordinals should be used
    @objc optional var ornaments: Bool { get } // whether the OpenType ornaments should be used
    @objc optional var overprintFill: Bool { get } // whether to overprint the fill of the text
    @objc optional var overprintStroke: Bool { get } // whether to overprint the stroke of the text
    @objc optional var paragraphListStyleTier: Int { get } // Tier/level of the paragraph list style
    @objc optional var proportionalMetrics: Bool { get } // does the Japanese OpenType support proportional font?
    @objc optional var rightIndent: Double { get } // right indent of margin expressed in points
    @objc optional var romanHanging: Bool { get } // is Roman hanging punctuation enabled?
    @objc optional var rotation: Double { get } // the character rotation angle (in degrees)
    @objc optional var selection: [Any] { get } // the selected text (ranges) in the text range
    @objc optional var singleWordJustification: AdobeIllustratorEPRa { get } // single word justification
    @objc optional var size: Double { get } // font size in points
    @objc optional var spaceAfter: Double { get } // spacing after paragraph in points
    @objc optional var spaceBefore: Double { get } // spacing before paragraph in points
    @objc optional var start: Int { get } // start index of the text range
    @objc optional var story: AdobeIllustratorStory { get } // the story of the text range
    @objc optional var strikeThrough: Bool { get } // whether to draw a strike through line over the text
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // the color of the text stroke
    @objc optional var strokeWeight: Double { get } // line width of stroke
    @objc optional var stylisticAlternates: Bool { get } // whether the OpenType stylistic alternates should be used
    @objc optional var stylisticSets: Int { get } // stylistic sets attribute
    @objc optional var swash: Bool { get } // whether the OpenType swash should be used
    @objc optional var tabStops: [Any] { get } // tab stop settings
    @objc optional var textFont: Any { get } // the text font
    @objc optional var titling: Bool { get } // whether the OpenType titling alternates should be used
    @objc optional var tracking: Int { get } // the tracking or range kerning amount in thousands of an em
    @objc optional var underline: Bool { get } // whether to underline the text
    @objc optional var verticalScale: Double { get } // character vertical scaling factor expressed as a percentage (100 = 100%)
    @objc optional var warichuCharactersAfterBreak: Int { get }
    @objc optional var warichuCharactersBeforeBreak: Int { get }
    @objc optional var warichuEnabled: Bool { get } // whether WariChu is enabled
    @objc optional var warichuGap: Int { get } // the Wari-Chu line gap
    @objc optional var warichuJustification: AdobeIllustratorEWCJ { get }
    @objc optional var warichuLines: Int { get } // the number of Wari-Chu (multiple text lines fit into a space meant for one) lines
    @objc optional var warichuScale: Double { get } // the Wari-Chu scale
    @objc optional func characterStyles() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphStyles() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AdobeIllustratorParagraph {}

// MARK: AdobeIllustratorParagraphStyle
@objc public protocol AdobeIllustratorParagraphStyle: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var akiLeft: Double { get } // the em amount of left aki
    @objc optional var akiRight: Double { get } // the em amount of right aki amount
    @objc optional var alignment: AdobeIllustratorESRA { get } // the character alignment type
    @objc optional var alternateGlyphs: AdobeIllustratorEAGF { get } // the alternate glyphs form
    @objc optional var autoLeading: Bool { get } // whether to use automatic leading
    @objc optional var autoLeadingAmount: Double { get } // auto leading amount (in percentage)
    @objc optional var baselineDirection: AdobeIllustratorEBSD { get } // the Japanese text baseline direction
    @objc optional var baselinePosition: AdobeIllustratorEFBO { get } // the baseline position of text
    @objc optional var baselineShift: Double { get } // the amount of shift (in points) of the text baseline
    @objc optional var BunriKinshi: Bool { get } // is BunriKinshi enabled?
    @objc optional var BurasagariType: AdobeIllustratorEPJ0 { get } // the Burasagari type
    @objc optional var capitalization: AdobeIllustratorEFCO { get } // the case of text
    @objc optional var ComposerEngine: AdobeIllustratorECET { get } // composer engine attribute
    @objc optional var connectionForms: Bool { get } // whether the OpenType connection forms should be used
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var contextualLigature: Bool { get } // whether the contextual ligature should be used
    @objc optional var desiredGlyphScaling: Double { get } // desired glyph scaling expressed as a percentage
    @objc optional var desiredLetterSpacing: Double { get } // desired letter spacing expressed as a percentage
    @objc optional var desiredWordSpacing: Double { get } // desired word spacing expressed as a percentage
    @objc optional var diacXOffset: Double { get } // diacritics x offset attribute
    @objc optional var diacYOffset: Double { get } // diacritics y offset attribute
    @objc optional var diacriticsPositioning: AdobeIllustratorEDVP { get } // diacritics positioning attribute
    @objc optional var digitSet: AdobeIllustratorEDgS { get } // digit set attribute
    @objc optional var directionOverride: AdobeIllustratorEDOT { get } // direction override attribute
    @objc optional var discretionaryLigature: Bool { get } // whether the discretionary ligature should be used
    @objc optional var everyLineComposer: Bool { get } // whether to enable every line composer (as opposed to single line composer)?
    @objc optional var figureStyle: AdobeIllustratorCFST { get } // which figure style to use in OpenType font
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // the color of the text fill
    @objc optional var firstLineIndent: Double { get } // first line left indent expressed in points
    @objc optional var fractions: Bool { get } // whether the OpenType fractions should be used
    @objc optional var horizontalScale: Double { get } // character horizontal scaling factor expressed as a percentage (100 = 100%)
    @objc optional var hyphenateCapitalizedWords: Bool { get } // is hyphenation enabled for the capitalized words?
    @objc optional var hyphenation: Bool { get } // is hyphenation enabled for the paragraph?
    @objc optional var hyphenationPreference: Double { get } // hyphenation preference scale for better spacing (0) or fewer hyphens (1) ( 0.0 - 1.0 )
    @objc optional var hyphenationZone: Double { get } // size of the hyphenation zone
    @objc optional var italics: Bool { get } // does the Japanese OpenType support italics?
    @objc optional var justification: AdobeIllustratorEPRa { get } // paragraph justification
    @objc optional var justificationAlternates: Bool { get } // justification alternates attribute
    @objc optional var kana: Bool { get } // does the Japanese OpenType support kana?
    @objc optional var kashidas: AdobeIllustratorEKas { get } // kashidas attribute
    @objc optional var KashidaWidth: AdobeIllustratorEKWT { get } // the Kashida Width attribute
    @objc optional var kerningMethod: AdobeIllustratorEATK { get } // the automatic kerning method to use
    @objc optional var Kinsoku: String { get } // the Kinsoku Shori name
    @objc optional var KinsokuOrder: AdobeIllustratorEPJ2 { get } // the preferred Kinsoku order
    @objc optional var KurikaeshiMojiShori: Bool { get } // is KurikaeshiMojiShori enabled?
    @objc optional var language: AdobeIllustratorELNG { get } // the language of text
    @objc optional var leading: Double { get } // the amount of space between two lines of text (in points)
    @objc optional var leadingType: AdobeIllustratorEALD { get } // auto leading type
    @objc optional var leftIndent: Double { get } // left indent of margin expressed in points
    @objc optional var ligature: Bool { get } // whether the ligature should be used
    @objc optional var listStyle: AdobeIllustratorListStyle { get } // paragraph list style
    @objc optional var maximumConsecutiveHyphens: Int { get } // maximum number of consecutive hypenated lines
    @objc optional var maximumGlyphScaling: Double { get } // maximum glyph scaling expressed as a percentage
    @objc optional var maximumLetterSpacing: Double { get } // maximum letter spacing expressed as a percentage
    @objc optional var maximumWordSpacing: Double { get } // maximum word spacing expressed as a percentage
    @objc optional var minimumAfterHyphen: Int { get } // minimum number of characters after a hyphen
    @objc optional var minimumBeforeHyphen: Int { get } // minimum number of characters before a hyphen
    @objc optional var minimumGlyphScaling: Double { get } // minimum glyph scaling expressed as a percentage
    @objc optional var minimumHyphenatedWordSize: Int { get } // minimum hyphenated word size
    @objc optional var minimumLetterSpacing: Double { get } // minimum letter spacing expressed as a percentage
    @objc optional var minimumWordSpacing: Double { get } // minimum word spacing expressed as a percentage
    @objc optional var Mojikumi: String { get } // the Mojikumi name
    @objc optional var name: String { get } // the paragraph style's name
    @objc optional var noBreak: Bool { get } // whether line breaks are allowed
    @objc optional var OpenTypePosition: AdobeIllustratorCOTP { get } // the OpenType baseline position
    @objc optional var ordinals: Bool { get } // whether the OpenType ordinals should be used
    @objc optional var ornaments: Bool { get } // whether the OpenType ornaments should be used
    @objc optional var overprintFill: Bool { get } // whether to overprint the fill of the text
    @objc optional var overprintStroke: Bool { get } // whether to overprint the stroke of the text
    @objc optional var paragraphListStyleTier: Int { get } // Tier/level of the paragraph list style
    @objc optional var ParagraphDirection: AdobeIllustratorEPDT { get } // main writing direction attribute
    @objc optional var proportionalMetrics: Bool { get } // does the Japanese OpenType support proportional font?
    @objc optional var rightIndent: Double { get } // right indent of margin expressed in points
    @objc optional var romanHanging: Bool { get } // is Roman hanging punctuation enabled?
    @objc optional var rotation: Double { get } // the character rotation angle (in degrees)
    @objc optional var singleWordJustification: AdobeIllustratorEPRa { get } // single word justification
    @objc optional var size: Double { get } // font size in points
    @objc optional var spaceAfter: Double { get } // spacing after paragraph in points
    @objc optional var spaceBefore: Double { get } // spacing before paragraph in points
    @objc optional var strikeThrough: Bool { get } // whether to draw a strike through line over the text
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // the color of the text stroke
    @objc optional var strokeWeight: Double { get } // line width of stroke
    @objc optional var stylisticAlternates: Bool { get } // whether the OpenType stylistic alternates should be used
    @objc optional var stylisticSets: Int { get } // stylistic sets attribute
    @objc optional var swash: Bool { get } // whether the OpenType swash should be used
    @objc optional var tabStops: [Any] { get } // tab stop settings
    @objc optional var TCYHorizontal: Int { get } // the Tate-Chu-Yoko horizontal adjustment in points
    @objc optional var TCYVertical: Int { get } // the Tate-Chu-Yoko vertical adjustment in points
    @objc optional var textFont: Any { get } // the text font
    @objc optional var titling: Bool { get } // whether the OpenType titling alternates should be used
    @objc optional var tracking: Int { get } // the tracking or range kerning amount in thousands of an em
    @objc optional var Tsume: Double { get } // the percentage of space reduction around a Japanese character (100 = 100%)
    @objc optional var underline: Bool { get } // whether to underline the text
    @objc optional var verticalScale: Double { get } // character vertical scaling factor expressed as a percentage (100 = 100%)
    @objc optional var warichuCharactersAfterBreak: Int { get }
    @objc optional var warichuCharactersBeforeBreak: Int { get }
    @objc optional var warichuEnabled: Bool { get } // whether WariChu is enabled
    @objc optional var warichuGap: Int { get } // the Wari-Chu line gap
    @objc optional var warichuJustification: AdobeIllustratorEWCJ { get }
    @objc optional var warichuLines: Int { get } // the number of Wari-Chu (multiple text lines fit into a space meant for one) lines
    @objc optional var warichuScale: Double { get } // the Wari-Chu scale
    @objc optional func applyParagraphStyleTo(_ to: Any!, clearingOverrides: Bool) // Apply the paragraph style to text object(s)
    @objc optional func clearStyle() // Remove all the attributes from this paragraph style
}
extension SBObject: AdobeIllustratorParagraphStyle {}

// MARK: AdobeIllustratorStory
@objc public protocol AdobeIllustratorStory: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var length: Int { get } // the number of characters in the story
    @objc optional var selection: [Any] { get } // the selected text (ranges) in the story
    @objc optional var textRange: AdobeIllustratorText { get } // the text range of the story
    @objc optional func characters() -> SBElementArray
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func textFrames() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AdobeIllustratorStory {}

// MARK: AdobeIllustratorText
@objc public protocol AdobeIllustratorText: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var characterOffset: Int { get } // offset of the first character of the range from the beginning of the story, in characters.
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var contents: String { get } // the text string
    @objc optional var end: Int { get } // end index of the text range
    @objc optional var kerning: Int { get } // controls the spacing between two characters (in milli-ems)
    @objc optional var length: Int { get } // length of text range ( minimum 0 )
    @objc optional var selection: [Any] { get } // the selected text (ranges) in the text range
    @objc optional var start: Int { get } // start index of the text range
    @objc optional var story: AdobeIllustratorStory { get } // the story of the text range
    @objc optional func characterStyles() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphStyles() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
    @objc optional func translatePlaceholderText() -> String // translate the placeholder text to regular text. A method to enter unicode points in hex values.
    @objc optional func doScriptFrom(_ from: String!, dialogs: Bool) // Play an action from the Actions Palette
}
extension SBObject: AdobeIllustratorText {}

// MARK: AdobeIllustratorTextPath
@objc public protocol AdobeIllustratorTextPath: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var area: Double { get } // the area of this path in square points
    @objc optional var blendMode: AdobeIllustratorCBlM { get } // the mode used when compositing an object
    @objc optional var clipping: Bool { get } // should this be used as a clipping path?
    @objc optional var closed: Bool { get } // is this path closed?
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var editable: Bool { get } // can the text path be modified
    @objc optional var entirePath: [Any] { get } // all the path item's path points
    @objc optional var evenodd: Bool { get } // should the even-odd rule be used to determine insideness?
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // fill color
    @objc optional var fillOverprint: Bool { get } // will art beneath a filled object be overprinted?
    @objc optional var filled: Bool { get } // should the path be filled?
    @objc optional var guides: Bool { get } // is this path a guide object?
    @objc optional var height: Double { get } // the height of the text path ( 0.0 - 16348.0 )
    @objc optional var note: String { get } // Note assigned to the path
    @objc optional var opacity: Double { get } // the object's opacity (between 0.0 and 100.0) ( 0.0 - 100.0 )
    @objc optional var polarity: AdobeIllustratorEPVu { get } // the polarity the path
    @objc optional var position: [Any] { get } // the position of the top left corner of the text path
    @objc optional var resolution: Double { get } // The resolution of the path
    @objc optional var selectedPathPoints: [Any] { get } // all the selected points in the path
    @objc optional var strokeCap: AdobeIllustratorESTc { get } // type of line capping
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // stroke color
    @objc optional var strokeDashOffset: Double { get } // the default distance into the dash pattern at which the pattern should be started
    @objc optional var strokeDashes: [Any] { get } // dash lengths (set to {} for a solid line)
    @objc optional var strokeJoin: AdobeIllustratorESTj { get } // type of joints
    @objc optional var strokeMiterLimit: Double { get } // whether a join is mitered (pointed) or beveled (squared-off)
    @objc optional var strokeOverprint: Bool { get } // will art beneath a stroked object be overprinted?
    @objc optional var strokeWidth: Double { get } // width of stroke
    @objc optional var stroked: Bool { get } // should the path be stroked?
    @objc optional var width: Double { get } // the width of the text path ( 0.0 - 16348.0 )
    @objc optional func pathPoints() -> SBElementArray
}
extension SBObject: AdobeIllustratorTextPath {}

// MARK: AdobeIllustratorWord
@objc public protocol AdobeIllustratorWord: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var OpenTypePosition: AdobeIllustratorCOTP { get } // the OpenType baseline position
    @objc optional var TCYHorizontal: Int { get } // the Tate-Chu-Yoko horizontal adjustment in points
    @objc optional var TCYVertical: Int { get } // the Tate-Chu-Yoko vertical adjustment in points
    @objc optional var Tsume: Double { get } // the percentage of space reduction around a Japanese character (100 = 100%)
    @objc optional var akiLeft: Double { get } // the em amount of left aki
    @objc optional var akiRight: Double { get } // the em amount of right aki amount
    @objc optional var alignment: AdobeIllustratorESRA { get } // the character alignment type
    @objc optional var alternateGlyphs: AdobeIllustratorEAGF { get } // the alternate glyphs form
    @objc optional var autoLeading: Bool { get } // whether to use automatic leading
    @objc optional var baselineDirection: AdobeIllustratorEBSD { get } // the Japanese text baseline direction
    @objc optional var baselinePosition: AdobeIllustratorEFBO { get } // the baseline position of text
    @objc optional var baselineShift: Double { get } // the amount of shift (in points) of the text baseline
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var capitalization: AdobeIllustratorEFCO { get } // the case of text
    @objc optional var characterOffset: Int { get } // offset of the first character of the range from the beginning of the story, in characters.
    @objc optional var connectionForms: Bool { get } // whether the OpenType connection forms should be used
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var contents: String { get } // the text string
    @objc optional var contextualLigature: Bool { get } // whether the contextual ligature should be used
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var diacXOffset: Double { get } // diacritics x offset attribute
    @objc optional var diacYOffset: Double { get } // diacritics y offset attribute
    @objc optional var diacriticsPositioning: AdobeIllustratorEDVP { get } // diacritics positioning attribute
    @objc optional var digitSet: AdobeIllustratorEDgS { get } // digit set attribute
    @objc optional var directionOverride: AdobeIllustratorEDOT { get } // direction override attribute
    @objc optional var discretionaryLigature: Bool { get } // whether the discretionary ligature should be used
    @objc optional var end: Int { get } // end index of the text range
    @objc optional var figureStyle: AdobeIllustratorCFST { get } // which figure style to use in OpenType font
    @objc optional var fillColor: AdobeIllustratorColorInfo { get } // the color of the text fill
    @objc optional var fractions: Bool { get } // whether the OpenType fractions should be used
    @objc optional var horizontalScale: Double { get } // character horizontal scaling factor expressed as a percentage (100 = 100%)
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var italics: Bool { get } // does the Japanese OpenType support italics?
    @objc optional var justificationAlternates: Bool { get } // justification alternates attribute
    @objc optional var kana: Bool { get } // does the Japanese OpenType support kana?
    @objc optional var kashidas: AdobeIllustratorEKas { get } // kashidas attribute
    @objc optional var kerning: Int { get } // controls the spacing between two characters (in milli-ems)
    @objc optional var kerningMethod: AdobeIllustratorEATK { get } // the automatic kerning method to use
    @objc optional var language: AdobeIllustratorELNG { get } // the language of text
    @objc optional var leading: Double { get } // the amount of space between two lines of text (in points)
    @objc optional var length: Int { get } // length of text range ( minimum 0 )
    @objc optional var ligature: Bool { get } // whether the ligature should be used
    @objc optional var noBreak: Bool { get } // whether line breaks are allowed
    @objc optional var ordinals: Bool { get } // whether the OpenType ordinals should be used
    @objc optional var ornaments: Bool { get } // whether the OpenType ornaments should be used
    @objc optional var overprintFill: Bool { get } // whether to overprint the fill of the text
    @objc optional var overprintStroke: Bool { get } // whether to overprint the stroke of the text
    @objc optional var proportionalMetrics: Bool { get } // does the Japanese OpenType support proportional font?
    @objc optional var rotation: Double { get } // the character rotation angle (in degrees)
    @objc optional var selection: [Any] { get } // the selected text (ranges) in the text range
    @objc optional var size: Double { get } // font size in points
    @objc optional var start: Int { get } // start index of the text range
    @objc optional var story: AdobeIllustratorStory { get } // the story of the text range
    @objc optional var strikeThrough: Bool { get } // whether to draw a strike through line over the text
    @objc optional var strokeColor: AdobeIllustratorColorInfo { get } // the color of the text stroke
    @objc optional var strokeWeight: Double { get } // line width of stroke
    @objc optional var stylisticAlternates: Bool { get } // whether the OpenType stylistic alternates should be used
    @objc optional var stylisticSets: Int { get } // stylistic sets attribute
    @objc optional var swash: Bool { get } // whether the OpenType swash should be used
    @objc optional var textFont: Any { get } // the text font
    @objc optional var titling: Bool { get } // whether the OpenType titling alternates should be used
    @objc optional var tracking: Int { get } // the tracking or range kerning amount in thousands of an em
    @objc optional var underline: Bool { get } // whether to underline the text
    @objc optional var verticalScale: Double { get } // character vertical scaling factor expressed as a percentage (100 = 100%)
    @objc optional var warichuCharactersAfterBreak: Int { get }
    @objc optional var warichuCharactersBeforeBreak: Int { get }
    @objc optional var warichuEnabled: Bool { get } // whether WariChu is enabled
    @objc optional var warichuGap: Int { get } // the Wari-Chu line gap
    @objc optional var warichuJustification: AdobeIllustratorEWCJ { get }
    @objc optional var warichuLines: Int { get } // the number of Wari-Chu (multiple text lines fit into a space meant for one) lines
    @objc optional var warichuScale: Double { get } // the Wari-Chu scale
    @objc optional func characterStyles() -> SBElementArray
    @objc optional func characters() -> SBElementArray
    @objc optional func insertionPoints() -> SBElementArray
    @objc optional func lines() -> SBElementArray
    @objc optional func paragraphStyles() -> SBElementArray
    @objc optional func paragraphs() -> SBElementArray
    @objc optional func text() -> SBElementArray
    @objc optional func words() -> SBElementArray
}
extension SBObject: AdobeIllustratorWord {}

// MARK: AdobeIllustratorMatrix
@objc public protocol AdobeIllustratorMatrix: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var mvalue_a: Double { get }
    @objc optional var mvalue_b: Double { get }
    @objc optional var mvalue_c: Double { get }
    @objc optional var mvalue_d: Double { get }
    @objc optional var mvalue_tx: Double { get }
    @objc optional var mvalue_ty: Double { get }
    @objc optional func concatenateMatrixWith(_ with: AdobeIllustratorMatrix!) -> AdobeIllustratorMatrix // Concatenate two transformation matrices
    @objc optional func concatenateRotationMatrixAngle(_ angle: Double) -> AdobeIllustratorMatrix // Concatenate a rotation matrix to a transformation matrix
    @objc optional func concatenateScaleMatrixHorizontalScale(_ horizontalScale: Double, verticalScale: Double) -> AdobeIllustratorMatrix // Concatenate a scale matrix to a transformation matrix
    @objc optional func concatenateTranslationMatrixDeltaX(_ deltaX: Double, deltaY: Double) -> AdobeIllustratorMatrix // Concatenate a translation to a transformation matrix
    @objc optional func equalMatricesWith(_ with: AdobeIllustratorMatrix!) -> Bool // Compares two matrices for equality
    @objc optional func invertMatrix() -> AdobeIllustratorMatrix // Invert a matrix
    @objc optional func singularMatrix() -> Bool // Tests if a matrix is singular (cannot be inverted)
}
extension SBObject: AdobeIllustratorMatrix {}

// MARK: AdobeIllustratorEllipse
@objc public protocol AdobeIllustratorEllipse: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bounds: [Any] { get } // the ellipse's bounds
    @objc optional var reversed: Bool { get } // is the ellipse path reversed? ( default: false )
    @objc optional var inscribed: Bool { get } // is the ellipse path inscribed? ( default: true )
}
extension SBObject: AdobeIllustratorEllipse {}

// MARK: AdobeIllustratorRectangle
@objc public protocol AdobeIllustratorRectangle: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bounds: [Any] { get } // the rectangle bounds
    @objc optional var reversed: Bool { get } // is the rectangle path reversed? ( default: false )
}
extension SBObject: AdobeIllustratorRectangle {}

// MARK: AdobeIllustratorRoundedRectangle
@objc public protocol AdobeIllustratorRoundedRectangle: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bounds: [Any] { get } // the rectangle bounds
    @objc optional var horizontalRadius: Double { get } // horizontal corner radius ( default: 15.0 )
    @objc optional var verticalRadius: Double { get } // vertical corner radius ( default: 20.0 )
    @objc optional var reversed: Bool { get } // is the rectangle path reversed? ( default: false )
}
extension SBObject: AdobeIllustratorRoundedRectangle {}

// MARK: AdobeIllustratorPolygon
@objc public protocol AdobeIllustratorPolygon: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var centerPoint: [Any] { get } // the center point of the polygon
    @objc optional var radius: Double { get } // the radius of the polygon points ( default: 50.0 )
    @objc optional var sides: Int { get } // the number of sides on the polygon ( default: 8 )
    @objc optional var reversed: Bool { get } // is the polygon path reversed? ( default: false )
}
extension SBObject: AdobeIllustratorPolygon {}

// MARK: AdobeIllustratorStar
@objc public protocol AdobeIllustratorStar: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var centerPoint: [Any] { get } // the center point of the rectangle
    @objc optional var radius: Double { get } // the outside radius of the star points ( default: 50.0 )
    @objc optional var innerRadius: Double { get } // the inside radius of the star points ( default: 20.0 )
    @objc optional var pointCount: Int { get } // the number of points on the star ( default: 5 )
    @objc optional var reversed: Bool { get } // is the star path reversed? ( default: false )
}
extension SBObject: AdobeIllustratorStar {}

// MARK: AdobeIllustratorAutoCADOptions
@objc public protocol AdobeIllustratorAutoCADOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var centerArtwork: Bool { get } // to center the created artwork on the artboard (default: true)
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var globalScaleOptions: AdobeIllustratorEGSO { get } // how to scale the AutoCAD drawing on import (default: Fit Artboard)
    @objc optional var globalScalePercent: Double { get } // percentage scaling to apply globally on the AutoCAD drawing (default: 1.0)
    @objc optional var mergeLayers: Bool { get } // to merge the layers of the artwork (default: false)
    @objc optional var scaleLineweights: Bool { get } // to scale lineweights by the same amount as rest of the drawing (default: false)
    @objc optional var scaleRatio: Double { get } // ratio by which to scale while mapping the units (default: 1.0)
    @objc optional var scaleUnit: AdobeIllustratorEASU { get } // units to which to map (default: Millimeters)
    @objc optional var selectedLayoutName: String { get } // name of layout in the AutoCAD drawing to import
}
extension SBObject: AdobeIllustratorAutoCADOptions {}

// MARK: AdobeIllustratorOpenOptions
@objc public protocol AdobeIllustratorOpenOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var addToRecentFiles: Bool { get } // Add this file to the list of recently opened files. ( default: true )
    @objc optional var `as`: AdobeIllustratorELib { get } // open the file as library ( default: Illustrator artwork )
    @objc optional var convertCropAreaToArtboard: Bool { get } // Convert crop area to Artboard when opening legacy document (pre-Illustrator CS4) in CS4 or later. If false then crop areas are discarded. ( default: true )
    @objc optional var convertTilesToArtboard: Bool { get } // Convert print tiles to Artboard when opening legacy document (pre-Illustrator CS4) in CS4 or later. ( default: false )
    @objc optional var createArtboardWithArtworkBoundingBox: Bool { get } // Create Artboard with dimentions of artwork bounding box when opening legacy document (pre-Illustrator CS4) in CS4 or later. ( default: false )
    @objc optional var preserveLegacyArtboard: Bool { get } // Preserve Legacy Artboard (pre-Illustrator CS4) when opening in CS4 or later. ( default: true )
    @objc optional var updateLegacyGradientMesh: Bool { get } // choose to preserve the spot colors in the gradient mesh objects for legacy documents (pre-Illustrator CS3) ( default: true )
    @objc optional var updateLegacyText: Bool { get } // choose to update all text objects for documents saved with legacy texts (pre-Illustrator 11) ( default: false )
}
extension SBObject: AdobeIllustratorOpenOptions {}

// MARK: AdobeIllustratorPDFOptions
@objc public protocol AdobeIllustratorPDFOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var linkPages: Bool { get } // Import PDF pages as links for optimal performance (default: true for PageRangeToOpen=all; false otherwise)
    @objc optional var page: Int { get } // what page should be used when opening a multipage document (default: 1)
    @objc optional var pageRange: String { get } // Range of pages when opening a multipage document [possible values: 'all', range(for example: '1,2,3-5,8')]
    @objc optional var PDFCropBounds: AdobeIllustratorEPBX { get } // what box should be used when placing a multipage document (default: PDF media box)
}
extension SBObject: AdobeIllustratorPDFOptions {}

// MARK: AdobeIllustratorPhotoshopOptions
@objc public protocol AdobeIllustratorPhotoshopOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var layerComp: String { get } // Should use the specified LayerComp
    @objc optional var preserveHiddenLayers: Bool { get } // should hidden layers be preserved when the document is converted (default: false)
    @objc optional var preserveImageMaps: Bool { get } // should image maps be preserved when the document is converted (default: true)
    @objc optional var preserveLayers: Bool { get } // should layers be Preserve when the document is converted (default: true)
    @objc optional var preserveSlices: Bool { get } // should slices be preserved when the document is converted (default: true)
}
extension SBObject: AdobeIllustratorPhotoshopOptions {}

// MARK: AdobeIllustratorEPSSaveOptions
@objc public protocol AdobeIllustratorEPSSaveOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var artboardRange: String { get } // If SaveMultipleArtboards is true,this will be considered for multi-asset extraction which specifies artboard range.Empty string will extracts all the artboards.Default is empty string ( default:  )
    @objc optional var CMYKPostScript: Bool { get } // use CMYK PostScript ( default: true )
    @objc optional var compatibility: AdobeIllustratorEDCc { get } // what Illustrator file format version to create ( default: Illustrator 24 )
    @objc optional var compatibleGradientPrinting: Bool { get } // create a raster item of the gradient or gradient mesh so that PostScript Level 2 printers can print the object ( default: false )
    @objc optional var embedAllFonts: Bool { get } // embed all fonts used by the document in the saved file (version 7 or later) ( default: false )
    @objc optional var embedLinkedFiles: Bool { get } // are linked image files to be included in the saved document ( default: false )
    @objc optional var flattenOutput: AdobeIllustratorEOFl { get } // how should transparency be flattened for older file format versions (pre-version 9) ( default: preserve appearance )
    @objc optional var includeDocumentThumbnails: Bool { get } // include thumbnail image of the EPS artwork ( default: true )
    @objc optional var overprint: AdobeIllustratorCPoP { get } // ( default: preserve )
    @objc optional var PostScript: AdobeIllustratorEPSt { get } // PostScript level to use (level 1 valid for file format version 8 or older) ( default: level 2 )
    @objc optional var preview: AdobeIllustratorEEPV { get } // EPS preview format
    @objc optional var saveMultipleArtboards: Bool { get } // All the artboards or range of the artboards will be saved ( default: false )
}
extension SBObject: AdobeIllustratorEPSSaveOptions {}

// MARK: AdobeIllustratorFXGSaveOptions
@objc public protocol AdobeIllustratorFXGSaveOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var artboardRange: String { get } // If SaveMultipleArtboards is true,this will be considered for multi-asset extraction which specifies artboard range.Empty string will extracts all the artboards.Default is empty string ( default:  )
    @objc optional var blendsPolicy: AdobeIllustratorEFBp { get } // the policy used by FXG to expand blends ( default: autoConvert blends )
    @objc optional var downsampleLinkedImages: Bool { get } // choose to downsample the linked images(72ppi) ( default: false )
    @objc optional var filtersPolicy: AdobeIllustratorEFFp { get } // the policy used by FXG to preserve filters ( default: keep filters editable )
    @objc optional var fxgVersion: AdobeIllustratorEFxV { get } // the version of the FXG file format to create ( default: version 2.0 )
    @objc optional var gradientsPolicy: AdobeIllustratorEFGp { get } // the policy used by FXG to preserve gradients ( default: autoConvert gradients )
    @objc optional var includeMetadata: Bool { get } // choose to include metadata (XMP) ( default: false )
    @objc optional var includeUnusedSymbols: Bool { get } // choose to include unused symbols ( default: false )
    @objc optional var preserveEditingCapabilities: Bool { get } // choose to preserve the editing capabilities of FXG ( default: true )
    @objc optional var saveMultipleArtboards: Bool { get } // All the artboards or range of the artboards will be saved ( default: false )
    @objc optional var textPolicy: AdobeIllustratorEFTp { get } // the policy used by FXG to preserve text ( default: autoConvert text )
}
extension SBObject: AdobeIllustratorFXGSaveOptions {}

// MARK: AdobeIllustratorIllustratorSaveOptions
@objc public protocol AdobeIllustratorIllustratorSaveOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var artboardRange: String { get } // If SaveMultipleArtboards is true ,this will be considered for multi-asset extraction which specifies artboard range.Empty string will extracts all the artboards.Default is empty string ( default:  )
    @objc optional var compatibility: AdobeIllustratorEDCc { get } // what Illustrator file format version to create ( default: Illustrator 24 )
    @objc optional var compressed: Bool { get } // should the saved file be compressed (version 10 or later) ( default: true )
    @objc optional var EmbedCompatibleFontGlyphs: Bool { get } // Save AI compatible used font glyphs (version 24 or later) ( default: false )
    @objc optional var embedICCProfile: Bool { get } // embed the document's ICC profile in the saved file (version 9 or later) ( default: false )
    @objc optional var embedLinkedFiles: Bool { get } // are linked image files to be included in the saved document (versions 7 or later) ( default: false )
    @objc optional var flattenOutput: AdobeIllustratorEOFl { get } // how should transparency be flattened for older file format versions (pre-version 9) ( default: preserve appearance )
    @objc optional var fontSubsetThreshold: Double { get } // include a subset of fonts when less than this percentage of characters are used (version 9 or later) ( 0.0 - 100.0; default: 100.0 )
    @objc optional var PDFCompatible: Bool { get } // save as a PDF compatible file (version 10 or later) ( default: true )
    @objc optional var saveMultipleArtboards: Bool { get } // All the artboards or range of the artboards will be saved ( default: false )
}
extension SBObject: AdobeIllustratorIllustratorSaveOptions {}

// MARK: AdobeIllustratorPDFSaveOptions
@objc public protocol AdobeIllustratorPDFSaveOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var acrobatLayers: Bool { get } // create acrobat layers from top-level layers - acrobat 6 only option ( default: false )
    @objc optional var allowPrinting: AdobeIllustratorCPpA { get } // PDF security printing permission ( default: pdf 128 print high res )
    @objc optional var artboardRange: String { get } // Considered for multi-asset extraction which specifies artboard range.Empty string will extracts all the artboards.Default is empty string ( default:  )
    @objc optional var bleedLink: Bool { get } // link 4 bleed values ( default: true )
    @objc optional var bleedOffset: [Any] { get } // the bleed offset rect
    @objc optional var changesAllowed: AdobeIllustratorCPcA { get } // PDF security changes allowed ( default: pdf 128 any changes )
    @objc optional var colorBars: Bool { get } // draw color bars ( default: false )
    @objc optional var colorCompression: AdobeIllustratorCCcT { get } // how should color bitmap images be compressed ( default: none )
    @objc optional var colorConversionId: AdobeIllustratorEPcC { get } // PDF color conversion policy. Three choices are available: (1)No Color Conversion (2) Repurpose (3) Convert to Destination ( default: none )
    @objc optional var colorDestinationId: AdobeIllustratorEDcD { get } // When NoColorConversion is specified for Color Conversion, NoColorDestination is set ( default: none )
    @objc optional var colorDownsampling: Double { get } // if zero, no downsampling, otherwise, the resolution to downsample color bitmap images to ( default: 150.0 )
    @objc optional var colorDownsamplingThreshold: Double { get } // downsample if the image's resolution is above this value ( default: 225.0 )
    @objc optional var colorProfileId: AdobeIllustratorEDpC { get } // If CMS is off, Don't Include Profiles is set ( default: none )
    @objc optional var colorResample: AdobeIllustratorCRsT { get } // how should color bitmap images be resampled ( default: nodownsample )
    @objc optional var colorTileSize: Int { get } // tile size when compressing with JPEG2000 ( default: 256 )
    @objc optional var compatibility: AdobeIllustratorEPDc { get } // the version of the Acrobat file format to create ( default: Acrobat 5 )
    @objc optional var compressArt: Bool { get } // should line art and text be compressed? ( default: true )
    @objc optional var documentPassword: String { get } // a password string to open the document ( default:  )
    @objc optional var enableAccess: Bool { get } // enable accessing 128-bit ( default: true )
    @objc optional var enableCopy: Bool { get } // enable copying of text 128-bit ( default: true )
    @objc optional var enableCopyAndAccess: Bool { get } // enable copying and accessing 40-bit ( default: true )
    @objc optional var enablePlaintext: Bool { get } // enable plaintext metadata 128-bit - available only for acrobat 6 ( default: false )
    @objc optional var flattenerPreset: String { get } // the transparency flattener preset name
    @objc optional var flattenerSettings: AdobeIllustratorFlatteningOptions { get } // the printing flattener options
    @objc optional var fontSubsetThreshold: Double { get } // include a subset of fonts when less than this percentage of characters are used ( 0.0 - 100.0; default: 100.0 )
    @objc optional var generateThumbnails: Bool { get } // generate thumbnails for the saved document ( default: true )
    @objc optional var grayscaleCompression: AdobeIllustratorCCcT { get } // how should grayscale bitmap images be compressed ( default: none )
    @objc optional var grayscaleDownsampling: Double { get } // if zero, no downsampling, otherwise, the resolution to downsample grayscale images to ( default: 150.0 )
    @objc optional var grayscaleDownsamplingThreshold: Double { get } // downsample if the image's resolution is above this value ( default: 225.0 )
    @objc optional var grayscaleResample: AdobeIllustratorCRsT { get } // how should grayscale bitmap images be resampled ( default: nodownsample )
    @objc optional var grayscaleTileSize: Int { get } // tile size when compressing with JPEG2000 ( default: 256 )
    @objc optional var monochromeCompression: AdobeIllustratorCMcQ { get } // how should monochrome bitmap images be compressed ( default: none )
    @objc optional var monochromeDownsampling: Double { get } // If zero, no downsampling, otherwise, the resolution to downsample images to ( default: 300.0 )
    @objc optional var monochromeDownsamplingThreshold: Double { get } // downsample if the image's resolution is above this value ( default: 450.0 )
    @objc optional var monochromeResample: AdobeIllustratorCRsT { get } // how should monochrome bitmap images be resampled ( default: nodownsample )
    @objc optional var offset: Double { get } // custom offset (in points) for using the custom paper ( default: 0.0 )
    @objc optional var optimization: Bool { get } // should the PDF document be optimized for fast web viewing ( default: false )
    @objc optional var outputCondition: String { get } // This is an optional comment which, if present, is added to the PDF file and describes the intended printing condition ( default:  )
    @objc optional var outputConditionId: String { get } // If selected for Output Intent Profile Name, you can set the name of a registered printing condition ( default:  )
    @objc optional var outputIntentProfile: String { get } // When CMS is on, the output intent profile is the same profile selected for Destination in the Color group box ( default:  )
    @objc optional var pageInfo: Bool { get } // draw page information ( default: false )
    @objc optional var pageMarksStyle: AdobeIllustratorEPMS { get } // the page marks style ( default: Roman )
    @objc optional var PDFPreset: String { get } // The max string length is 255 bytes. Name of PDF preset to use.
    @objc optional var pdfXstandard: AdobeIllustratorEPdX { get } // This control includes the None option for when the user is not complying with any PDF standard ( default: PDFX None )
    @objc optional var pdfXstandardDescripton: String { get } // This displays the description from the selected preset
    @objc optional var permissionPassword: String { get } // a password string to restrict editing security settings ( default:  )
    @objc optional var preserveEditability: Bool { get } // preserve Illustrator editing capabilities when saving the document ( default: true )
    @objc optional var printerResolution: Double { get } // flattening printer resolution ( default: 800.0 )
    @objc optional var registrationMarks: Bool { get } // draw registration marks ( default: false )
    @objc optional var registryName: String { get } // URL to the site where the specified output condition is registered. No validation is performed on the URL ( default:  )
    @objc optional var requireDocPassword: Bool { get } // require a password to open the document ( default: false )
    @objc optional var requirePermPassword: Bool { get } // use a password to restrict editing security settings ( default: false )
    @objc optional var trapped: Bool { get } // This indicates if manual trapping has been prepared in the document ( default: false )
    @objc optional var trimMarkWeight: AdobeIllustratorCPtW { get } // trim mark weight ( default: trimmarkweight0125 )
    @objc optional var trimMarks: Bool { get } // draw trim marks ( default: false )
    @objc optional var viewPdf: Bool { get } // view PDF after saving ( default: false )
}
extension SBObject: AdobeIllustratorPDFSaveOptions {}

// MARK: AdobeIllustratorAutoCADExportOptions
@objc public protocol AdobeIllustratorAutoCADExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var alterPathsForAppearance: Bool { get } // alter paths for appearance ( default: false )
    @objc optional var AutoCADVersion: AdobeIllustratorEAVS { get } // release of AutoCAD to export to ( default: AutoCAD release 24 )
    @objc optional var colors: AdobeIllustratorEACL { get } // number of colors to export into the AutoCAD file ( default: true colors )
    @objc optional var convertTextToOutlines: Bool { get } // whether to convert text to outlines ( default: false )
    @objc optional var exportFileFormat: AdobeIllustratorEAFF { get } // which format to export the file as ( default: dwg )
    @objc optional var exportOption: AdobeIllustratorEExO { get } // whether to preserve appearance or editability during export ( default: maximize editability )
    @objc optional var exportSelectedArtOnly: Bool { get } // export selected art only ( default: false )
    @objc optional var rasterFormat: AdobeIllustratorEARF { get } // raster format in which to export raster art ( default: PNG raster )
    @objc optional var scaleLineweights: Bool { get } // whether to scale lineweights by the same amount as rest of the drawing ( default: false )
    @objc optional var scaleRatio: Double { get } // ratio by which to scale the output ( default: 1.0 )
    @objc optional var scaleUnit: AdobeIllustratorEASU { get } // units from which to map ( default: autocad millimeters )
}
extension SBObject: AdobeIllustratorAutoCADExportOptions {}

// MARK: AdobeIllustratorAVIFExportOptions
@objc public protocol AdobeIllustratorAVIFExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: AdobeIllustratorEALS { get } // Should the resulting image be antialiased ( default: type optimized )
    @objc optional var embedICCProfile: Bool { get } // Embed an ICC profile when exporting ( default: false )
    @objc optional var includeMetadata: Bool { get } // choose to include metadata (XMP) ( default: false )
    @objc optional var losslessCompression: Bool { get } // Indicates whether to have lossless or lossy compression ( default: true )
    @objc optional var matteColor: AdobeIllustratorRGBColorInfo { get } // Matte color to be used for background if image is not transparent
    @objc optional var ppi: Double { get } // Image resolution in pixels-per-inch ( default: 72.0 )
    @objc optional var quality: Int { get } // In lossy compression, indicates the quality of the image to maintain ( 0 - 63; default: 63 )
    @objc optional var transparent: Bool { get } // Should include alpha channel ( default: true )
}
extension SBObject: AdobeIllustratorAVIFExportOptions {}

// MARK: AdobeIllustratorGIFExportOptions
@objc public protocol AdobeIllustratorGIFExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: Bool { get } // should the resulting image be antialiased ( default: true )
    @objc optional var artboardClipping: Bool { get } // should the resulting image be clipped to the artboard ( default: false )
    @objc optional var colorCount: Int { get } // number of colors in exported color table ( 2 - 256; default: 128 )
    @objc optional var colorDither: AdobeIllustratorCDtM { get } // method used to dither colors ( default: diffusion )
    @objc optional var colorReduction: AdobeIllustratorCCRM { get } // method used to reduce the number of colors ( default: selective )
    @objc optional var ditherPercent: Int { get } // how much should the colors be dithered ( 0 - 100; default: 88 )
    @objc optional var horizontalScaling: Double { get } // horizontal scaling factor ( default: 100.0 )
    @objc optional var informationLoss: Int { get } // level of information loss during compression ( 0 - 100; default: 0 )
    @objc optional var interlaced: Bool { get } // should the resulting image be interlaced ( default: false )
    @objc optional var matte: Bool { get } // should the artboard be matted with a color ( default: true )
    @objc optional var matteColor: AdobeIllustratorRGBColorInfo { get } // the color to use when matting the artboard (default: white)
    @objc optional var savingAsHTML: Bool { get } // should the resulting image be saved as HTML ( default: false )
    @objc optional var transparency: Bool { get } // should the resulting image use transparency ( default: true )
    @objc optional var verticalScaling: Double { get } // vertical scaling factor ( default: 100.0 )
    @objc optional var webSnap: Int { get } // how much should the color table be changed to match the web pallet ( 0 - 100; default: 0 )
}
extension SBObject: AdobeIllustratorGIFExportOptions {}

// MARK: AdobeIllustratorImageCaptureOptions
@objc public protocol AdobeIllustratorImageCaptureOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: Bool { get } // should the resulting image be antialiased ( default: false )
    @objc optional var matte: Bool { get } // should the artboard be matted with a color ( default: false )
    @objc optional var matteColor: AdobeIllustratorRGBColorInfo { get } // the color to use when matting the artboard (default: white)
    @objc optional var resolution: Double { get } // The resolution of the captured image file ( 72.0 - 2400.0; default: 150.0 )
    @objc optional var transparency: Bool { get } // should the resulting image use transparency ( default: false )
}
extension SBObject: AdobeIllustratorImageCaptureOptions {}

// MARK: AdobeIllustratorItemToExport
@objc public protocol AdobeIllustratorItemToExport: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var document: Bool { get } // Whether to export the document or not ( default: false )
    @objc optional var rangeOfArtboards: String { get } // Range of artboards to export [possible values: '', 'all'(default), range] ( default: all )
    @objc optional var rangeOfAssets: [Any] { get } // Array of asset id to export (default:empty)
}
extension SBObject: AdobeIllustratorItemToExport {}

// MARK: AdobeIllustratorJPEGExportOptions
@objc public protocol AdobeIllustratorJPEGExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: Bool { get } // should the resulting image be antialiased ( default: true )
    @objc optional var artboardClipping: Bool { get } // should the resulting image be clipped to the artboard ( default: false )
    @objc optional var blur: Double { get } // blur the resulting image this much ( 0.0 - 2.0; default: 0.0 )
    @objc optional var horizontalScaling: Double { get } // horizontal scaling factor ( 0.0 - 776.19; default: 100.0 )
    @objc optional var matte: Bool { get } // should the artboard be matted with a color ( default: true )
    @objc optional var matteColor: AdobeIllustratorRGBColorInfo { get } // the color to use when matting the artboard (default: white)
    @objc optional var optimization: Bool { get } // should the image be optimized for web viewing ( default: true )
    @objc optional var quality: Int { get } // quality of resulting image ( 0 - 100; default: 30 )
    @objc optional var savingAsHTML: Bool { get } // should the resulting image be saved as HTML ( default: false )
    @objc optional var verticalScaling: Double { get } // vertical scaling factor ( 0.0 - 776.19; default: 100.0 )
}
extension SBObject: AdobeIllustratorJPEGExportOptions {}

// MARK: AdobeIllustratorPDFExportOptions
@objc public protocol AdobeIllustratorPDFExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var PDFPreset: String { get } // The max string length is 255 bytes. Name of PDF preset to use. ( default:  )
}
extension SBObject: AdobeIllustratorPDFExportOptions {}

// MARK: AdobeIllustratorPhotoshopExportOptions
@objc public protocol AdobeIllustratorPhotoshopExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: Bool { get } // should the resulting image be antialiased ( default: true )
    @objc optional var artboardRange: String { get } // If SaveMultipleArtboards is true,this will be considered for multi-asset extraction which specifies artboard range.Empty string will extracts all the artboards.Default is empty string ( default:  )
    @objc optional var colorSpace: AdobeIllustratorECLS { get } // the color space of the exported file ( default: RGB )
    @objc optional var editableText: Bool { get } // export text objects as editable text layers ( default: true )
    @objc optional var embedICCProfile: Bool { get } // embed an ICC profile when exporting ( default: false )
    @objc optional var maximumEditability: Bool { get } // preserve as much of the original document's structure as possible when exporting ( default: true )
    @objc optional var resolution: Double { get } // The resolution of the exported file ( 72.0 - 2400.0; default: 150.0 )
    @objc optional var saveMultipleArtboards: Bool { get } // All the artboards or range of the artboards will be exported ( default: false )
    @objc optional var warnings: Bool { get } // should a warning dialog be displayed because of conflicts in the export settings ( default: true )
    @objc optional var writeLayers: Bool { get } // preserve document layers when exporting ( default: true )
}
extension SBObject: AdobeIllustratorPhotoshopExportOptions {}

// MARK: AdobeIllustratorPNG24ExportOptions
@objc public protocol AdobeIllustratorPNG24ExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: Bool { get } // should the resulting image be antialiased ( default: true )
    @objc optional var artboardClipping: Bool { get } // should the resulting image be clipped to the artboard ( default: false )
    @objc optional var dimensionsOfPNG: AdobeIllustratorDimensionsInfo { get } // Dimensions in which to contain the resulting raster
    @objc optional var horizontalScaling: Double { get } // horizontal scaling factor ( default: 100.0 )
    @objc optional var matte: Bool { get } // should the artboard be matted with a color ( default: true )
    @objc optional var matteColor: AdobeIllustratorRGBColorInfo { get } // the color to use when matting the artboard (default: white)
    @objc optional var savingAsHTML: Bool { get } // should the resulting image be saved as HTML ( default: false )
    @objc optional var transparency: Bool { get } // should the resulting image use transparency ( default: true )
    @objc optional var verticalScaling: Double { get } // vertical scaling factor ( default: 100.0 )
}
extension SBObject: AdobeIllustratorPNG24ExportOptions {}

// MARK: AdobeIllustratorPNG8ExportOptions
@objc public protocol AdobeIllustratorPNG8ExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: Bool { get } // should the resulting image be antialiased ( default: true )
    @objc optional var artboardClipping: Bool { get } // should the resulting image be clipped to the artboard ( default: false )
    @objc optional var colorCount: Int { get } // number of colors in exported color table ( 2 - 256; default: 128 )
    @objc optional var colorDither: AdobeIllustratorCDtM { get } // method used to dither colors ( default: diffusion )
    @objc optional var colorReduction: AdobeIllustratorCCRM { get } // method used to reduce the number of colors ( default: selective )
    @objc optional var ditherPercent: Int { get } // how much should the colors be dithered ( 0 - 100; default: 88 )
    @objc optional var horizontalScaling: Double { get } // horizontal scaling factor ( default: 100.0 )
    @objc optional var interlaced: Bool { get } // should the resulting image be interlaced ( default: false )
    @objc optional var matte: Bool { get } // should the artboard be matted with a color ( default: true )
    @objc optional var matteColor: AdobeIllustratorRGBColorInfo { get } // the color to use when matting the artboard (default: white)
    @objc optional var savingAsHTML: Bool { get } // should the resulting image be saved as HTML ( default: false )
    @objc optional var transparency: Bool { get } // should the resulting image use transparency ( default: true )
    @objc optional var verticalScaling: Double { get } // vertical scaling factor ( default: 100.0 )
    @objc optional var webSnap: Int { get } // how much should the color table be changed to match the web palette ( 0 - 100; default: 0 )
}
extension SBObject: AdobeIllustratorPNG8ExportOptions {}

// MARK: AdobeIllustratorSVGExportOptions
@objc public protocol AdobeIllustratorSVGExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var artboardRange: String { get } // If SaveMultipleArtboards is true,this will be considered for multi-asset extraction which specifies artboard range.Empty string will extracts all the artboards.Default is empty string ( default:  )
    @objc optional var coordinatePrecision: Int { get } // decimal precision for element coordinate values ( 1 - 7; default: 3 )
    @objc optional var CSSProperties: AdobeIllustratorESCS { get } // how should the CSS properties of the document be included in the document ( default: style attributes )
    @objc optional var fontType: AdobeIllustratorESFT { get } // the type of font that should be included in the exported file ( default: SVG font )
    @objc optional var minifySvg: Bool { get } // Reduces the size of the svg ( default: false )
    @objc optional var rasterImageLocation: AdobeIllustratorERIL { get } // should the raster images in the exported file be included ( default: preserve )
    @objc optional var responsiveSvg: Bool { get } // Makes the SVG Responsive ( default: true )
    @objc optional var saveMultipleArtboards: Bool { get } // All the artboards or range of the artboards will be saved ( default: false )
    @objc optional var setTypeOfSVG: AdobeIllustratorESIT { get } // how object names (IDs) are generated in exported SVG ( default: regular svg )
}
extension SBObject: AdobeIllustratorSVGExportOptions {}

// MARK: AdobeIllustratorTIFFExportOptions
@objc public protocol AdobeIllustratorTIFFExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: AdobeIllustratorEALS { get } // should the resulting image be antialiased ( default: art optimized )
    @objc optional var artboardRange: String { get } // If SaveMultipleArtboards is true,this will be considered for multi-asset extraction which specifies artboard range.Empty string will extracts all the artboards.Default is empty string ( default:  )
    @objc optional var ByteOrder: AdobeIllustratorETbo { get } // Mac or PC byte order when exporting ( default: IBM PC )
    @objc optional var colorSpace: AdobeIllustratorECLS { get } // the color space of the exported file ( default: RGB )
    @objc optional var embedICCProfile: Bool { get } // embed an ICC profile when exporting ( default: false )
    @objc optional var LZWCompression: Bool { get } // compress TIFF file with LZW Compression when exporting ( default: false )
    @objc optional var resolution: Double { get } // The resolution of the exported file ( 72.0 - 2400.0; default: 150.0 )
    @objc optional var saveMultipleArtboards: Bool { get } // All the artboards or range of the artboards will be exported ( default: false )
}
extension SBObject: AdobeIllustratorTIFFExportOptions {}

// MARK: AdobeIllustratorWebPExportOptions
@objc public protocol AdobeIllustratorWebPExportOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var antialiasing: AdobeIllustratorEALS { get } // Should the resulting image be antialiased ( default: type optimized )
    @objc optional var embedICCProfile: Bool { get } // Embed an ICC profile when exporting ( default: false )
    @objc optional var includeMetadata: Bool { get } // choose to include metadata (XMP) ( default: false )
    @objc optional var losslessCompression: Bool { get } // Indicates whether to have lossless or lossy compression ( default: true )
    @objc optional var matteColor: AdobeIllustratorRGBColorInfo { get } // Matte color to be used for background if image is not transparent
    @objc optional var ppi: Double { get } // Image resolution in pixels-per-inch ( default: 72.0 )
    @objc optional var quality: Int { get } // In lossy compression, indicates the quality of the image to maintain ( 0 - 100; default: 100 )
    @objc optional var transparent: Bool { get } // Should include alpha channel ( default: true )
}
extension SBObject: AdobeIllustratorWebPExportOptions {}

// MARK: AdobeIllustratorDataset
@objc public protocol AdobeIllustratorDataset: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var name: String { get } // the name of this dataset
    @objc optional func display() // displays the dynamic data that has been captured in the dataset.
    @objc optional func update() // re-apply the dynamic data of the active dataset to the artboard
}
extension SBObject: AdobeIllustratorDataset {}

// MARK: AdobeIllustratorVariable
@objc public protocol AdobeIllustratorVariable: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var kind: AdobeIllustratorEVKd { get } // the variable's type
    @objc optional var name: String { get } // the name of this variable
    @objc optional func pageItems() -> SBElementArray
}
extension SBObject: AdobeIllustratorVariable {}

// MARK: AdobeIllustratorColorManagementOptions
@objc public protocol AdobeIllustratorColorManagementOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var intent: AdobeIllustratorEPCI { get } // the color management intent type ( default: relative colorimetric )
    @objc optional var name: String { get } // the color management profile name
    @objc optional var profileKind: AdobeIllustratorEPCP { get } // the color management profile mode ( default: source profile )
}
extension SBObject: AdobeIllustratorColorManagementOptions {}

// MARK: AdobeIllustratorColorSeparationOptions
@objc public protocol AdobeIllustratorColorSeparationOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var convertSpotColors: Bool { get } // whether to convert all spot colors to process colors ( default: false )
    @objc optional var inks: [Any] { get } // the list of inks for color separation
    @objc optional var overPrintBlack: Bool { get } // whether to overprint in black ( default: false )
    @objc optional var separationMode: AdobeIllustratorEPCS { get } // the color separation type ( default: composite )
}
extension SBObject: AdobeIllustratorColorSeparationOptions {}

// MARK: AdobeIllustratorCoordinateOptions
@objc public protocol AdobeIllustratorCoordinateOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var emulsion: Bool { get } // whether to flip artwork horizontally ( default: false )
    @objc optional var fitToPage: Bool { get } // whether to proportionally scale the artwork to fit on the page ( default: false )
    @objc optional var horizontalScale: Double { get } // the horizontal scaling factor expressed as a percentage (100 = 100%) ( 1.0 - 10000.0; default: 100.0 )
    @objc optional var orientation: AdobeIllustratorEPOR { get } // the artwork orientation ( default: portrait )
    @objc optional var position: AdobeIllustratorEPPO { get } // the artwork position on media ( default: center )
    @objc optional var tiling: AdobeIllustratorEPTL { get } // the page tiling mode ( default: single full page )
    @objc optional var verticalScale: Double { get } // the vertical scaling factor expressed as a percentage (100 = 100%) ( 1.0 - 10000.0; default: 100.0 )
}
extension SBObject: AdobeIllustratorCoordinateOptions {}

// MARK: AdobeIllustratorFlatteningOptions
@objc public protocol AdobeIllustratorFlatteningOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var clipComplexRegions: Bool { get } // whether to clip complex regions ( default: false )
    @objc optional var convertStrokesToOutlines: Bool { get } // whether to convert all strokes to outlines ( default: false )
    @objc optional var convertTextToOutlines: Bool { get } // whether to convert all text to outlines ( default: false )
    @objc optional var flatteningBalance: Int { get } // the flattening balance ( 0 - 100; default: 100 )
    @objc optional var gradientResolution: Double { get } // the gradient resolution ( 1.0 - 9600.0; default: 300.0 )
    @objc optional var overprint: AdobeIllustratorCPoP { get } // overprint ( default: preserve )
    @objc optional var rasterizationResolution: Double { get } // the rasterization resolution ( 1.0 - 9600.0; default: 300.0 )
}
extension SBObject: AdobeIllustratorFlatteningOptions {}

// MARK: AdobeIllustratorFontOptions
@objc public protocol AdobeIllustratorFontOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var downloadFonts: AdobeIllustratorEPFD { get } // the font download mode ( default: subset )
    @objc optional var fontSubstitutionKind: AdobeIllustratorEPFS { get } // the font substitution policy ( default: oblique substitution )
}
extension SBObject: AdobeIllustratorFontOptions {}

// MARK: AdobeIllustratorInk
@objc public protocol AdobeIllustratorInk: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var name: String { get } // the ink's name
    @objc optional var properties: AdobeIllustratorInkProperties { get } // the ink information
}
extension SBObject: AdobeIllustratorInk {}

// MARK: AdobeIllustratorInkProperties
@objc public protocol AdobeIllustratorInkProperties: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var angle: Double { get } // the ink's screen angle (in degrees)
    @objc optional var customColor: AdobeIllustratorColorInfo { get } // the color of the custom ink
    @objc optional var density: Double { get } // the neutral density ( minimum 0.0 )
    @objc optional var dotShape: String { get } // the dot shape name
    @objc optional var frequency: Double { get } // the ink's frequency ( minimum 0.0 )
    @objc optional var kind: AdobeIllustratorEPIK { get } // the ink type
    @objc optional var printingStatus: AdobeIllustratorEPST { get } // the ink printing status
    @objc optional var trapping: AdobeIllustratorEPTT { get } // the trapping type
    @objc optional var trappingOrder: Int { get } // the order of trapping for the ink ( minimum 1 )
}
extension SBObject: AdobeIllustratorInkProperties {}

// MARK: AdobeIllustratorJobOptions
@objc public protocol AdobeIllustratorJobOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var artboardRange: String { get } // Artboard Range to be printed if PrintAllArtboards is false ( default: 1- )
    @objc optional var bitmapResolution: Double { get } // the bitmap resolution ( minimum 0.0; default: 0.0 )
    @objc optional var collate: Bool { get } // whether to collate print pages ( default: false )
    @objc optional var copies: Int { get } // the number of copies to print ( minimum 1; default: 1 )
    @objc optional var designation: AdobeIllustratorEPAD { get } // the layers/objects to be printed ( default: visible printable layers )
    @objc optional var filePath: URL { get } // the file to be printed to
    @objc optional var name: String { get } // the print job name
    @objc optional var printAllArtboards: Bool { get } // whether to print all artboards ( default: true )
    @objc optional var printArea: AdobeIllustratorEPBD { get } // the printing bounds ( default: artboard bounds )
    @objc optional var printAsBitmap: Bool { get } // whether to print as bitmap ( default: false )
    @objc optional var reversePages: Bool { get } // print pages in reverse order ( default: false )
}
extension SBObject: AdobeIllustratorJobOptions {}

// MARK: AdobeIllustratorPageMarksOptions
@objc public protocol AdobeIllustratorPageMarksOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bleedOffset: [Any] { get } // the bleed offset rect
    @objc optional var colorBars: Bool { get } // whether to enable color bars printing ( default: false )
    @objc optional var marksOffset: [Any] { get } // the page marks offset rect
    @objc optional var pageInfoMarks: Bool { get } // whether to enable page info marks printing ( default: false )
    @objc optional var pageMarksStyle: AdobeIllustratorEPMS { get } // the page marks style ( default: Roman )
    @objc optional var registrationMarks: Bool { get } // whether to enable registration marks printing ( default: false )
    @objc optional var trimMarks: Bool { get } // whether to enable trim marks printing ( default: false )
    @objc optional var trimMarksWeight: Double { get } // stroke weight of trim marks ( minimum 0.0; default: 0.125 )
}
extension SBObject: AdobeIllustratorPageMarksOptions {}

// MARK: AdobeIllustratorPaper
@objc public protocol AdobeIllustratorPaper: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var name: String { get } // the paper name
    @objc optional var properties: AdobeIllustratorPaperProperties { get } // the paper information
}
extension SBObject: AdobeIllustratorPaper {}

// MARK: AdobeIllustratorPaperOptions
@objc public protocol AdobeIllustratorPaperOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var height: Double { get } // the custom height (in points) for using the custom paper ( default: 0.0 )
    @objc optional var name: String { get } // the paper's name
    @objc optional var offset: Double { get } // custom offset (in points) for using the custom paper ( default: 0.0 )
    @objc optional var transverse: Bool { get } // whether to transverse the artwork (rotate 90 degrees) on the custom paper ( default: false )
    @objc optional var width: Double { get } // the custom width (in points) for using the custom paper ( default: 0.0 )
}
extension SBObject: AdobeIllustratorPaperOptions {}

// MARK: AdobeIllustratorPaperProperties
@objc public protocol AdobeIllustratorPaperProperties: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var customPaper: Bool { get } // Is it a custom paper?
    @objc optional var height: Double { get } // the paper's height (in points)
    @objc optional var imageableArea: [Any] { get } // the imageable area
    @objc optional var width: Double { get } // the paper's width (in points)
}
extension SBObject: AdobeIllustratorPaperProperties {}

// MARK: AdobeIllustratorPostscriptOptions
@objc public protocol AdobeIllustratorPostscriptOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var binaryPrinting: Bool { get } // whether to print in binary mode ( default: false )
    @objc optional var compatibleShading: Bool { get } // use PostScript level 1 compatible gradient and gradient mesh printing ( default: false )
    @objc optional var forceContinuousTone: Bool { get } // whether to force continuous tone ( default: false )
    @objc optional var imageCompression: AdobeIllustratorEPIC { get } // the image compression type ( default: none )
    @objc optional var negativePrinting: Bool { get } // whether to print in negative mode ( default: false )
    @objc optional var PostScript: AdobeIllustratorEPPS { get } // the PostScript language level ( default: level 2 )
    @objc optional var shadingResolution: Double { get } // the shading resolution ( 1.0 - 9600.0; default: 300.0 )
}
extension SBObject: AdobeIllustratorPostscriptOptions {}

// MARK: AdobeIllustratorPPDFile
@objc public protocol AdobeIllustratorPPDFile: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var name: String { get } // the PPD model name
    @objc optional var properties: AdobeIllustratorPPDProperties { get } // the PPD file information
}
extension SBObject: AdobeIllustratorPPDFile {}

// MARK: AdobeIllustratorPPDProperties
@objc public protocol AdobeIllustratorPPDProperties: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var filePath: URL { get } // path specification for the PPD file
    @objc optional var languageLevel: String { get } // the PostScript language level
    @objc optional var screens: [Any] { get } // list of color separation screens
    @objc optional var spotFunctions: [Any] { get } // list of color separation screen spot functions
}
extension SBObject: AdobeIllustratorPPDProperties {}

// MARK: AdobeIllustratorPrintOptions
@objc public protocol AdobeIllustratorPrintOptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var colorManagementSettings: AdobeIllustratorColorManagementOptions { get } // the printing color management options
    @objc optional var colorSeparationSettings: AdobeIllustratorColorSeparationOptions { get } // the printing color separation options
    @objc optional var coordinateSettings: AdobeIllustratorCoordinateOptions { get } // the printing coordinate options
    @objc optional var flattenerPreset: String { get } // the transparency flattener preset name
    @objc optional var flattenerSettings: AdobeIllustratorFlatteningOptions { get } // the printing flattener options
    @objc optional var fontSettings: AdobeIllustratorFontOptions { get } // the printing font options
    @objc optional var jobSettings: AdobeIllustratorJobOptions { get } // the printing job options
    @objc optional var pageMarksSettings: AdobeIllustratorPageMarksOptions { get } // the printing page marks options
    @objc optional var paperSettings: AdobeIllustratorPaperOptions { get } // the paper options
    @objc optional var postscriptSettings: AdobeIllustratorPostscriptOptions { get } // the printing PostScript options
    @objc optional var PPDName: String { get } // the name of the PPD to use
    @objc optional var printPreset: String { get } // the name of a print preset to use
    @objc optional var printerName: String { get } // the name of the printer to print to
}
extension SBObject: AdobeIllustratorPrintOptions {}

// MARK: AdobeIllustratorPrinter
@objc public protocol AdobeIllustratorPrinter: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var name: String { get } // the printer name
    @objc optional var properties: AdobeIllustratorPrinterProperties { get } // the printer information
}
extension SBObject: AdobeIllustratorPrinter {}

// MARK: AdobeIllustratorPrinterProperties
@objc public protocol AdobeIllustratorPrinterProperties: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var binaryPrinting: Bool { get } // does the printer support binary printing?
    @objc optional var colorSupport: AdobeIllustratorEPCM { get } // the printer color capability
    @objc optional var customPaperSizes: Bool { get } // does the printer support custom paper size?
    @objc optional var customPaperTransverse: Bool { get } // does the printer support custom paper transverse?
    @objc optional var defaultResolution: Double { get } // the printer default resolution
    @objc optional var InRIPSeparationSupport: Bool { get } // does the printer support InRIP color separation?
    @objc optional var maximumHeightOffset: Double { get } // custom paper's maximum height offset
    @objc optional var maximumPaperHeight: Double { get } // custom paper's maximum height
    @objc optional var maximumPaperWidth: Double { get } // custom paper's maximum width
    @objc optional var maximumResolution: Double { get } // the printer maximum device resolution
    @objc optional var maximumWidthOffset: Double { get } // custom paper's maximum width offset
    @objc optional var minimumHeightOffset: Double { get } // custom paper's minimum height offset
    @objc optional var minimumPaperHeight: Double { get } // custom paper's minimum height
    @objc optional var minimumPaperWidth: Double { get } // custom paper's minimum width
    @objc optional var minimumWidthOffset: Double { get } // custom paper's minimum width offset
    @objc optional var paperSizes: [Any] { get } // the list of supported paper sizes
    @objc optional var PostScript: AdobeIllustratorEPPS { get } // the PostScript level
    @objc optional var printerType: AdobeIllustratorEPTY { get } // the printer type
}
extension SBObject: AdobeIllustratorPrinterProperties {}

// MARK: AdobeIllustratorScreenProperties
@objc public protocol AdobeIllustratorScreenProperties: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var angle: Double { get } // the screen's angle (in degrees)
    @objc optional var defaultScreen: Bool { get } // Is it the default screen?
    @objc optional var frequency: Double { get } // the screen's frequency
}
extension SBObject: AdobeIllustratorScreenProperties {}

// MARK: AdobeIllustratorScreenSpotFunction
@objc public protocol AdobeIllustratorScreenSpotFunction: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var name: String { get } // the color separation screen spot function name
    @objc optional var spotFunction: String { get } // the spot function in terms of the PostScript commands
}
extension SBObject: AdobeIllustratorScreenSpotFunction {}

// MARK: AdobeIllustratorSeparationScreen
@objc public protocol AdobeIllustratorSeparationScreen: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var name: String { get } // the color separation screen name
    @objc optional var properties: AdobeIllustratorScreenProperties { get } // the color separation screen information
}
extension SBObject: AdobeIllustratorSeparationScreen {}

// MARK: AdobeIllustratorTracingobject
@objc public protocol AdobeIllustratorTracingobject: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var anchorCount: Int { get } // The number of anchors in the tracing result.
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var originalArt: AdobeIllustratorPageItem { get } // The source art used when creating a new tracing object.
    @objc optional var pathCount: Int { get } // The number of paths in the tracing result.
    @objc optional var tracingOptions: AdobeIllustratorTracingoptions { get } // The options used when tracing the artwork.
    @objc optional var usedColorCount: Int { get } // The number of colors used in the tracing result.
    @objc optional func expandTracingViewed(_ viewed: Bool) -> AdobeIllustratorGroupItem // Expand the tracing to paths.  Deletes this tracing object.
    @objc optional func releaseTracing() -> AdobeIllustratorPageItem // Release the source artwork for the tracing object.  Deletes this tracing object.
}
extension SBObject: AdobeIllustratorTracingobject {}

// MARK: AdobeIllustratorTracingoptions
@objc public protocol AdobeIllustratorTracingoptions: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var AutoGrouping: Bool { get } // Enables/Disables Auto Grouping
    @objc optional var colorFidelity: Double { get } // ColorFidelity when TracingColorTypeValue is TracingFullColor.
    @objc optional var colorgroup: String { get } // The color group name used for tracing. Use 'All' or any color group name available in color Palette (library).
    @objc optional var container: SBObject { get } // the object's container
    @objc optional var CornerFidelity: Double { get } // Corner fidelity for tracing.
    @objc optional var fills: Bool { get } // Tracing with fills. Fills, Strokes or both must be on.
    @objc optional var grayLevels: Int { get } // The gray levels for a grayscale mode tracing.. ( 1 - 256 )
    @objc optional var ignoreWhite: Bool { get } // Controls whether to ignore white fill color. Works only if TracingMethod is TracingMethodAbutting and mode is Black and white.
    @objc optional var maximumColors: Int { get } // Maximum number of colors allowed for tracing when TracingColorTypeValue is TracingLimitedColor.
    @objc optional var maximumStrokeWeight: Double { get } // Maximum stroke weight (stroke only).
    @objc optional var NoiseFidelity: Double { get } // Specifies minimum area of pixels to be vectorized.
    @objc optional var palette: String { get } // The color palette (Library) name used for tracing. Use 'Document Library' or any other imported library name.
    @objc optional var PathFidelity: Double { get } // Path fidelity for tracing.
    @objc optional var preset: String { get } // The name of the preset in use.  Read-only.
    @objc optional var snapCurveToLines: Bool { get } // Controls whether to snap curve to lines.
    @objc optional var strokes: Bool { get } // Tracing with strokes.  Fills, Strokes or both must be on.
    @objc optional var threshold: Int { get } // The threshold value for a black and white mode tracing. ( 1 - 256 )
    @objc optional var TracingColorTypeValue: AdobeIllustratorETCt { get } // Color Type used for tracing, TracingLimitedColor or TracingFullColor .
    @objc optional var TracingMethod: AdobeIllustratorETet { get } // Method for tracing, either abutting or adjoining paths.
    @objc optional var tracingMode: AdobeIllustratorETMt { get } // The tracing mode: color, gray, black and white.
    @objc optional var viewMode: AdobeIllustratorETvv { get } // The visualization mode.
    @objc optional func loadPresetPresetname(_ presetname: String!) -> Bool // Load options from preset.
    @objc optional func storePresetPresetname(_ presetname: String!) -> Bool // Store options to a preset kAiVectorizeSuite.  Will overwrite an existing (unlocked) preset if names match.
}
extension SBObject: AdobeIllustratorTracingoptions {}

// MARK: AdobeIllustratorAsset
@objc public protocol AdobeIllustratorAsset: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var bestType: NSNumber { get } // the best type for the object's value
    @objc optional var defaultType: NSNumber { get } // the default type for the object's value
    @objc optional var index: Int { get } // the index of this instance of the object
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var assetid: Int { get } // The UID for the asset which is unique within a document
    @objc optional var assetname: String { get } // Name of the asset
    @objc optional var container: SBObject { get } // the object's container
    @objc optional func normalizedName() -> String // Gets the normalized name without special characters, such that it can be used as a file name
}
extension SBObject: AdobeIllustratorAsset {}

// MARK: AdobeIllustratorAddfromselection
@objc public protocol AdobeIllustratorAddfromselection: SBObjectProtocol, AdobeIllustratorGenericMethods {
}
extension SBObject: AdobeIllustratorAddfromselection {}

// MARK: AdobeIllustratorAdd
@objc public protocol AdobeIllustratorAdd: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var sourceArt: Any { get } // The page item(s) to apply to
}
extension SBObject: AdobeIllustratorAdd {}

// MARK: AdobeIllustratorGridRepeatConfig
@objc public protocol AdobeIllustratorGridRepeatConfig: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var columnFlipType: AdobeIllustratorEGSF { get } // column flip type of grid repeat art ( default: no shift or flip )
    @objc optional var horizontalSpacing: Double { get } // spacing between each rows ( default: 10.0 )
    @objc optional var patternType: AdobeIllustratorEGSF { get } // shift type of grid repeat art ( default: no shift or flip )
    @objc optional var rowFlipType: AdobeIllustratorEGSF { get } // row flip type of grid repeat art ( default: no shift or flip )
    @objc optional var verticalSpacing: Double { get } // spacing between each columns ( default: 10.0 )
}
extension SBObject: AdobeIllustratorGridRepeatConfig {}

// MARK: AdobeIllustratorGridRepeatItem
@objc public protocol AdobeIllustratorGridRepeatItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var gridConfig: AdobeIllustratorGridRepeatConfig { get } // grid repeat config for repeat art
    @objc optional func setGridConfigurationConfig(_ config: AdobeIllustratorGridRepeatConfig!, state: AdobeIllustratorEGRU) // update the grid repeat art
}
extension SBObject: AdobeIllustratorGridRepeatItem {}

// MARK: AdobeIllustratorRadialRepeatConfig
@objc public protocol AdobeIllustratorRadialRepeatConfig: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var numberOfInstances: Int { get } // number of instances of radial repeat art ( default: 8 )
    @objc optional var radius: Double { get } // radius of radial repeat art ( default: -1.0 )
    @objc optional var reverseOverlap: Bool { get } // Reverse overlap of radial repeat art ( default: false )
}
extension SBObject: AdobeIllustratorRadialRepeatConfig {}

// MARK: AdobeIllustratorRadialRepeatItem
@objc public protocol AdobeIllustratorRadialRepeatItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var radialConfig: AdobeIllustratorRadialRepeatConfig { get } // radial repeat config for repeat art
    @objc optional func setRadialConfigurationConfig(_ config: AdobeIllustratorRadialRepeatConfig!, state: AdobeIllustratorERRU) // update the radial repeat art
}
extension SBObject: AdobeIllustratorRadialRepeatItem {}

// MARK: AdobeIllustratorSymmetryRepeatConfig
@objc public protocol AdobeIllustratorSymmetryRepeatConfig: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var axisRotationAngleInRadians: Double { get } // symmetry axis rotation angle wrt x-axis in anti-clockwise fashion ( default: 1.57 )
}
extension SBObject: AdobeIllustratorSymmetryRepeatConfig {}

// MARK: AdobeIllustratorSymmetryRepeatItem
@objc public protocol AdobeIllustratorSymmetryRepeatItem: AdobeIllustratorPageItem {
    @objc optional var properties: [AnyHashable : Any] { get } // all of this object's properties returned in a single record
    @objc optional var symmetryConfig: AdobeIllustratorSymmetryRepeatConfig { get } // symmetry repeat config for repeat art
    @objc optional func setSymmetryConfigurationConfig(_ config: AdobeIllustratorSymmetryRepeatConfig!, state: AdobeIllustratorESRU) // update the symmetry repeat art
}
extension SBObject: AdobeIllustratorSymmetryRepeatItem {}

// MARK: AdobeIllustratorAeadd
@objc public protocol AdobeIllustratorAeadd: SBObjectProtocol, AdobeIllustratorGenericMethods {
    @objc optional var sourceArt: Any { get } // The page item(s) to apply to
    @objc optional var config: AdobeIllustratorSymmetryRepeatConfig { get } // The symmetry repeat configuration
}
extension SBObject: AdobeIllustratorAeadd {}

