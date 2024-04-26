import "graphics" for Canvas, Color, ImageData
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView, Hotkey
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
    if (Hotkey["navigateForward"].justPressed) {
      // select frame
      _framesList.isFocused = true
      _animationsList.isFocused = false
    } else {
      _animationsList.update()
      _framesList.items = _animationsList.selectedItem.frames
    }
  }

  updateFrameFocused() {
    if (Hotkey["navigateBack"].justPressed) {
      // return to animations list
      _framesList.isFocused = false
      _animationsList.isFocused = true
    } else {
      _framesList.update()
    }
  }

  draw(x, y) {
    _animationsList.draw(x + 15, y + 130)
    _framesList.draw(x + 80, y + 130)
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
    _cellsList.isFocused = false
  }

  selection { _clustersList.selectedIndex }
  selectedCluster { _clustersList.selectedItem }
  cellsListFocused { _cellsList.isFocused }
  selectedCell { _cellsList.selectedItem }

  update() {
    if (_clustersList.isFocused) {
      updateClustersFocused()
    } else {
      updateCellsFocused()
    }
  }

  updateClustersFocused() {
    if (Hotkey["navigateForward"].justPressed) {
      // select frame
      _cellsList.isFocused = true
      _clustersList.isFocused = false
    } else {
      _clustersList.update()
      _cellsList.items = _clustersList.selectedItem.cells
    }
  }

  updateCellsFocused() {
    if (Hotkey["navigateBack"].justPressed) {
      // return to animations list
      _cellsList.isFocused = false
      _clustersList.isFocused = true
    } else {
      _cellsList.update()
    }
  }

  draw(x, y) {
    _clustersList.draw(x + 15, y + 130)
    _cellsList.draw(x + 80, y + 130)
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
    var x = 10
    var y = 10
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
  }
}