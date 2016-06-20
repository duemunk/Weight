//
//  Chart.swift
//
//  Created by Giampaolo Bellavite on 07/11/14.
//  Copyright (c) 2014 Giampaolo Bellavite. All rights reserved.
//

import UIKit

public protocol ChartDelegate {

    /**
    Tells the delegate that the specified chart has been touched.

    - parameter chart: The chart that has been touched.
    - parameter indexes: Each element of this array contains the index of the data that has been touched, one for each series.
            If the series hasn't been touched, its index will be nil.
    - parameter x: The value on the x-axis that has been touched.
    - parameter left: The distance from the left side of the chart.

    */
    func didTouchChart(_ chart: Chart, indexes: Array<Int?>, x: Float, left: CGFloat)

    /**
    Tells the delegate that the user finished touching the chart. The user will "finish" touching the
    chart only swiping left/right outside the chart.

    - parameter chart: The chart that has been touched.

    */
    func didFinishTouchingChart(_ chart: Chart)
}

/**
Represent the x- and the y-axis values for each point in a chart series.
*/
typealias ChartPoint = (x: Float, y: Float)

@IBDesignable
public class Chart: UIControl {

    // MARK: Options

    @IBInspectable
    public var identifier: String?

    /**
    Series to display in the chart.
    */
    public var series: Array<ChartSeries> = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    /**
    The values to display as labels on the x-axis. You can format these values with the `xLabelFormatter` attribute.
    As default, it will display the values of the series which has the most data.
    */
    public var xLabels: Array<Float>?

    /**
    Formatter for the labels on the x-axis. The `index` represents the `xLabels` index, `value` its value:
    */
    public var xLabelsFormatter = { (labelIndex: Int, labelValue: Float) -> String in
        String(Int(labelValue))
    }

    /**
    Text alignment for the x-labels
    */
    public var xLabelsTextAlignment: NSTextAlignment = .left

    /**
    Values to display as labels of the y-axis. If not specified, will display the
    lowest, the middle and the highest values.
    */
    public var yLabels: Array<Float>?

    /**
    Formatter for the labels on the y-axis.
    */
    public var yLabelsFormatter = { (labelIndex: Int, labelValue: Float, yIncrement: Float?) -> String in
        String(Int(labelValue))
    }

    /**
    Displays the y-axis labels on the right side of the chart.
    */
    public var yLabelsOnRightSide: Bool = true

    /**
    Font used for the labels.
    */
    public var labelFont: UIFont? = UIFont.systemFont(ofSize: 12)

    /**
    Font used for the labels.
    */
    @IBInspectable
    public var labelColor: UIColor = UIColor.black()

    /**
    Color for the axes.
    */
    @IBInspectable
    public var axesColor: UIColor = UIColor.gray().withAlphaComponent(0.3)

    public var axesLineWidth: CGFloat = 1

    /**
    Color for the grid.
    */
    @IBInspectable
    public var gridColor: UIColor = UIColor.gray().withAlphaComponent(0.3)

    public var gridLineWidth: CGFloat = 1

    /**
    Inset of the area at the bottom of the chart, containing the labels for the x-axis.
    */
    public var inset: UIEdgeInsets = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 30)

    /**
    Width of the chart's lines.
    */
    @IBInspectable
    public var lineWidth: CGFloat = 2

    /**
     Width of the chart's lines.
     */
    @IBInspectable
    public var dotSize: CGFloat = 3

    /**
    Delegate for listening to Chart touch events.
    */
    public var delegate: ChartDelegate?

    /**
    Custom minimum value for the x-axis.
    */
    public var minX: Float?

    /**
    Custom minimum value for the y-axis.
    */
    public var minY: Float?

    /**
    Custom maximum value for the x-axis.
    */
    public var maxX: Float?

    /**
    Custom maximum value for the y-axis.
    */
    public var maxY: Float?

    /**
    Color for the highlight line.
    */
    public var highlightLineColor = UIColor.gray()

    /**
    Width for the highlight line.
    */
    public var highlightLineWidth: CGFloat = 0.5

    /**
    Alpha component for the area's color.
    */
    public var areaAlphaComponent: CGFloat = 0.1

    // MARK: Private variables

    private var highlightShapeLayer: CAShapeLayer!
    private var layerStore: Array<CAShapeLayer> = []

    private var drawingHeight: CGFloat!
    private var drawingWidth: CGFloat!

    // Minimum and maximum values represented in the chart
    private var min: ChartPoint!
    private var max: ChartPoint!
    private var yIncrement: Float? = nil

    // Represent a set of points corresponding to a segment line on the chart.
    typealias ChartLineSegment = Array<ChartPoint>

    // MARK: initializations

    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    convenience public init() {
        self.init(frame: .zero)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear()
        contentMode = .redraw
    }

    override public func draw(_ rect: CGRect) {
        #if TARGET_INTERFACE_BUILDER
            drawIBPlaceholder()
        #else
            drawChart()
        #endif
    }

    /**
    Adds a chart series.
    */
    public func addSeries(_ series: ChartSeries) {
        self.series.append(series)
    }

    /**
    Adds multiple series.
    */
    public func addSeries(_ series: Array<ChartSeries>) {
        for s in series {
            addSeries(s)
        }
    }

    /**
    Remove the series at the specified index.
    */
    public func removeSeriesAtIndex(_ index: Int) {
        series.remove(at: index)
    }

    /**
    Remove all the series.
    */
    public func removeSeries() {
        series = []
    }

    /**
    Returns the value for the specified series at the given index
    */
    public func valueForSeries(_ seriesIndex: Int, atIndex dataIndex: Int?) -> Float? {
        if dataIndex == nil { return nil }
        let series = self.series[seriesIndex] as ChartSeries
        return series.data[dataIndex!].y
    }


    private func drawIBPlaceholder() {
        let placeholder = UIView(frame: self.frame)
        placeholder.backgroundColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1)
        let label = UILabel()
        label.text = "Chart"
        label.font = UIFont.systemFont(ofSize: 28)
        label.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2)
        label.sizeToFit()
        label.frame.origin.x += frame.width/2 - (label.frame.width / 2)
        label.frame.origin.y += frame.height/2 - (label.frame.height / 2)

        placeholder.addSubview(label)
        addSubview(placeholder)
    }

    private func drawChart() {

        drawingHeight = bounds.height - inset.bottom - inset.top
        drawingWidth = bounds.width - inset.left - inset.right

        let minMax = getMinMax()
        min = minMax.min
        max = minMax.max
        yIncrement = minMax.yIncrement

        highlightShapeLayer = nil

        // Remove things before drawing, e.g. when changing orientation

        for view in self.subviews {
            view.removeFromSuperview()
        }
        for layer in layerStore {
            layer.removeFromSuperlayer()
        }
        layerStore.removeAll()

        // Draw content

        for (index, series) in self.series.enumerated() {

            // Separate each line in multiple segments over and below the x axis
            let segments = Chart.segmentLine(series.data as ChartLineSegment)

            segments.forEach({ segment in
                let scaledXValues = segment.map { return $0.x }.map { scaleValueOnXAxis($0) }
                let scaledYValues = segment.map { return $0.y }.map { scaleValueOnYAxis($0) }

                if series.line {
                    drawLine(xValues: scaledXValues, yValues: scaledYValues, seriesIndex: index)
                }
                if series.area {
                    drawArea(xValues: scaledXValues, yValues: scaledYValues, seriesIndex: index)
                }
                if series.dots {
                    drawDots(xValues: scaledXValues, yValues: scaledYValues, seriesIndex: index)
                }
            })
        }

//        drawAxes()

        if xLabels != nil || series.count > 0 {
            drawLabelsAndGridOnXAxis()
        }
        if yLabels != nil || series.count > 0 {
            drawLabelsAndGridOnYAxis()
        }

    }

    // MARK: - Scaling

    private func getMinMax() -> (min: ChartPoint, max: ChartPoint, yIncrement: Float?) {

        // Start with user-provided values

        var min = (x: minX, y: minY)
        var max = (x: maxX, y: maxY)

        // Check in datasets

        for series in self.series {
            let xValues =  series.data.map({ (point: ChartPoint) -> Float in
                return point.x })
            let yValues =  series.data.map({ (point: ChartPoint) -> Float in
                return point.y })

            let newMinX = xValues.min()!
            let newMinY = yValues.min()!
            let newMaxX = xValues.max()!
            let newMaxY = yValues.max()!

            if min.x == nil || newMinX < min.x! { min.x = newMinX }
            if min.y == nil || newMinY < min.y! { min.y = newMinY }
            if max.x == nil || newMaxX > max.x! { max.x = newMaxX }
            if max.y == nil || newMaxY > max.y! { max.y = newMaxY }
        }

        // Check in labels

        if xLabels != nil {
            let newMinX = (xLabels!).min()!
            let newMaxX = (xLabels!).max()!
            if min.x == nil || newMinX < min.x { min.x = newMinX }
            if max.x == nil || newMaxX > max.x { max.x = newMaxX }
        }

        if yLabels != nil {
            let newMinY = (yLabels!).min()!
            let newMaxY = (yLabels!).max()!
            if min.y == nil || newMinY < min.y { min.y = newMinY }
            if max.y == nil || newMaxY > max.y { max.y = newMaxY }
        }

        var _min = ChartPoint(x: min.x ?? 0, y: min.y ?? 0)
        var _max = ChartPoint(x: max.x ?? 0, y: max.y ?? 0)

        // Clean min max values
        let yRange = _max.y - _min.y
        let yIncrement = axesIncrementIn(range: yRange, axesRange: Float(frame.height))
        if let yIncrement = yIncrement {
            _min.y -= (_min.y).truncatingRemainder(dividingBy: yIncrement)
            _max.y += yIncrement - (_max.y).truncatingRemainder(dividingBy: yIncrement)
        }

        return (min: _min, max: _max, yIncrement: yIncrement)
    }

    private func axesIncrementIn(range valueRange: Float, axesRange: Float) -> Float? {
        guard valueRange != 0 else { return nil }
        let incrementApproxHeight: Float = 40
        let roomForRows = axesRange / incrementApproxHeight
        let naiveIncrement = valueRange / roomForRows
        let roundedIncrement = validGridIncrement(naiveIncrement)
        return roundedIncrement
    }

    private func nearestPowerOf10(_ value: Float) -> Float {
        return pow(10, round(log10(value) - log10(5.5) + 0.5))
    }

    private func nextPowerOf10(_ value: Float) -> Float {
        return pow(10, ceil(log10(value) - log10(5.5) + 0.5))
    }

    private func nextPower(of power: Float, value: Float) -> Float {
        return pow(power, ceil(log(value)/log(power) - log(power + 0.5)/log(power) + 0.5))
    }

    private func validGridIncrement(_ value: Float) -> Float {
        switch value {
        case 10...25: return 25
        case 25...50: return 50
        case 50...100: return 100
        case 100...FLT_MAX: return validGridIncrement(value/10)*10 // Recursive
        case -FLT_MAX...10: return validGridIncrement(value*10)/10 // Recursive
        default: return value
        }
    }

    private func scaleValueOnXAxis(_ value: Float) -> Float {
        let width = Float(drawingWidth)

        var factor: Float
        if max.x - min.x == 0 {
            factor = 0
        } else {
            factor = width / (max.x - min.x)
        }

        let scaled = Float(inset.left) + factor * (value - min.x)
        return scaled
    }

    private func scaleValueOnYAxis(_ value: Float) -> Float {

        let height = Float(drawingHeight)
        var factor: Float
        if max.y - min.y == 0 {
            factor = 0
        } else {
            factor = height / (max.y - min.y)
        }

        let scaled = Float(inset.top) + height - factor * (value - min.y)
        return scaled
    }

    private func getZeroValueOnYAxis() -> Float {
        if min.y > 0 {
            return scaleValueOnYAxis(min.y)
        } else {
            return scaleValueOnYAxis(0)
        }

    }

    // MARK: - Drawings

    private func isVerticalSegmentAboveXAxis(_ yValues: Array<Float>) -> Bool {

        // YValues are "reverted" from top to bottom, so min is actually the maxz
        let min = yValues.max()!
        let zero = getZeroValueOnYAxis()

        return min <= zero

    }

    @discardableResult
    private func drawLine(xValues: Array<Float>, yValues: Array<Float>, seriesIndex: Int) -> CAShapeLayer {

        let isAboveXAxis = isVerticalSegmentAboveXAxis(yValues)
        let path = CGMutablePath()

        path.moveTo(nil, x: CGFloat(xValues.first!), y: CGFloat(yValues.first!))

        for i in 1..<yValues.count {
            let y = yValues[i]
            path.addLineTo(nil, x: CGFloat(xValues[i]), y: CGFloat(y))
        }

        let lineLayer = CAShapeLayer()
        lineLayer.frame = self.bounds
        lineLayer.path = path

        lineLayer.fillColor = UIColor.clear().cgColor
        if isAboveXAxis {
            lineLayer.strokeColor = series[seriesIndex].colors.above.cgColor
        } else {
            lineLayer.strokeColor = series[seriesIndex].colors.below.cgColor
        }
        lineLayer.lineWidth = lineWidth
        lineLayer.lineJoin = kCALineJoinBevel

        self.layer.addSublayer(lineLayer)

        layerStore.append(lineLayer)


        return lineLayer
    }

    private func drawArea(xValues: Array<Float>, yValues: Array<Float>, seriesIndex: Int) {
        let isAboveXAxis = isVerticalSegmentAboveXAxis(yValues)
        let area = CGMutablePath()
        let zero = CGFloat(getZeroValueOnYAxis())

        area.moveTo(nil, x: CGFloat(xValues[0]), y: zero)

        for i in 0..<xValues.count {
            area.addLineTo(nil, x: CGFloat(xValues[i]), y: CGFloat(yValues[i]))
        }

        area.addLineTo(nil, x: CGFloat(xValues.last!), y: zero)

        let areaLayer = CAShapeLayer()
        areaLayer.frame = self.bounds
        areaLayer.path = area
        areaLayer.strokeColor = UIColor.clear().cgColor
        if isAboveXAxis {
            areaLayer.fillColor = series[seriesIndex].colors.above.withAlphaComponent(areaAlphaComponent).cgColor
        } else {
            areaLayer.fillColor = series[seriesIndex].colors.below.withAlphaComponent(areaAlphaComponent).cgColor
        }
        areaLayer.lineWidth = 0

        self.layer.addSublayer(areaLayer)

        layerStore.append(areaLayer)
    }

    @discardableResult
    private func drawDots(xValues: Array<Float>, yValues: Array<Float>, seriesIndex: Int) -> CAShapeLayer {

        let isAboveXAxis = isVerticalSegmentAboveXAxis(yValues)

        let path = CGMutablePath()
        for (xValue, yValue) in zip(xValues, yValues) {
            let size = dotSize
            let x = CGFloat(xValue) - size / 2
            let y = CGFloat(yValue) - size / 2
            let circleRect = CGRect(x: x, y: y, width: size, height: size)
            path.addRoundedRect(nil, rect: circleRect, cornerWidth: size/2, cornerHeight: size/2)
        }

        let dotsLayer = CAShapeLayer()
        dotsLayer.frame = self.bounds
        dotsLayer.path = path

        let colors = series[seriesIndex].colors
        dotsLayer.fillColor = isAboveXAxis ? colors.above.cgColor : colors.below.cgColor
        dotsLayer.strokeColor = UIColor.clear().cgColor

        self.layer.addSublayer(dotsLayer)

        layerStore.append(dotsLayer)
        
        return dotsLayer
    }

    private func drawAxes() {

        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(axesColor.cgColor)
        context?.setLineWidth(axesLineWidth)

        // horizontal axis at the bottom
        context?.moveTo(x: inset.left, y: drawingHeight + inset.top)
        context?.addLineTo(x: drawingWidth, y: drawingHeight + inset.top)
        context?.strokePath()

        // horizontal axis at the top
        context?.moveTo(x: inset.left, y: inset.top)
        context?.addLineTo(x: drawingWidth + inset.left, y: inset.top)
        context?.strokePath()

        // horizontal axis when y = 0
        if min.y < 0 && max.y > 0 {
            let y = CGFloat(getZeroValueOnYAxis())
            context?.moveTo(x: inset.left, y: y)
            context?.addLineTo(x: drawingWidth + inset.left, y: y)
            context?.strokePath()
        }

        // vertical axis on the left
        context?.moveTo(x: inset.left, y: inset.top)
        context?.addLineTo(x: inset.left, y: drawingHeight + inset.top)
        context?.strokePath()


        // vertical axis on the right
        context?.moveTo(x: drawingWidth + inset.left, y: inset.top)
        context?.addLineTo(x: drawingWidth + inset.left, y: drawingHeight + inset.top)
        context?.strokePath()

    }

    private func drawLabelsAndGridOnXAxis() {

        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(gridColor.cgColor)
        context?.setLineWidth(gridLineWidth)

        var labels: Array<Float>
        if xLabels == nil {
            // Use labels from the first series
            labels = series[0].data.map{ $0.x }
        } else {
            labels = xLabels!
        }

        let scaled = labels.map { scaleValueOnXAxis($0) }
        let padding: CGFloat = 5

        scaled.enumerated().forEach { (i, value) in
            let x = CGFloat(value)

            // Add vertical grid for each label, except axes on the left and right
            context?.moveTo(x: x, y: inset.top)
            context?.addLineTo(x: x, y: bounds.height)
            context?.strokePath()

            if x == drawingWidth {
                // Do not add label at the most right position
                return
            }

            // Add label
            let label = UILabel(frame: CGRect(x: x, y: drawingHeight, width: 0, height: 0))
            label.font = labelFont
            label.text = xLabelsFormatter(i, labels[i])
            label.textColor = labelColor

            // Set label size
            label.sizeToFit()

            // Add left padding
            label.frame.origin.x += padding

            // Center label vertically
            label.frame.origin.y += inset.top
            label.frame.origin.y -= (label.frame.height - inset.bottom) / 2

            // Set label's text alignment
            label.frame.size.width = (drawingWidth / CGFloat(labels.count)) - padding * 2
            label.textAlignment = xLabelsTextAlignment


            self.addSubview(label)
        }
    }

    private func drawLabelsAndGridOnYAxis() {

        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(gridColor.cgColor)
        context?.setLineWidth(gridLineWidth)

        var labels: Array<Float>
        if yLabels == nil {
            if let yIncrement = yIncrement {
                labels = stride(from: min.y, through: max.y, by: yIncrement)
                    .map { $0 }
            } else {
                labels = [(min.y + max.y) / 2, max.y]
                if yLabelsOnRightSide || min.y != 0 {
                    labels.insert(min.y, at: 0)
                }
            }
        } else {
            labels = yLabels!
        }

        let scaled = labels.map { scaleValueOnYAxis($0) }

        scaled.enumerated().forEach { (i, value) in

            let y = CGFloat(value)

            // Add horizontal grid for each label
            context?.moveTo(x: 0, y: y)
            context?.addLineTo(x: self.bounds.width, y: y)
            context?.strokePath()

            let label = UILabel(frame: CGRect(x: 0, y: y, width: 0, height: 0))
            label.font = labelFont
            label.text = yLabelsFormatter(i, labels[i], yIncrement)
            label.textColor = labelColor
            label.sizeToFit()

            if yLabelsOnRightSide {
                label.frame.origin.x = drawingWidth + inset.left + inset.right - label.frame.width
            }

            // Labels should be placed above the horizontal grid
            label.frame.origin.y -= label.frame.height

            self.addSubview(label)

        }

        UIGraphicsEndImageContext()
    }

    // MARK: - Touch events

    private func drawHighlightLineFromLeftPosition(_ left: CGFloat) {
        if let shapeLayer = highlightShapeLayer {
            // Use line already created
            let path = CGMutablePath()

            path.moveTo(nil, x: left, y: 0)
            path.addLineTo(nil, x: left, y: drawingHeight  + inset.top)
            shapeLayer.path = path
        } else {
            // Create the line
            let path = CGMutablePath()

            path.moveTo(nil, x: left, y: 0)
            path.addLineTo(nil, x: left, y: drawingHeight + inset.top)

            let shapeLayer = CAShapeLayer()
            shapeLayer.frame = self.bounds
            shapeLayer.path = path
            shapeLayer.strokeColor = highlightLineColor.cgColor
            shapeLayer.fillColor = UIColor.clear().cgColor
            shapeLayer.lineWidth = highlightLineWidth

            highlightShapeLayer = shapeLayer
            layer.addSublayer(shapeLayer)
            layerStore.append(shapeLayer)
        }

    }

    func handleTouchEvents(_ touches: NSSet!, event: UIEvent!) {
        let point: AnyObject! = touches.anyObject()
        let left = point.location(in: self).x
        let x = valueFromPointAtX(left)

        if left < 0 || left > drawingWidth {
            // Remove highlight line at the end of the touch event
            if let shapeLayer = highlightShapeLayer {
                shapeLayer.path = nil
            }
            delegate?.didFinishTouchingChart(self)
            return
        }

        drawHighlightLineFromLeftPosition(left)

        if delegate == nil {
            return
        }

        var indexes: Array<Int?> = []

        for series in self.series {
            var index: Int? = nil
            let xValues = series.data.map({ (point: ChartPoint) -> Float in
                return point.x })
            let closest = Chart.findClosestInValues(xValues, forValue: x)
            if closest.lowestIndex != nil && closest.highestIndex != nil {
                // Consider valid only values on the right
                index = closest.lowestIndex
            }
            indexes.append(index)
        }

        delegate!.didTouchChart(self, indexes: indexes, x: x, left: left)

    }
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
    }


    // MARK: - Utilities

    private func valueFromPointAtX(_ x: CGFloat) -> Float {
        let value = ((max.x-min.x) / Float(drawingWidth)) * Float(x) + min.x
        return value
    }

    private func valueFromPointAtY(_ y: CGFloat) -> Float {
        let value = ((max.y - min.y) / Float(drawingHeight)) * Float(y) + min.y
        return -value
    }

    private class func findClosestInValues(_ values: Array<Float>, forValue value: Float) -> (lowestValue: Float?, highestValue: Float?, lowestIndex: Int?, highestIndex: Int?) {
        var lowestValue: Float?, highestValue: Float?, lowestIndex: Int?, highestIndex: Int?

        values.enumerated().forEach { (i, currentValue) in

            if currentValue <= value && (lowestValue == nil || lowestValue! < currentValue) {
                lowestValue = currentValue
                lowestIndex = i
            }
            if currentValue >= value && (highestValue == nil || highestValue! > currentValue) {
                highestValue = currentValue
                highestIndex = i
            }

        }
        return (lowestValue: lowestValue, highestValue: highestValue, lowestIndex: lowestIndex, highestIndex: highestIndex)
    }


    /**
    Segment a line in multiple lines when the line touches the x-axis, i.e. separating
    positive from negative values.
    */
    private class func segmentLine(_ line: ChartLineSegment) -> Array<ChartLineSegment> {
        var segments: Array<ChartLineSegment> = []
        var segment: ChartLineSegment = []

        line.enumerated().forEach { (i, point) in

            segment.append(point)
            if i < line.count - 1 {
                let nextPoint = line[i+1]
                if point.y * nextPoint.y < 0 || point.y < 0 && nextPoint.y == 0 {
                    // The sign changed, close the segment with the intersection on x-axis
                    let closingPoint = Chart.intersectionOnXAxisBetween(point, and: nextPoint)
                    segment.append(closingPoint)
                    segments.append(segment)
                    // Start a new segment
                    segment = [closingPoint]
                }
            } else {
                // End of the line
                segments.append(segment)
            }

        }
        return segments
    }

    /**
    Return the intersection of a line between two points on the x-axis
    */
    private class func intersectionOnXAxisBetween(_ p1: ChartPoint, and p2: ChartPoint) -> ChartPoint {
        return (x: p1.x - (p2.x - p1.x) / (p2.y - p1.y) * p1.y, y: 0)
    }
}
