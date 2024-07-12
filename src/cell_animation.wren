/*

Load cell animations from xml document

*/

import "xsequence" for XDocument, XElement, XAttribute
import "io" for FileSystem
import "util" for StringUtil
import "graphics" for ImageData, Canvas
import "dome" for Log
import "math" for Math

class CellFormat {
  static oneImagePerCell { "OneImagePerCell" }
  static oneImagePerCluster { "OneImagePerCluster" }
  static all { [oneImagePerCell, oneImagePerCluster] }
}

class Shape {
  static square { "Square" }
  static wide { "Wide" }
  static tall { "Tall" }
}

class Scale {
  static small { "Small" }
  static medium { "Medium" }
  static large { "Large" }
  static xlarge { "XLarge" }
}

class CellSize {
  construct new(shape, scale, width, height) {
    _shape = shape
    _scale = scale
    _width = width
    _height = height
    _str = "%(width)x%(height)"
  }
  shape { _shape }
  scale { _scale }
  width { _width }
  height { _height }
  toString { _str }

  static validSizes { __validSizes }

  static init_() {
    __validSizes = [
      CellSize.new(Shape.square, Scale.small, 8, 8),
      CellSize.new(Shape.square, Scale.medium, 16, 16),
      CellSize.new(Shape.square, Scale.large, 32, 32),
      CellSize.new(Shape.square, Scale.xlarge, 64, 64),

      CellSize.new(Shape.wide, Scale.small, 16, 8),
      CellSize.new(Shape.wide, Scale.medium, 32, 8),
      CellSize.new(Shape.wide, Scale.large, 32, 16),
      CellSize.new(Shape.wide, Scale.xlarge, 64, 32),

      CellSize.new(Shape.tall, Scale.small, 8, 16),
      CellSize.new(Shape.tall, Scale.medium, 8, 32),
      CellSize.new(Shape.tall, Scale.large, 16, 32),
      CellSize.new(Shape.tall, Scale.xlarge, 32, 64),
    ]
  }

  static get(width, height) {
    for (i in __validSizes) {
      if (i.width == width && i.height == height) {
        return i
      }
    }
    return null
  }
}
CellSize.init_()

class Cell {

  x { _x }
  x=(v) { 
    _x = v 
    updateImage()
  }

  y { _y }
  y=(v) { 
    _y = v 
    updateImage()
  }

  // byte
  palette { _palette }
  palette=(v) { _palette = v }

  size { CellSize.get(width, height) }
  size=(v) {
    _width = v.width
    _height = v.height
    updateImage()
  }

  width { _width }
  width=(v) { 
    _width = v
    updateImage()
  }

  height { _height }
  height=(v) { 
    _height = v
    updateImage()
  }

  flipX { _flipX }
  flipX=(v) { 
    _flipX = v 
    updateImage()
  }

  flipY { _flipY }
  flipY=(v) { 
    _flipY = v
    updateImage()
  }

  doubleSize { _doubleSize }
  doubleSize=(v) {
    _doubleSize = v
    updateImage()
  }

  image { _image }

  format { _format }

  file { _file }
  file=(v) {
    _file = v
    loadFile()
    updateImage()
  }

  originalImage=(v) {
    _originalImage = v
    updateImage()
  }

  construct new(element, image, dir, format) {
    _format = format
    _dir = dir
    _originalImage = image
    _x = element.attributeValue("x", Num)
    _y = element.attributeValue("y", Num)
    _flipX = element.attributeValue("flip_x", Bool, false)
    _flipY = element.attributeValue("flip_y", Bool, false)
    _doubleSize = element.attributeValue("double_size", Bool, false)
    _palette = element.attributeValue("palette", Num, 0)
    
    if (_format == CellFormat.oneImagePerCell) {
      _file = element.attributeValue("file", String)
      loadFile()
    } else if (_format == CellFormat.oneImagePerCluster) {
      _width = element.attributeValue("width", Num)
      _height = element.attributeValue("height", Num)
    }
    if (size == null) {
      size = CellSize.validSizes[0]
    }
    updateImage()
  }

  serialise() {
    var element = XElement.new("cell",
      XAttribute.new("x", x),
      XAttribute.new("y", y)
    )

    if (width > 0) {
      element.add(XAttribute.new("width", width))
    }
    if (height > 0) {
      element.add(XAttribute.new("height", height))
    }
    if (file != null && file != "") {
      element.add(XAttribute.new("file", file))
    }
    if (palette != 0) {
      element.add(XAttribute.new("palette", palette))
    }
    if (flipX) {
      element.add(XAttribute.new("flip_x", flipX))
    }
    if (flipY) {
      element.add(XAttribute.new("flip_y", flipY))
    }
    if (doubleSize) {
      element.add(XAttribute.new("double_size", doubleSize))
    }
    return element
  }

  construct new(image, dir, format) {
    _format = format
    _dir = dir
    _originalImage = image
    _x = 0
    _y = 0
    _flipX = false
    _flipY = false
    _doubleSize = false

    if (_format == CellFormat.oneImagePerCell) {
      _file = null
    } else if (_format == CellFormat.oneImagePerCluster) {
      var validSize = CellSize.validSizes[0]
      _width = validSize.width
      _height = validSize.height
    }
    if (size == null) {
      size = CellSize.validSizes[0]
    }
    updateImage()
  }

  loadFile() {
    _originalImage = ImageData.load(_dir + "/" + _file)
    if (_format == CellFormat.oneImagePerCell) {
      _width = _originalImage.width
      _height = _originalImage.height
    }
  }

  updateImage() {
    var transform = {}
    if (_format == CellFormat.oneImagePerCell) {
      if (_doubleSize) {
        transform["scaleX"] = 4/3
        transform["scaleY"] = 4/3
      }
    } else if (_format == CellFormat.oneImagePerCluster) {
      transform["srcX"] = x 
      transform["srcY"] = y
      transform["srcW"] = width 
      transform["srcH"] = height
    }
    _image = _originalImage.transform(transform)
  }

  draw(x, y) {
    Canvas.draw(image, x + this.x, y + this.y)
  }
}

class Cluster {
  name { _name }
  name=(v) { _name = v }
  file { _file }
  file=(v) { 
    _file = v
    loadImage()
    for (cell in _cells) {
      cell.originalImage = _image
    }
  }
  cells { _cells }

  toString { _name }

  construct new(element, dir, format) {
    _dir = dir
    _format = format
    _name = element.attributeValue("name", String)
    _image = null
    if (format == CellFormat.oneImagePerCluster) {
      _file = element.attributeValue("file", String)
      loadImage()
    }
    _cells = element.elements("cell").map {|x| Cell.new(x, _image, dir, format) }.toList
  }

  serialise() {
    var element = XElement.new("cluster", 
      XAttribute.new("name", name)
      )
    
    if (file != null && file != "") {
      element.add(XAttribute.new("file", file))
    }
    for (cell in cells) {
      element.add(cell.serialise())
    }
    return element
    
  }

  loadImage() {
    _image = ImageData.load(_dir  + "/" + _file)
  }

  construct new(dir, format) {
    _dir = dir
    _format = format
    _name = "cluster_new"
    _file = null
    _cells = []
  }

  newCell() {
    return Cell.new(_image, _dir, _format)
  }

  // draw non-cropped cells
  draw(x, y) {
    if (cells.count == 0) {
      return
    }
    for (cid in (cells.count-1)..0) {
      var cell = cells[cid]
      cell.draw(x, y)
    }
  }

  // draw cells including cropped out sections
  drawFull(x, y) {
    if (_format == CellFormat.oneImagePerCluster) {
      Canvas.draw(_image, x, y)
    } else {
      draw(x, y)
    }
  }

  clone() {
    var n = Cluster.new()
    n.name = name
    n.file = file
    for (c in cells) {
      n.cells.add(c.clone())
    }
  }
}

class Frame {
  cluster { _cluster }
  cluster=(value) { _cluster = value }
  duration { _duration }
  duration=(value) { _duration = value }
  
  construct new(element, clusters) {
    var clusterName = element.attributeValue("cluster", String)
    for (c in clusters) {
      if (c.name == clusterName) {
        _cluster = c
      }
    }
    _duration = element.attributeValue("duration", Num)
  }

  serialise() {
    return XElement.new("frame",
      XAttribute.new("cluster", cluster.name),
      XAttribute.new("duration", duration)
    )
  }

  construct new() {
    _cluster = null
    _duration = 1
  }

  clone() {
    var n = Frame.new()
    n.cluster = cluster
    n.duration = duration
    return n
  }
}

class Animation {
  name { _name }
  name=(value) { _name = value }
  frames { _frames }
  frame { _frame }

  construct new(element, clusters) {
    _name = element.attributeValue("name", String)
    Log.debug("Loaded animation %(_name)")
    // frames with zero duration are ignored
    _frames = element.elements("frame").map {|x| Frame.new(x, clusters) }.toList.where{|x| x.duration > 0 }.toList
    reset()
  }

  serialise() {
    var element = XElement.new("animation", XAttribute.new("name", name))
    for (frame in _frames) {
      element.add(frame.serialise())
    }
    return element
  }

  construct new() {
    _name = "new_anim"
    _frames = []
    reset()
  }

  update() {
    _counter = _counter + 1
    if (_frames.count == 0) {
      return
    }
    if (_frame == null) {
      Fiber.abort("We have frames, but the current frame is null. Be sure to reset after modifying frames collection")
    }
    if (_counter == frame.duration) {
      // move onto the next frame
      _counter = 0
      _frameId = _frameId + 1
      if (_frameId == _frames.count) {
        _frameId = 0
      }
      _frame = _frames[_frameId]
    }
  }

  reset() {
    _counter = 0
    _frameId = 0
    if (_frames.count > 0) {
      _frame = _frames[0]
    } else {
      _frame = null
    }
  }

  clone() {
    var n = Animation.new()
    n.name = name
    for (frame in frames) {
      n.frames.add(frame.clone())
    }
    n.reset()
    return n
  }
}

class CellAnimationResource {
  clusters { _clusters }
  animations { _animations }
  background { _background }
  backgroundImage { _backgroundImage }
  format { _format }
  findCluster(name) {
    for (cluster in clusters) {
      if (cluster.name == name) {
        return cluster
      }
    }
    return null
  }
  findClusterIndex(name) {
    for (i in 0...clusters.count) {
      var cluster = clusters[i]
      if (cluster.name == name) {
        return i
      }
    }
    return -1
  }

  newCluster() {
    return Cluster.new(_dir, _format)
  }

  dir { _dir }
  
  construct new(file, dir) {
    _file = file
    _dir = dir
    Log.debug("Loading animation file '%(file)'")
    var document = XDocument.parse(FileSystem.load(file))
    var root = document.elementOrAbort("nitro_cell_animation_resource")
    var version = root.attributeValue("version", Num)
    if (version != 1) {
      Fiber.abort("Unknown animation format version '%(version)'")
    }

    _background = root.attributeValue("background")
    if (_background != null) {
      var bgFile = dir + "/" + _background
      Log.debug("Loading background file '%(bgFile)'")
      _backgroundImage = ImageData.load(bgFile)
    }
    // decides whether to play the animation. if null or empty we should play all
    var play = root.attributeValue("play")
    var playAll = play == null || play == ""

    // find the cell format and load the cells
    var cellCollElem = root.elementOrAbort("cell_collection")
    _format = cellCollElem.attributeValue("format", String)
    if (!CellFormat.all.contains(format)) {
      Fiber.abort("Unknown cell format '%(format)'")
    }
    _clusters = []
    for (clust in cellCollElem.elements("cluster").map{|x| Cluster.new(x, dir, format) }) {
      _clusters.add(clust)
    }
    // animations without frames are ignored
    _animations = []
    for (anim in root.elementOrAbort("animation_collection").elements("animation").map{|x| Animation.new(x, _clusters)}) {
      if (anim.frames.count > 0 && (playAll || play == anim.name)) {
        _animations.add(anim)
      }
    }
  }

  serialise() {
    var cellElem = XElement.new("cell_collection")
    for (c in clusters) {
      cellElem.add(c.serialise())
    }
    cellElem.add(XAttribute.new("format", format))

    var animElem = XElement.new("animation_collection")
    for (a in animations) {
      animElem.add(a.serialise())
    }

    var root = XElement.new("nitro_cell_animation_resource")
    if (background != null && background != "") {
      root.add(XAttribute.new("background", background))
    }

    root.add(cellElem)
    root.add(animElem)
    return XDocument.new(root)
  }

  save(file) {
    var doc = serialise()
    FileSystem.save(file, doc.toString)
  }

  update() {
    for (anim in _animations) {
      anim.update()
    }
  }

  draw(x, y) {
    // for some reason the draw order is back-to-front
    if (_animations.count == 0) {
      return
    }
    for (i in (_animations.count-1)..0) {
      drawAnimation(x, y, i)
    }
  }

  drawAnimation(x, y, index) {
    var anim = _animations[index]
    if (anim.frame == null) {
      return // anim has no frames
    }
    var cluster = anim.frame.cluster
    if (cluster != null) {
      cluster.draw(x, y)
    }
  }

  reset() {
    for (anim in _animations) {
      anim.reset()
    }
  }
}