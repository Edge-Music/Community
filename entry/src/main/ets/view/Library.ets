import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { Playlist, SourceConfig } from "../type/Adapter";
import { PushPathHelper } from "../util/PushPathHelper";
import { SourceAdapter } from "../adapter";
import { PlaylistList } from "../component/PlaylistList";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import FormUtils from "../util/FormUtils"
import { cover } from "../util/AdapterHelper";
import { promptAction, UIContext } from "@kit.ArkUI";
import { PreferencesCache } from "../util/PreferenceCache";
import { HeaderAnimation } from "../component/HeaderAnimation";
import { ScrollIndexHandler } from "../util/ScrollIndexHandler";
import { ResponseCacheUtil } from "../util/ResponseCacheUtil";

const TAG = 'Library'
@Builder
export function LibraryBuilder(){
  Library()
}

@Component
struct Library {
  subTitles: Resource[] = [$r('app.string.all_playlists'), $r('app.string.custom_playlists'), $r('app.string.collection_playlists')]
  @State itemHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageLink('user_playlist') playlists: Playlist[] = [];
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';
  @State isLoading: boolean = false;
  private scrollController: Scroller = new Scroller();
  @StorageProp('bottomRect') bottomRect: number = 0;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('winHeight') winHeight: number = 0;
  @StorageProp("user_data_source") adapters: SourceConfig[] = []
  @StorageLink("show_user_data_source") showAdapters: SourceConfig[] = PreferencesCache.getShowUserDataSource()
  @State sIndex: number = 0
  @State @Watch('onChangeSubTitleIndex') subTitleIndex: number = 0
  @State isExpanded: boolean = false
  @State capsuleOffset: number = 0
  @State capsuleWidth: number = 0
  @State titleWidths: number[] = []
  private readonly BUTTON_GAP: number = 15
  @State scaleX: number = 0.9
  @State scaleY: number = 1.0
  @State scrollIndexHandler: ScrollIndexHandler = new ScrollIndexHandler({
    onIndexChange: (index) => {
      this.onMenuIconClick(index)
    },
    componentTag: TAG
  }).linkController(this.scrollController)

  onChangeSubTitleIndex(){
    this.updateCapsulePosition(this.subTitleIndex)
  }

  onMenuIconClick(index: number) {
    if (index === 0) {
      this.pageStack.pop();
    } else if (index === 2) {
      // 触发刷新
      this.refreshData();
    }
  }

  async refreshData() {
    this.isLoading = true;

    try {
      this.playlists = await SourceAdapter.getUserPlaylist();
      ResponseCacheUtil.clear()
    } finally {
      this.isLoading = false;
    }
  }

  aboutToAppear(): void {
    if (this.playlists[1]?.cover){
      FormUtils.updateRecommendedCards(this.playlists[1].cover)
    }
  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.library'),
      backActive: this.scrollIndexHandler.currentIndex === 0,
      rightContent: () => {
        this.ButtonS()
      },
      midContent: () => {
        this.TabsTitles()
      }
    })
  }

  @Builder
  TabsTitles(){
    Stack(){
      Row(){
        Row()
          .width(this.capsuleWidth)
          .height(10)
          .backgroundColor($r('app.color.title_emphasis_color'))
          .borderRadius(5)
          .margin({ bottom: -20})
          .scale({ x: this.scaleX, y: this.scaleY })
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      }
      .height(35)
      .layoutWeight(1)
      .align(Alignment.BottomStart)
      .padding({ left: this.capsuleOffset })
      .animation({ duration: 500, curve: Curve.FastOutSlowIn })

      Row({ space: 15 }){
        ForEach(this.subTitles, (str: string, index: number) => {
          Text(str)
            .fontColor($r('app.color.text_secondary'))
            .fontWeight(FontWeight.Bold)
            .fontSize('20fp')
            .backgroundColor('transparent')
            .onClick(() => this.updateCapsulePosition(index))
            .onAreaChange((_, area) => {
              this.titleWidths[index] = area.width as number
              if (index === this.subTitleIndex) {
                this.capsuleWidth = area.width as number
              }
            })
            .margin({ bottom: -5 })
        })
      }
      .height(35)
      .align(Alignment.BottomStart)
      .layoutWeight(1)
    }
    .height(35)
    .layoutWeight(1)
    .padding({ left: 20 })
    .align(Alignment.BottomStart)
  }

  @Builder
  ButtonS(){
    Button({ type: ButtonType.Circle }){
      Image(cover(this.adapters[this.sIndex].auth?.user?.avatar, 200) ?? $r('app.media.portrait'))
        .width(35)
        .height(35)
        .borderRadius(17.5)
    }
    .shadow(ShadowStyle.OUTER_DEFAULT_XS)
    .backgroundColor('transparent')
    .onClick(() => {
      this.isExpanded = !this.isExpanded
    })
    .bindContextMenu(this.isExpanded, this.SwitchSourceMenu(),{
      onDisappear: () => {
        if(this.isExpanded){
          this.isExpanded = !this.isExpanded
        }
      }
    })
  }

  @Builder
  SwitchSourceMenu(){
    Menu(){
      ForEach(this.adapters, (adapter: SourceConfig, sIndex) => {
        MenuItem(this.SourceMenuContent(adapter, sIndex))
          .backgroundColor(this.getBackgroundColor(adapter))
          .border({
            width: 1,
            color: this.getBorderColor(adapter),
            style: BorderStyle.Solid
          })
          .margin(5)
          .borderRadius(20)
          .onClick(() => {
            const exists: boolean = this.showAdapters.some(adapterShow => adapterShow.id === adapter.id)
            if(!exists){
              PreferencesCache.addShowUserDataSource(adapter)
            }else{
              PreferencesCache.deleteShowUserDataSource(adapter.id)
            }
            this.sIndex = sIndex
            this.isExpanded = !this.isExpanded
          })
      })
    }
  }

  @Builder
  SourceMenuContent(sourceConfig: SourceConfig, sIndex: number){
    Row() {
      Row({ space: 5}) {
        Image(cover(sourceConfig.auth?.user?.avatar ?? ''))
          .width(20)
          .borderRadius(10)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        Text((sourceConfig.auth?.user?.name ?? '') + '（' + sourceConfig.name + '）')
          .maxLines(1)
          .fontColor($r('app.color.text_primary'))
          .fontSize('15fp')
          .fontWeight(FontWeight.Bold)
      }
    }
    .padding({
      left: 10,
      right: 10,
      top: 5,
      bottom: 5
    })
    .height(40)
  }

  private updateCapsulePosition(index: number) {
    let offset = 0
    for (let i = 0; i < index; i++) {
      offset += (this.titleWidths[i] || 0) + this.BUTTON_GAP
    }

    animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.scaleX = 0.4
      this.scaleY = 1.3
    })

    animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
      this.capsuleOffset = offset
    })

    animateTo({ duration: 150, curve: Curve.EaseIn }, () => {
      this.scaleX = 0.9
      this.scaleY = 1
      this.capsuleWidth = this.titleWidths[index]
      this.subTitleIndex = index
    })
  }

  private getBackgroundColor(sourceConfig: SourceConfig) {
    if (this.judgeHighLighting(sourceConfig)) {
      return 'rgba(100, 149, 237, 0.15)'; // 高亮背景色
    }
    return Color.Transparent;
  }

  judgeHighLighting(sourceConfig: SourceConfig): boolean {
    const result: boolean = this.showAdapters.some(adapter => adapter.id === sourceConfig.id)
    return result
  }

  private getBorderColor(sourceConfig: SourceConfig) {
    if (this.judgeHighLighting(sourceConfig)) {
      return 'rgba(100, 149, 237, 0.4)'; // 高亮边框色
    }
    return Color.Transparent;
  }

  showToast(msg: string) {
    promptAction.showToast({ message: msg, backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.BACKGROUND_THIN, bottom: StyleConstants.PLAYER_CONTROL_HEIGHT + 32 })
  }

  @Builder
  EmptyState() {
    Column() {
      Text('暂无歌单')
        .fontSize(16)
        .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Text('您还没有创建或收藏任何歌单')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
        .margin({ bottom: 24 })

      Button() {
        Row() {
          Image($r('app.media.ic_plus'))
            .width(18)
            .height(18)
            .fillColor(Color.White)
            .margin({ right: 8 })

          Text('创建歌单')
            .fontSize(16)
            .fontColor(Color.White)
        }
      }
      .width(150)
      .height(44)
      .borderRadius(22)
      .backgroundColor('#6A5ACD')
      .onClick(() => {
        // 创建歌单的逻辑
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // 标题
          this.Title()
          // 主内容
          List({ scroller: this.scrollController }) {
            // 下拉提示动画
            ListItem(){
              HeaderAnimation({ scrollIndexHandler: this.scrollIndexHandler, isShowLoadingProgress: true })
            }
            // 如果没有歌单，显示空状态
            if (this.playlists.length === 0) {
              ListItem() {
                this.EmptyState()
              }
              .width(StyleConstants.FULL_WIDTH)
            } else {
              // 我的歌单部分
              ListItem() {
                PlaylistList({
                  playlists: [...this.playlists],
                  sIndex: this.sIndex,
                  subTitleIndex: this.subTitleIndex,
                  adapters: this.adapters,
                  onPlaylistSelected: (item: Playlist) => {
                    PushPathHelper.pushPathImmediately(this.pageStack, "Playlist", async () => {
                      const playlist = await SourceAdapter.getPlaylistDetail(item)
                      AppStorage.setOrCreate('current_playlist_data', playlist)
                    })
                  }
                })
              }
              .width(StyleConstants.FULL_WIDTH)
              .onAreaChange((oldValue: Area, newValue: Area) => {
                this.itemHeight = newValue.height as number
              })

              ListItem(){
                Column(){
                  Blank().height(this.countSubVp())
                }
              }
            }

            // 添加底部空白区域，避开播放控制器和底部安全区域
            ListItem() {
              Column() {
                // 使用Column包裹空白区域，符合ArkTS规范
                // 主页底部避让高度：播控组件高度(60) + 播控组件下方margin值(16)
              }
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
              .backgroundColor('transparent')
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
          .expandSafeArea()
          .backToTop(true)
          .onWillScroll(this.scrollIndexHandler.scrollHandlers.onWillScroll)
          .onScrollStop(this.scrollIndexHandler.scrollHandlers.onScrollStop)
          .onReachEnd(() => {
            // 到达底部可以加载更多内容
            if (!this.isLoading) {
              // 加载更多逻辑
            }
          })
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
    .gesture(
      SwipeGesture({
        direction: SwipeDirection.Vertical,
      }).onAction((event) => {
        if (event.angle < 0) {
          // 向上滑
        } else {
          // 向下滑，返回上一页
          this.pageStack.pop();
        }
      })
    )
  }

  countSubVp(): number{
    let sub: number = 0
    // 填补高度=屏幕高度 - title高度50 - 上方padding高度12 - 单一组件高度(74+0.5)*歌曲数量 - 状态栏高度 - 导航栏高度
    sub = px2vp(this.winHeight) - (this.itemHeight+50+12) - px2vp(this.topRect+this.bottomRect)
    return sub > 0 ? sub : 0
  }
}