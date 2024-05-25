import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView, Hotkey, Menu, TextInputDialog
import "math" for Math

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

  name { "CLUSTERS" }

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
    _clustersList.draw(x, y)

    var cellsListY = y
    var clusterInfoX = x + 65
    if (_res.format == CellFormat.oneImagePerCluster) {
      cellsListY = cellsListY + 20
      _clusterInfo.draw(clusterInfoX, y)
    }
    _cellsList.draw(clusterInfoX, cellsListY)
  }
}