import { StyleConstants } from "../constants/StyleConstants";
import { avPlayerManager } from "../util/AVPlayerManager";
import { PreferencesCache } from "../util/PreferenceCache";
import { LengthMetrics } from '@kit.ArkUI'
import { LyricsLine } from "../util/LyricsManager";
import { VibrationControl } from "../util/DeviceController";

class LyricStyle {
  fontWeight: FontWeight;
  fontColor: string | Color;
  background: string;
  opacity: number;

  constructor(fontWeight: FontWeight, fontColor: string | Color, background: string, opacity: number) {
    this.fontWeight = fontWeight;
    this.fontColor = fontColor;
    this.background = background;
    this.opacity = opacity;
  }
}

@Component
export struct LyricsView {
  @StorageProp('current_parsed_lyrics') private parsedLyrics: Array<LyricsLine> = []
  @StorageLink('current_lyrics_index') @Watch("onTimeUpdate") private currentLyricsIndex: number = 0
  @State mode_judge: boolean = false
  @State private isAnimating: boolean = false
  @State private showTranslation: boolean = PreferencesCache.showTranslationLyric()
  @StorageProp('current_lyrics_has_translation') private hasTranslation: boolean = false // 是否有翻译歌词
  @StorageProp('current_lyrics_has_transliteration') private hasTransliteration: boolean = false
  private scroller: Scroller = new Scroller()
  private readonly ANIMATION_DURATION: number = 300
  private readonly SCROLL_ANIMATION_DURATION: number = 400
  private lastTriggerTime: number = 0;

  aboutToAppear() {
    this.scrollToLyric(this.currentLyricsIndex)
  }

  // 监听当前播放时间更新
  onTimeUpdate() {
    // 如果索引变化且不在动画中，则更新并滚动
    if (this.currentLyricsIndex !== -1 && !this.isAnimating) {
      this.isAnimating = true
      this.scrollToLyric(this.currentLyricsIndex)
    }
  }

  // 滚动到指定歌词位置
  private scrollToLyric(index: number) {
    if (index < 0) {
      return
    }

    // 保持在视图中间偏上的位置，很显然这是一个经验修正
    const targetIndex = Math.max(0, this.mode_judge ? index - (5 * (this.showTranslation ? 0.2 : 0.6)) : index - (this.showTranslation ? 0 : 1))

    animateTo({
      duration: this.SCROLL_ANIMATION_DURATION,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.isAnimating = false
      }
    }, () => {
      this.scroller.scrollToIndex(targetIndex)
    })
  }

  // 歌词点击处理
  private handleLyricClick(time: number, index: number) {
    // 更新UI状态
    this.isAnimating = true
    this.currentLyricsIndex = index

    // 滚动到目标位置
    this.scrollToLyric(index)

    // 跳转到指定时间
    avPlayerManager.seek(time)
  }

  // 切换翻译显示状态
  private toggleTranslation() {
    animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
      this.showTranslation = !this.showTranslation
      this.scrollToLyric(this.currentLyricsIndex)
      PreferencesCache.showTranslationLyric(this.showTranslation)
      VibrationControl.handlePresetVibration()
    })
  }

  // 获取歌词显示样式
  private getLyricStyle(index: number) {
    const isCurrent = index === this.currentLyricsIndex

    return new LyricStyle(
      isCurrent ? StyleConstants.FONT_WEIGHT_SEVEN : StyleConstants.FONT_WEIGHT_FIVE,
      isCurrent ? Color.White : 'rgba(255, 255, 255, 0.6)',
      isCurrent ? 'rgba(255, 255, 255, 0.1)' : 'transparent',
      isCurrent ? 1 : 0.7
    )
  }

  /**
   * 双指操作防抖
   * @param func
   */
  private debounce(func: Function) {
    const now = Date.now();
    if (now - this.lastTriggerTime > 300) {
      func();
      this.lastTriggerTime = now;
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        if (this.parsedLyrics.length === 0) {
          Text($r('app.string.no_lyric_available'))
            .fontSize(18)
            .fontColor('rgba(255, 255, 255, 0.5)')
            .margin(16)
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.parsedLyrics, (item: LyricsLine, index) => {
              ListItem() {
                Column() {
                  // 原文歌词
                  Text(item.text)
                    .fontSize(20)
                    .fontWeight(this.getLyricStyle(index).fontWeight)
                    .fontColor(this.getLyricStyle(index).fontColor)
                    .margin({ top: 4, bottom: this.showTranslation && item.translation ? 0 : 4 })
                    .padding({
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: 8
                    })
                    .textAlign(TextAlign.Center)
                    .borderRadius(8)
                    .backgroundColor(this.getLyricStyle(index).background)
                    .opacity(this.getLyricStyle(index).opacity)
                    .animation({
                      duration: this.ANIMATION_DURATION,
                      curve: Curve.EaseInOut
                    })

                  // 翻译歌词 (仅当启用显示翻译且该行有翻译时显示)
                  if (this.showTranslation && item.translation) {
                    Text(item.translation)
                      .fontSize(16)
                      .fontWeight(FontWeight.Normal)
                      .fontColor(this.getLyricStyle(index).fontColor)
                      .opacity(this.getLyricStyle(index).opacity * 0.9)
                      .margin({ bottom: 4 })
                      .padding({
                        left: 16,
                        right: 16,
                        top: 4,
                        bottom: 4
                      })
                      .textAlign(TextAlign.Center)
                      .borderRadius(8)
                      .backgroundColor('transparent')
                      .animation({
                        duration: this.ANIMATION_DURATION,
                        curve: Curve.EaseInOut
                      })
                  }

                  // 音译歌词 (仅当启用显示翻译且该行有翻译时显示)
                  if (this.showTranslation && item.transliteration) {
                    Text(item.transliteration)
                      .fontSize(16)
                      .fontWeight(FontWeight.Normal)
                      .fontColor(this.getLyricStyle(index).fontColor)
                      .opacity(this.getLyricStyle(index).opacity * 0.9)
                      .margin({ bottom: 4 })
                      .padding({
                        left: 16,
                        right: 16,
                        top: 4,
                        bottom: 4
                      })
                      .textAlign(TextAlign.Center)
                      .borderRadius(8)
                      .backgroundColor('transparent')
                      .animation({
                        duration: this.ANIMATION_DURATION,
                        curve: Curve.EaseInOut
                      })
                  }
                }
                .width(StyleConstants.FULL_WIDTH)
                .onClick(() => {
                  this.handleLyricClick(item.time, index)
                })
              }
              .width(StyleConstants.FULL_WIDTH)
            })
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .expandSafeArea()
          .contentEndOffset(10)
          .contentStartOffset(10)
          .fadingEdge(true,{fadingEdgeLength:LengthMetrics.vp(80)})
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)

      if ((this.hasTranslation || this.hasTransliteration) && this.mode_judge === true) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_translate'))
            .width(24)
            .height(24)
            .fillColor((this.hasTranslation || this.hasTransliteration) ? Color.White : 'rgba(255, 255, 255, 0.6)')
        }
        .width(48)
        .height(48)
        .backgroundColor(this.showTranslation ? 'rgba(255, 255, 255, 0.2)' : Color.Transparent)
        .margin({ bottom: 24, right: 24 })
        .position({ x: '100%', y: '100%' })
        .translate({ x: -72, y: -72 })
        .onClick(() => this.toggleTranslation())
        .animation({
          duration: 300,
          curve: Curve.EaseInOut
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .expandSafeArea()
    .gesture(
      PinchGesture()
        .onActionUpdate((event: PinchGestureEvent) => {
          if (event.scale > 1.1) {
            this.debounce(() => {
              if(!this.showTranslation && (this.hasTranslation || this.hasTransliteration)){
                this.toggleTranslation()
              }
            });
          } else if (event.scale < 0.9) {
            this.debounce(() => {
              if(this.showTranslation && (this.hasTranslation || this.hasTransliteration)){
                this.toggleTranslation()
              }
            });
          }
        })
    )
  }
}