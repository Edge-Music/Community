import { SlideDownControl, slideTypeByTagConfigMap } from "./SlideDownController";

export interface ScrollIndexConfig {
  onIndexChange: (index: number) => void // 索引变化回调
  componentTag: string; // 组件TAG
}


export interface ScrollHandlersConfig {
  onWillScroll: (scrollOffset: number, state: ScrollState, source: ScrollSource) => void | ScrollResult
  onScrollStop?: () => void | ScrollResult
}

@Observed
export class ScrollIndexHandler {
  currentIndex: number = -1
  config: ScrollIndexConfig
  scrollController?: Scroller
  private defaultTag: string = 'Return'

  constructor(config: ScrollIndexConfig) {
    this.config = config
  }

  // 绑定到滚动组件的修饰器
  get scrollHandlers(): ScrollHandlersConfig {
    return {
      onWillScroll: (scrollOffset: number, state: ScrollState, source: ScrollSource) => {
        if (state === ScrollState.Scroll) {
          const positionY = this.scrollController?.currentOffset().yOffset || 0;
          this.handleScroll(positionY)
        }
      },
      onScrollStop: () => {
        this.config.onIndexChange(this.currentIndex)
        this.resetIndex()
      }
    };
  }

  // 关联ScrollController
  linkController(controller: Scroller): ScrollIndexHandler {
    this.scrollController = controller;
    return this;
  }

  private handleScroll(positionY: number) {
    if (positionY < 0) {
      const newIndex = (slideTypeByTagConfigMap[this.config.componentTag] ?? slideTypeByTagConfigMap[this.defaultTag]).computeFunction(positionY)
      this.currentIndex = newIndex
    } else {
      this.resetIndex()
    }
  }

  resetIndex(){
    this.currentIndex = -1
  }

  getText(): Resource {
    return (slideTypeByTagConfigMap[this.config.componentTag] ?? slideTypeByTagConfigMap[this.defaultTag]).getActionText(this.currentIndex)
  }
}
