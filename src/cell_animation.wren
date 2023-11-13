/*

Load pattern animations from xml document
https://github.com/Deijin27/RanseiLink/blob/master/RanseiLink.Core/Graphics/Nitro/NSPAT.cs
https://github.com/Deijin27/RanseiLink/blob/master/RanseiLink.Core/Graphics/Conquest/NSPAT_RAW.cs

*/

import "xsequence" for XDocument
import "io" for FileSystem
import "util" for StringUtil

class Cell {
  x { _x }
  y { _y }
  width { _width }
  height { _height }
  flipX { _flipX }
  flipY { _flipY }
  image { _image }

  construct new(element) {
    _x = Num.fromString(element.attribute("x").value)
    _y = Num.fromString(element.attribute("y").value)
    _width = Num.fromString(element.attribute("width").value)
    _height = Num.fromString(element.attribute("height").value)
    _flipX = element.attributeValue("flip_x") == "true"
    _flipY = element.attributeValue("flip_y") == "true"
  }
}

class CellImage {
  name { _name }
  file { _file }
  cells { _cells }

  construct new(element) {
    _name = element.attribute("name").value
    _file = element.attribute("file").value
    _cells = element.elements("cell").map {|x| Cell.new(x) }.toList
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

  construct new(element) {
    _name = element.attribute("name").value
    _frames = element.elements("frame").map {|x| Frame.new(x) }.toList
  }
}

class AnimationResource {
  cellImages { _cellImages }
  animations { _animations }
  
  construct new(document) {
    var root = document.element("nitro_animation_resource")
    _cellImages = root.element("cell_collection").map{|x| CellImage.new(x) }.toList
    _animations = root.element("animation_collection").map{|x| Animation.new(x)}.toList
  }
}