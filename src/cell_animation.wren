/*

Load cell animations from xml document

*/

import "xsequence" for XDocument
import "io" for FileSystem
import "util" for StringUtil
import "graphics" for ImageData, Canvas
import "dome" for Log

class CellFormat {
  static oneImagePerCell { "OneImagePerCell" }
  static oneImagePerBank { "OneImagePerBank" }
  static all { [oneImagePerCell, oneImagePerBank] }
}

class Cell {
  x { _x }
  y { _y }
  width { _width }
  height { _height }
  flipX { _flipX }
  flipY { _flipY }
  image { _image }

  construct new(element, image, dir, format) {

    _x = element.attributeValue("x", Num)
    _y = element.attributeValue("y", Num)
    _width = element.attributeValue("width", Num)
    _height = element.attributeValue("height", Num)
    _flipX = element.attributeValue("flip_x", Bool, false)
    _flipY = element.attributeValue("flip_y", Bool, false)
    _doubleSize = element.attributeValue("double_size", Bool, false)
    
    var transform = {}
    if (format == CellFormat.oneImagePerCell) {
      var file = element.attributeValue("file", String)
      image = ImageData.load(dir + "/" + file)
      if (_doubleSize) {
        transform["scaleX"] = 4/3
        transform["scaleY"] = 4/3
      }
    } else if (format == CellFormat.oneImagePerBank) {
      transform["srcX"] = x 
      transform["srcY"] = y
      transform["srcW"] = width 
      transform["srcH"] = height
    }
    _image = image.transform(transform)
  }
}

class CellImage {
  name { _name }
  file { _file }
  cells { _cells }

  construct new(element, dir, format) {
    _name = element.attributeValue("name", String)
    var image = null
    if (format == CellFormat.oneImagePerBank) {
      _file = element.attributeValue("file", String)
      var image = ImageData.load(dir  + "/" + file)
    }
    _cells = element.elements("cell").map {|x| Cell.new(x, image, dir, format) }.toList
  }
}

class Frame {
  image { _image }
  duration { _duration }
  
  construct new(element) {
    _image = element.attributeValue("image", String)
    _duration = element.attributeValue("duration", Num)
  }
}

class Animation {
  name { _name }
  frames { _frames }
  frame { _frame }

  construct new(element) {
    _name = element.attributeValue("name", String)
    Log.debug("Loaded animation %(_name)")
    // frames with zero duration are ignored
    _frames = element.elements("frame").map {|x| Frame.new(x) }.toList.where{|x| x.duration > 0 }.toList
    _frameId = 0
    _counter = 0
    if (_frames.count > 0) {
      _frame = _frames[0]
    }
  }

  update() {
    _counter = _counter + 1
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
}

class CellAnimationResource {
  cellImages { _cellImages }
  animations { _animations }
  
  construct new(file, dir) {
    Log.debug("Loading animation file '%(file)'")
    var document = XDocument.parse(FileSystem.load(file))
    var root = document.elementOrAbort("nitro_cell_animation_resource")
    // decides whether to play the animation. if null or empty we should play all
    var play = root.attributeValue("play")
    var playAll = play == null || play == ""

    // find the cell format and load the cells
    var cellCollElem = root.elementOrAbort("cell_collection")
    var format = cellCollElem.attributeValue("format", String)
    if (!CellFormat.all.contains(format)) {
      Fiber.abort("Unknown cell format '%(format)'")
    }
    _cellImages = {}
    for (cellImg in cellCollElem.elements("image").map{|x| CellImage.new(x, dir, format) }) {
      _cellImages[cellImg.name] = cellImg
    }
    // animations without frames are ignored
    _animations = []
    for (anim in root.elementOrAbort("animation_collection").elements("animation").map{|x| Animation.new(x)}) {
      if (anim.frames.count > 0 && (playAll || play == anim.name)) {
        _animations.add(anim)
      }
    }
  }

  update() {
    for (anim in _animations) {
      anim.update()
    }
  }

  draw(x, y) {
    // for some reason the draw order is back-to-front
    for (i in (_animations.count-1)..0) {
      var anim = _animations[i]
      var cellImage = _cellImages[anim.frame.image]
      for (cid in (cellImage.cells.count-1)..0) {
        var cell = cellImage.cells[cid]
        Canvas.draw(cell.image, x + cell.x, y + cell.y)
      }
    }
  }
}