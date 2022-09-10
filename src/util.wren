class StringUtil {
  static padLeft(str, totalWidth, paddingChar) {
    while (str.count < totalWidth) {
      str = paddingChar + str
    }
  }
}