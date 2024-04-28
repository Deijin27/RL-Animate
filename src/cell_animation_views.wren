import "graphics" for Canvas, Color, ImageData
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView, Hotkey, Menu
import "math" for Math

class AnimationPanel {
  construct new(cellAnimationResource) {
    _res = cellAnimationResource
    _frameListFocused = false

    _animationsList = ListView.new("ANIMATIONS", _res.animations) {|item, x, y| 
      Canvas.print(item.name, x, y, AppColor.foreground)
    }
    _framesList = ListView.new("FRAMES", []) {|item, x, y| 
      Canvas.print(item.cluster, x, y, AppColor.foreground)
      Canvas.print(item.duration.toString, x + 40, y, AppColor.foreground)
    }
    _framesList.isFocused = false
  }

  selection { _animationsList.selectedIndex }
  framesListFocused { _framesList.isFocused }
  selectedAnim { _animationsList.selectedItem }
  selectedFrame { _framesList.selectedItem }

  update() {
    if (_animationsList.isFocused) {
      updateAnimFocused()
    } else {
      updateFrameFocused()
    }
  }

  updateAnimFocused() {
    if (Hotkey["delete"].justPressed && selectedAnim != null) {
      _animationsList.items.removeAt(_animationsList.selectedIndex)
      return
    }
    
    if (_animationsList.items.count > 0 && Hotkey["navigateForward"].justPressed) {
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
    }
  }

  updateFrameFocused() {
    if (Hotkey["delete"].justPressed && selectedFrame != null) {
      _framesList.items.removeAt(_framesList.selectedIndex)
      _res.reset()
    } else if (Hotkey["right"].justPressed) {
      changeFrameClusterId(selectedFrame, 1)
    } else if (Hotkey["left"].justPressed) {
      changeFrameClusterId(selectedFrame, -1)
    } else if (Hotkey["navigateBack"].justPressed) {
      // return to animations list
      _framesList.isFocused = false
      _animationsList.isFocused = true
    } else {
      _framesList.update()
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

  draw(x, y) {
    _animationsList.draw(x + 15, y + 130)
    _framesList.draw(x + 80, y + 130)
  }
}

class ClusterInfoForm {
  construct new() {
    _isFocused = false
    _title = "FILE"
  }
  title { _title }
  isFocused { _isFocused }
  isFocused=(value) { _isFocused = value }
  cluster { _cluster }
  cluster=(value) { _cluster = value }

  update() {
    
  }

  draw(x, y) {
    Canvas.print(title, x + 6, y, isFocused ? AppColor.domePurple : AppColor.gray)
    y = y + 10
    Canvas.print(_cluster.file, x + 6, y, AppColor.foreground)
  }
}

class ClusterPanel {
  construct new(cellAnimationResource) {
    _res = cellAnimationResource
    
    _clustersList = ListView.new("CLUSTERS", _res.clusters) {|item, x, y| 
      Canvas.print(item.name, x, y, AppColor.foreground)
    }
    _cellsList = ListView.new("CELLS", []) {|item, x, y| 
      Canvas.print("[%(item.x),%(item.y),%(item.width),%(item.height)]", x, y, AppColor.foreground)
    }
    _clusterInfo = ClusterInfoForm.new()
    _cellsList.isFocused = false
    _clusterInfo.isFocused = false
  }

  selection { _clustersList.selectedIndex }
  selectedCluster { _clustersList.selectedItem }
  cellFileFocused { _cellFileFocused }
  cellsListFocused { _cellsList.isFocused }
  selectedCell { _cellsList.selectedItem }

  update() {
    if (_clustersList.isFocused) {
      updateClustersFocused()
    } else if (_cellsList.isFocused) {
      updateCellsFocused()
    } else if (_clusterInfo.isFocused) {
      updateClusterInfoFocused()
    }
  }

  updateClustersFocused() {
    if (Hotkey["navigateForward"].justPressed) {
      _clusterInfo.isFocused = true
      _clustersList.isFocused = false
    } else {
      _clustersList.update()
      var sc = _clustersList.selectedItem
      if (sc != null) {
        _cellsList.items = sc.cells
        _clusterInfo.cluster = sc
      } else {
        _cellsList.items = []
      }
    }
  }

  updateCellsFocused() {
    if (Hotkey["navigateBack"].justPressed) {
      _cellsList.isFocused = false
      _clusterInfo.isFocused = true
    } else {
      _cellsList.update()
    }
  }

  updateClusterInfoFocused() {
    if (Hotkey["navigateForward"].justPressed) {
      _clusterInfo.isFocused = false
      _cellsList.isFocused = true
    } else if (Hotkey["navigateBack"].justPressed) {
      _clusterInfo.isFocused = false
      _clustersList.isFocused = true
    } else {
      _clusterInfo.update()
    }
  }

  draw(x, y) {
    y = y + 130

    _clustersList.draw(x + 15, y)

    var cellsListY = y
    var clusterInfoX = x + 80
    if (_res.format == CellFormat.oneImagePerCluster) {
      cellsListY = cellsListY + 20
      _clusterInfo.draw(clusterInfoX, y)
    }
    _cellsList.draw(clusterInfoX, cellsListY)
  }
}

class CellAnimationState {
  construct new(dir, animationFile) {
    _drawBackground = true
    _cellAnimationResource = CellAnimationResource.new(animationFile, dir)
    if (_cellAnimationResource.background != null) {
      var bgFile = dir + "/" + _cellAnimationResource.background
      _background = ImageData.load(bgFile)
    }

    _animationPanel = AnimationPanel.new(_cellAnimationResource)
    _clusterPanel = ClusterPanel.new(_cellAnimationResource)
    _currentPanel = _animationPanel
    _all = true
  }

  update() {
    _cellAnimationResource.update()
    if (Hotkey["toggleAllAnimations"].justPressed) {
      _all = !_all
    }
    if (Hotkey["toggleBackground"].justPressed) {
      _drawBackground = !_drawBackground
    }
    if (Hotkey["switchMode"].justPressed) {
      if (_currentPanel == _animationPanel) {
        _currentPanel = _clusterPanel
      } else {
        _currentPanel = _animationPanel
      }
    }
    _currentPanel.update()
  }

  draw(dt) {
    var x = 00
    var y = 00
    if (_background != null && _drawBackground) {
      Canvas.draw(_background, x, y)
    }

    if (_all) {
      _cellAnimationResource.draw(x, y)
    } else if (_currentPanel == _animationPanel) {
      if (_animationPanel.framesListFocused) {
        _cellAnimationResource.findCluster(_animationPanel.selectedFrame.cluster).draw(x, y)
      } else {
        _cellAnimationResource.drawAnimation(x, y, _animationPanel.selection)
      }
    } else {
      _clusterPanel.selectedCluster.draw(x, y)
    }

    if (_currentPanel == _clusterPanel) {
      var selectedCell = _clusterPanel.selectedCell
      for (cell in _clusterPanel.selectedCluster.cells) {
        Canvas.rect(x + cell.x, y + cell.y, cell.width, cell.height, (_clusterPanel.cellsListFocused && cell == selectedCell) ? AppColor.domePurple : AppColor.gray)
      }
    }

    _currentPanel.draw(x, y)

    var menu = Menu.new(["Add", "Rename", "Move", "Delete", "Duplicate"])
    menu.draw(220, 180)
  }
}