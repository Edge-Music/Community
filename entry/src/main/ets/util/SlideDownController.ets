import { VibrationControl } from './DeviceController'

const _promptString: string[] = ["", "释放→设置", "释放→搜索", "下拉→刷新", "释放→刷新", "释放→上一页"]
const __promptString: string[] = ["", "设置←释放", "搜索←释放", "刷新←下拉", "刷新←释放", "上一页←释放"]
const promptString: Resource[] = [
  $r('app.string.blank'),
  $r('app.string.release_settings'),
  $r('app.string.release_search'),
  $r('app.string.pull_refresh'),
  $r('app.string.release_refresh'),
  $r('app.string.release_back')
]
type SlideTypeByTagConfigMap = Record<string, TagConfig>

class TagConfig {
  tag: string
  computeFunction: (offset: number) => number
  getActionText: (index: number) => Resource

  constructor(tag: string, computeFunction: (offsetY: number) => number, getFunction: (index: number) => Resource) {
    this.tag = tag
    this.computeFunction = computeFunction
    this.getActionText = getFunction
  }
}

class SlideTypeByTagConfig {
  static readonly LIBRARY = new TagConfig('Library', (offsetY: number) => SlideDownControl.calculateCurrentIndex(offsetY, 2), (index: number) => SlideDownControl.getLibraryActionText(index))
  static readonly INDEX = new TagConfig('Index', (offsetY: number) => SlideDownControl.calculateCurrentIndex(offsetY, 2), (index: number) => SlideDownControl.getIndexActionText(index))
  static readonly RETURN = new TagConfig('Return', (offsetY: number) => SlideDownControl.calculateCurrentIndex(offsetY, 0), (index: number) => SlideDownControl.getReturnActionText(index))
}

export const slideTypeByTagConfigMap: SlideTypeByTagConfigMap = {
  'Library': SlideTypeByTagConfig.LIBRARY,
  'Index': SlideTypeByTagConfig.INDEX,
  'Return': SlideTypeByTagConfig.RETURN
}

export class SlideDownControl {

  /**
   * 获取当前下拉索引
   * @param offset
   * @param maxIndex
   * @returns
   */
  public static calculateCurrentIndex(offset: number, maxIndex: number): number {
    offset = Math.abs(offset)
    if (offset < 40) {
      return -1
    }
    const index = Math.floor(offset / 72)
    return Math.min(Math.max(index, 0), maxIndex)
  }

  /**
   * 获取主页操作文本提示
   * @param index
   * @returns
   */
  public static getIndexActionText(index: number): Resource {
    switch (index) {
      case 0:
        VibrationControl.handlePresetVibration()
        return promptString[1];
      case 1:
        VibrationControl.handlePresetVibration()
        return promptString[2];
      case 2:
        VibrationControl.handlePresetVibration()
        return promptString[4];
      default:
        return promptString[0];
    }

  }
  /**
   * 获取歌单页操作文本提示
   * @param index
   * @returns
   */
  public static getLibraryActionText(index: number): Resource {
    switch (index) {
      case 0:
        VibrationControl.handlePresetVibration()
        return promptString[5];
      case 1:
        return promptString[3];
      case 2:
        VibrationControl.handlePresetVibration()
        return promptString[4];
      default:
        return promptString[0];
    }
  }

  /**
   * 获取返回上一页操作提示
   * @param index
   * @returns
   */
  public static getReturnActionText(index: number): Resource {
    switch (index) {
      case 0:
        VibrationControl.handlePresetVibration()
        return promptString[5];
      default:
        return promptString[0];
    }
  }
}