/*

Load pattern animations from xml document
https://github.com/Deijin27/RanseiLink/blob/master/RanseiLink.Core/Graphics/Nitro/NSPAT.cs
https://github.com/Deijin27/RanseiLink/blob/master/RanseiLink.Core/Graphics/Conquest/NSPAT_RAW.cs

*/

import "xsequence" for XDocument
import "io" for FileSystem
import "util" for StringUtil
import "graphics" for ImageData, Canvas
import "dome" for Log

class Cell {
  x { _x }
  y { _y }
  width { _width }
  height { _height }
  flipX { _flipX }
  flipY { _flipY }
  image { _image }

  construct new(element, image) {
    _x = Num.fromString(element.attribute("x").value)
    _y = Num.fromString(element.attribute("y").value)
    _width = Num.fromString(element.attribute("width").value)
    _height = Num.fromString(element.attribute("height").value)
    _flipX = element.attributeValue("flip_x") == "true"
    _flipY = element.attributeValue("flip_y") == "true"

    var transform = {
      "srcX": x, 
      "srcY": y,
      "srcW": width, 
      "srcH": height
    }
    _image = image.transform(transform)
  }
}

class CellImage {
  name { _name }
  file { _file }
  cells { _cells }

  construct new(element, dir) {
    _name = element.attribute("name").value
    _file = element.attribute("file").value
    var image = ImageData.load(dir  + "/" + file)
    _cells = element.elements("cell").map {|x| Cell.new(x, image) }.toList
  }
}

class Frame {
  image { _image }
  duration { _duration }
  
  construct new(element) {
    _image = element.attribute("image").value
    _duration = Num.fromString(element.attribute("duration").value)
  }
}

class Animation {
  name { _name }
  frames { _frames }
  frame { _frame }

  construct new(element) {
    _name = element.attribute("name").value
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
    var root = document.element("nitro_cell_animation_resource")
    if (root == null) {
      Fiber.abort("CellAnimationResource document missing root element 'nitro_cell_animation_resource'")
    }
    // decides whether to play the animation. if null or empty we should play all
    var play = root.attributeValue("play")
    var playAll = play == null || play == ""

    _cellImages = {}
    for (cellImg in root.element("cell_collection").elements("image").map{|x| CellImage.new(x, dir) }) {
      _cellImages[cellImg.name] = cellImg
    }
    // animations without frames are ignored
    _animations = []
    for (anim in root.element("animation_collection").elements("animation").map{|x| Animation.new(x)}) {
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
      for (cell in cellImage.cells) {
        Canvas.draw(cell.image, x + cell.x, y + cell.y)
      }
    }
  }
}