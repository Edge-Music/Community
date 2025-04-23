import { ID, Song } from '../type/Adapter';
import { StyleConstants } from '../constants/StyleConstants';
import { DownloadProgress, SongDownloadManager } from '../util/SongDownloadManager';
import { MiniPlaybackControl } from '../component/MiniPlaybackControl';
import { TitleHeader } from '../component/TitleHeader';
import { ScrollIndexHandler } from '../util/ScrollIndexHandler';
import { HeaderAnimation } from '../component/HeaderAnimation';

const TAG = 'Download'

@Component
export struct Download {
  @State groupHeight: number = 0;
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageProp('bottomRect') bottomRect: number = 0;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('winHeight') winHeight: number = 0;
  @StorageLink('download_queue') queue: Map<ID, DownloadProgress> = new Map();
  private scrollController: Scroller = new Scroller();
  @State scrollIndexHandler: ScrollIndexHandler = new ScrollIndexHandler({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scrollController)

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.download'),
      backActive: this.scrollIndexHandler.currentIndex === 0
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // 标题
          this.Title()

          // 下载列表
          List({ scroller: this.scrollController }) {

            ListItem(){
              HeaderAnimation({ scrollIndexHandler: this.scrollIndexHandler })
            }

            if (this.queue.size === 0) {
              ListItem() {
                Column() {
                  Text($r('app.string.no_download_tasks'))
                    .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                    .fontSize(16)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(StyleConstants.FULL_HEIGHT)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
              }
            } else {
              ListItemGroup(){
                ForEach(Array.from(this.queue.entries()), (item: [string, DownloadProgress]) => {
                  ListItem() {
                    Column() {
                      // 歌曲信息
                      Row() {
                        Column() {
                          Text(item[1].song.name)
                            .fontSize(16)
                            .fontColor($r('app.color.text_primary'))
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .margin({ bottom: 4 })

                          Text(item[1].song.artists?.map(artist => artist.name).join(' / ') || '未知艺术家')
                            .fontSize(14)
                            .fontColor($r('app.color.text_secondary'))
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)

                        Text(`${Math.round(item[1].progress)}%`)
                          .fontSize(14)
                          .fontColor($r('app.color.text_click'))
                          .fontWeight(FontWeight.Medium)
                      }
                      .width(StyleConstants.FULL_WIDTH)
                      .padding({ bottom: 12 })
                    }
                    .width(StyleConstants.FULL_WIDTH)
                    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                    .backgroundColor($r('app.color.card_background'))
                    .borderRadius(12)
                    .margin({ bottom: 8 })
                  }
                  .width(StyleConstants.FULL_WIDTH)
                  .padding({ left: 16, right: 16 })
                })
              }
              .onAreaChange((oldValue: Area, newValue: Area) => {
                this.groupHeight = newValue.height as number
              })

              ListItem(){
                Row(){
                  // 监控ListItemGroup高度变化，随时调整List下方补充高度，winHeight - group高度 - 标题高度 - 避让高度
                  Blank().height(this.getBlankHeight())
                }
              }
            }

            // 底部空白区域
            ListItem() {
              Column() {
                Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
              }
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
          .expandSafeArea()
          .onWillScroll(this.scrollIndexHandler.scrollHandlers.onWillScroll)
          .onScrollStop(this.scrollIndexHandler.scrollHandlers.onScrollStop)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        // 底部迷你播控组件
        MiniPlaybackControl()
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    // .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .hideToolBar(true)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .expandSafeArea()
  }

  getBlankHeight(): Length {
    let sub = px2vp(this.winHeight) - this.groupHeight - 50 - px2vp(this.bottomRect+this.topRect)
    return sub > 0 ? sub : 0
  }
}