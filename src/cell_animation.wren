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
  static oneImagePerCluster { "OneImagePerCluster" }
  static all { [oneImagePerCell, oneImagePerCluster] }
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
    } else if (format == CellFormat.oneImagePerCluster) {
      _width = element.attributeValue("width", Num)
      _height = element.attributeValue("height", Num)
      transform["srcX"] = x 
      transform["srcY"] = y
      transform["srcW"] = width 
      transform["srcH"] = height
    }
    _image = image.transform(transform)
  }
}

class Cluster {
  name { _name }
  file { _file }
  cells { _cells }

  construct new(element, dir, format) {
    _name = element.attributeValue("name", String)
    var image = null
    if (format == CellFormat.oneImagePerCluster) {
      _file = element.attributeValue("file", String)
      image = ImageData.load(dir  + "/" + file)
    }
    _cells = element.elements("cell").map {|x| Cell.new(x, image, dir, format) }.toList
  }

  draw(x, y) {
    if (cells.count == 0) {
        return
      }
    for (cid in (cells.count-1)..0) {
      var cell = cells[cid]
      Canvas.draw(cell.image, x + cell.x, y + cell.y)
    }
  }
}

class Frame {
  cluster { _cluster }
  cluster=(value) { _cluster = value }
  duration { _duration }
  duration=(value) { _duration = value }
  
  construct new(element) {
    _cluster = element.attributeValue("cluster", String)
    _duration = element.attributeValue("duration", Num)
  }

  construct new() {
    _cluster = "cluster_0"
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

  construct new(element) {
    _name = element.attributeValue("name", String)
    Log.debug("Loaded animation %(_name)")
    // frames with zero duration are ignored
    _frames = element.elements("frame").map {|x| Frame.new(x) }.toList.where{|x| x.duration > 0 }.toList
    reset()
  }

  construct new() {
    _name = "new_anim"
    _frames = []
    reset()
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
  
  construct new(file, dir) {
    Log.debug("Loading animation file '%(file)'")
    var document = XDocument.parse(FileSystem.load(file))
    var root = document.elementOrAbort("nitro_cell_animation_resource")
    _background = root.attributeValue("background")
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
    if (_animations.count == 0) {
      return
    }
    for (i in (_animations.count-1)..0) {
      drawAnimation(x, y, i)
    }
  }

  drawAnimation(x, y, index) {
    var anim = _animations[index]
    var cluster = findCluster(anim.frame.cluster)
    cluster.draw(x, y)
  }

  reset() {
    for (anim in _animations) {
      anim.reset()
    }
  }
}