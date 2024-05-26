import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView, Hotkey, Menu, TextInputDialog
import "math" for Math

class Field {
  model { _model }
  model=(v) { _model = v }

  name { _name }
  withName(v) { 
    _name = v 
    return this
  }

  getter { _getter }
  withGetter(v) { 
    _getter = v
    return this
  }

  setter { _setter }
  withSetter(v) { 
    _setter = v
    return this
  }

  getValue() {
    return _getter.call(_model)
  }

  setValue(newValue) {
    if (getValue() != newValue) {
      _setter.call(_model, newValue)
    }
  }

  update() {
  }

  getValueString() {
    var val = getValue()
    if (val == null) {
      return "---"
    } else {
      return val.toString
    }
  }

  draw(x, y) {
    Canvas.print(name, x, y, AppColor.foreground)
    Canvas.print(getValueString(), x + 40, y, AppColor.foreground)
  }
}

class SelectorField is Field {
  construct new() {
    _items = []
  }

  items { _items }
  withItems(v) { 
    _items = v
    return this
  }

  update() {
    super.update()

    var currentValue = getValue()
    var currentIndex = _items.indexOf(currentValue)

    var newIndex = currentIndex

    var leftRepeats = Hotkey["left"].repeats
    var rightRepeats = Hotkey["right"].repeats

    if (leftRepeats > 20) {
      if (leftRepeats % 5 == 0) {
        newIndex = currentIndex - 1
      }
    } else if (rightRepeats > 20) {
      if (rightRepeats % 5 == 0) {
        newIndex = currentIndex + 1
      }
    } else if (Hotkey["left"].justPressed) {
      newIndex = currentIndex - 1
    } else if (Hotkey["right"].justPressed) {
      newIndex = currentIndex + 1
    }

    newIndex = coerceIndex(newIndex)
    var newValue = newIndex == -1 ? null : _items[newIndex]
    setValue(newValue)
  }
  
  coerceIndex(index) {
    if (_items.count == 0) {
      return -1
    }
    if (index < -1) {
      return -1
    } else if (index >= (_items.count - 1)) {
      return _items.count - 1
    } else {
      return index
    }
  }
}

class NumberField is Field {
  construct new() {
    _min = 0
    _max = 1000
  }

  min { _min }
  withMin(v) { 
    _min = v
    return this
  }

  max { _max }
  withMax(v) { 
    _max = v
    return this
  }

  update() {
    super.update()

    var currentValue = getValue()
    var newValue = currentValue

    var leftRepeats = Hotkey["left"].repeats
    var rightRepeats = Hotkey["right"].repeats

    if (leftRepeats > 20) {
      if (leftRepeats % 5 == 0) {
        newValue = currentValue - 1
      }
    } else if (rightRepeats > 20) {
      if (rightRepeats % 5 == 0) {
        newValue = currentValue + 1
      }
    } else if (Hotkey["left"].justPressed) {
      newValue = currentValue - 1
    } else if (Hotkey["right"].justPressed) {
      newValue = currentValue + 1
    }

    newValue = coerceValue(newValue)
    setValue(newValue)
  }

  coerceValue(value) {
    if (value < min) {
      return min
    } else if (value > max) {
      return max
    } else {
      return value
    }
  }
}

class Form is ListView {
  construct new(title, fields) {
    super(title, fields, Fn.new {|item, x, y| item.draw(x, y) })
    _fields = fields
  }

  update() {
    super.update()

    var si = selectedItem
    if (si != null) {
      si.update()
    }
  }

  model { _model }
  model=(v) {
    _model = v
    for (f in _fields) {
      f.model = _model
    }
  }
}



class AnimationPanel {

  name { "ANIMATIONS" }

  allowSwapPanel { !_framesForm.isFocused }

  update() {
    if (_animationsList.isFocused) {
      _animStateActions[_state].call()
    } else if (_framesList.isFocused) {
      _frameStateActions[_state].call()
    } else {
      _frameItemStateActions[_state].call()
    }
  }

  draw(x, y) {
    _animationsList.draw(x, y)
    _framesList.draw(x + 65, y)
    _framesForm.draw(x + 130, y)
    if (_menu != null) {
      _menu.draw(220, 160)
    }
    if (_textDialog != null) {
      _textDialog.draw(200, 180)
    }
  }

  construct new(cellAnimationResource) {
    _res = cellAnimationResource
    _frameListFocused = false

    _animationsList = ListView.new("ANIMATIONS", _res.animations) {|item, x, y| 
      Canvas.print(item.name, x, y, AppColor.foreground)
    }
    _framesList = ListView.new("FRAMES", []) {|item, x, y|
      var clust = item.cluster
      Canvas.print(clust == null ? "---" : clust, x, y, AppColor.foreground)
      Canvas.print(item.duration.toString, x + 40, y, AppColor.foreground)
    }

    var frameFields = []

    var clusterField = SelectorField.new()
      .withName("Cluster")
      .withGetter {|m| m.cluster }
      .withSetter {|m, v| m.cluster = v }
      .withItems(cellAnimationResource.clusters.map{|x| x.name }.toList)

    var durationField = NumberField.new()
      .withName("Duration")
      .withGetter {|m| m.duration }
      .withSetter {|m, v| 
        m.duration = v 
        _res.reset()
      }
      .withMin(1)

    frameFields.add(clusterField)
    frameFields.add(durationField)

    _framesForm = Form.new("FRAME", frameFields)
    _framesForm.width = 80

    _framesList.isFocused = false
    _framesForm.isFocused = false
    _state = "list"

    _animStateActions = {
      "list": Fn.new { 
        updateAnimFocused() 
      },
      "rename" : Fn.new {
        _textDialog.update()
        if (_textDialog.complete) {
          if (_textDialog.proceed) {
            selectedAnim.name = _textDialog.text
          }
          _state = "list"
          _textDialog = null
        }
      },
      "menu" : Fn.new {
        _menu.update()
        if (_menu.complete) {
          if (_menu.proceed) {
             _animMenuActions[_menu.selected].call()
          } else {
            _state = "list"
          }
          _menu = null
        }
      },
      "move" : Fn.new {
        // TODO: have some text per-state, maybe which replaces the left top bar text
        // and this says "MOVING ITEM..." etc.
        if (Hotkey["navigateBack"].justPressed) {
          _state = "list"
          _animationsList.moving = false
        } else {
          _animationsList.update()
        }
      },
    }

    _frameStateActions = {
      "list": Fn.new { 
        updateFrameFocused() 
      },
      "menu": Fn.new {
       _menu.update()
        if (_menu.complete) {
          if (_menu.proceed) {
             _frameMenuActions[_menu.selected].call()
          } else {
            _state = "list"
          }
          _menu = null
        }
      },
      "move" : Fn.new {
        if (Hotkey["navigateBack"].justPressed) {
          _state = "list"
          _framesList.moving = false
        } else {
          _framesList.update()
        }
      }
    }

    _frameItemStateActions = {
      "list": Fn.new {
        updateFrameItemFocused()
      }
    }

    _animMenuActions = {
      "Add": Fn.new {
        var targetPos = _animationsList.items.count > 0 ? _animationsList.selectedIndex + 1 : 0
        _animationsList.items.insert(targetPos, Animation.new())
        _animationsList.selectedIndex = targetPos
        beginRename()
      },
      "Rename" : Fn.new {
        beginRename()
      },
      "Move" : Fn.new {
        _state = "move"
        _animationsList.moving = true
      },
      "Delete": Fn.new {
        _animationsList.items.removeAt(_animationsList.selectedIndex)
        _state = "list"
      },
      "Duplicate": Fn.new {
        var targetPos = _animationsList.items.count > 0 ? _animationsList.selectedIndex + 1 : 0
        _animationsList.items.insert(targetPos, selectedAnim.clone())
        _animationsList.selectedIndex = targetPos
        _menu = null
        beginRename()
      }
    }

    _frameMenuActions = {
      "Add": Fn.new {
        var targetPos = _framesList.items.count > 0 ? _framesList.selectedIndex + 1 : 0
        _framesList.items.insert(targetPos, Frame.new())
        _state = "list"
      },
      "Move" : Fn.new {
        _state = "move"
        _framesList.moving = true
      },
      "Delete": Fn.new {
        _framesList.items.removeAt(_framesList.selectedIndex)
        _res.reset()
        _state = "list"
      },
      "Duplicate": Fn.new {
        var targetPos = _framesList.items.count > 0 ? _framesList.selectedIndex + 1 : 0
        _framesList.items.insert(targetPos, selectedFrame.clone())
        _state = "list"
      }
    }
  }

  beginRename() {
    _state = "rename"
    _textDialog = TextInputDialog.new(selectedAnim.name) {|text|
      // validate
      if (text.count == 0) {
        return false
      }
      for (i in 0..._animationsList.items.count) {
        if (i != _animationsList.selectedIndex && _animationsList.items[i].name == text) {
          return false
        }
      }
      return true
    }
  }

  selection { _animationsList.selectedIndex }
  framesListFocused { _framesList.isFocused }
  selectedAnim { _animationsList.selectedItem }
  selectedFrame { _framesList.selectedItem }

  

  updateAnimFocused() {
    if (Hotkey["menu"].justPressed) {
      _menu = _animationsList.items.count == 0 ? Menu.new(["Add"]) : Menu.new(["Add", "Rename", "Move", "Delete", "Duplicate"])
      _state = "menu"
    } else if (_animationsList.items.count > 0 && Hotkey["navigateForward"].justPressed) {
      // select frame
      _framesList.isFocused = true
      _animationsList.isFocused = false
    } else {
      _animationsList.update()
      var sa = selectedAnim
      if (sa != null) {
        _framesList.items = sa.frames
      } else {
        _framesList.items = []
      }
      _framesForm.model = selectedFrame
    }
  }

  updateFrameFocused() {
    if (Hotkey["menu"].justPressed) {
      _menu = _framesList.items.count == 0 ? Menu.new(["Add"]) : Menu.new(["Add", "Move", "Delete", "Duplicate"])
      _state = "menu"
    } else if (Hotkey["navigateBack"].justPressed) {
      // return to animations list
      _framesList.isFocused = false
      _animationsList.isFocused = true
    } else if (Hotkey["navigateForward"].justPressed) {
      _framesList.isFocused = false
      _framesForm.isFocused = true
    } else {
      _framesList.update()
      _framesForm.model = selectedFrame
    }
  }

  updateFrameItemFocused() {
    if (Hotkey["navigateBack"].justPressed) {
      _framesForm.isFocused = false
      _framesList.isFocused = true
    } else {
      _framesForm.update()
    }
  }

  changeFrameClusterId(frame, change) {
    var clusterIndex = _res.findClusterIndex(frame.cluster) + change
    if (clusterIndex >= _res.clusters.count) {
      clusterIndex = 0
    } else if (clusterIndex < 0) {
      clusterIndex = _res.clusters.count - 1
    }
    frame.cluster = _res.clusters[clusterIndex].name
  }

  
}