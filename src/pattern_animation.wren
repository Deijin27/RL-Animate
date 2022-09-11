/*

Load pattern animations from xml document
https://github.com/Deijin27/RanseiLink/blob/master/RanseiLink.Core/Graphics/Nitro/NSPAT.cs
https://github.com/Deijin27/RanseiLink/blob/master/RanseiLink.Core/Graphics/Conquest/NSPAT_RAW.cs

*/

import "xsequence" for XDocument
import "io" for FileSystem
import "util" for StringUtil

class KeyFrame {
  frame { _frame }
  texture { _texture }
  palette { _palette }
  
  construct new(element) {
    var fa = element.attribute("frame")
    _frame = fa == null ? 0 : Num.fromString(fa.value)
    var ta = element.attribute("texture")
    _texture = ta == null ? null : ta.value
    var pa = element.attribute("palette")
    _palette = pa == null ? null : pa.value
  }
}

class PatternAnimationTrack {
  keyFrames { _keyFrames }
  material { _material }

  construct new(element) {
    _keyFrames = []
    var mAttr = element.attribute("material")
    _material = mAttr == null ? null : mAttr.value
    for (ke in element.elements("key_frame")) {
      _keyFrames.add(KeyFrame.new(ke))
    }
  }

  sample(frame) {
    for (i in 0...keyFrames.count) {
      var kf = keyFrames[i]
      if (kf.frame > frame) {
        if (i == 0) {
          return keyFrames[0]
        } else {
          return keyFrames[i - 1]
        }
      }
    }
    return keyFrames[-1]
  }
}

class PatternAnimation {
  name { _name }
  name=(x) { _name = x }
  numFrames { _numFrames }
  numFrames=(x) { _numFrames = x }
  tracks { _tracks }
  
  construct new(element) {
    var nAttr = element.attribute("name")
    _name = nAttr == null ? null : nAttr.value
    var nfAttr = element.attribute("num_frames")
    _numFrames = nfAttr == null ? 0 : Num.fromString(nfAttr.value)
    _tracks = []
    for (te in element.elements("track")) {
      _tracks.add(PatternAnimationTrack.new(te))
    }
  }

  sample(material, frame) {
    var relativeFrame = frame % numFrames
    for (track in tracks) {
      if (track.material == material) {
        return track.sample(relativeFrame)
      }
    }
    Fiber.abort("No track found with the material")
  }
}

class LibraryPatternAnimations {
  animations { _animations }
  
  construct new(element) {
    _animations = []
    for (pe in element.elements("pattern_animation")) {
      _animations.add(PatternAnimation.new(pe))
    }
  }

  find(orientation, direction, type) {
    var find = "%(orientation)%(direction)_%(type)"
    for (anim in _animations) {
      if (anim.name.endsWith(find)) {
        return anim
      }
    }
    return null
  }
}

class LibraryPatternAnimationCollection {
  library { _library }
  libraryRaw { _libraryRaw }
  longAttack { _longAttack }
  asymmetrical { _asymmetrical }
  
  construct new(text) {
    var doc = XDocument.parse(text)
    var root = doc.root
    var nonRawEl = root.element("library_pattern_animations")
    _library = LibraryPatternAnimations.new(nonRawEl)
    var rawEl = root.element("library_raw_pattern_animations")
    _libraryRaw = LibraryPatternAnimations.new(rawEl)

    var laAttr = root.attribute("long_attack")
    _longAttack = laAttr != null && laAttr.value == "true"

    var asymAttr = root.attribute("asymmetrical")
    _asymmetrical = asymAttr != null && asymAttr.value == "true"
  }

  populateLibraryRawTextures() {
    var baseFix = 0
    for (anim in _libraryRaw) {
      var track = anim.tracks[0]
      
    }
  }
}