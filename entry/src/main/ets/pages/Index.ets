import { BreakpointSystem } from '../component/BreakpointSystem'
import { Cover } from '../component/Cover'
import { MenuButton } from '../component/MenuButton'
import { StyleConstants } from '../constants/StyleConstants'
import { HomePageMenu } from '../model/HomePageMenu'
import { ComingSoon } from '../view/ComingSoon'
import { HomePageMenuData } from '../viewmodel/HomePageMenuData'
import { MenuIcon } from '../component/MenuIcon'
import { Setting } from '../view/Setting'
import { PreferencesCache } from '../util/PreferenceCache'
import { Artist, Playlist, Song, SourceConfig } from '../type/Adapter'
import { SourceAdapter } from '../adapter'
import { cover } from '../util/AdapterHelper'
import { Segment } from '../component/Segment'
import { PlayList } from '../view/Playlist'
import { ToastUtil } from '@pura/harmony-utils'
import { PushPathHelper } from '../util/PushPathHelper'
import { PlaylistManager } from '../util/PlaylistManager'
import { MiniPlaybackControl } from '../component/MiniPlaybackControl'
import { MultiSearch } from '../view/MultiSearch'
import { LazyData } from '@pie/lazy-data'
import { HorizontalMode } from '../util/HorizontalCheck'
import { Download } from '../view/Download'
import { ScrollIndexHandler } from '../util/ScrollIndexHandler'
import { HeaderAnimation } from '../component/HeaderAnimation'
import { deviceInfo } from '@kit.BasicServicesKit'
// 缓存常用值以避免重复计算
const COLUMNS_TEMPLATE_LG = '1fr 1fr 1fr 1fr'
const COLUMNS_TEMPLATE_SM = '1fr 1fr'
const DEFAULT_COVER_SIZE = 256
const TAG = 'Index'

@Entry
@Component
struct Index {
  @Provide('NavPathStack') pageStack: NavPathStack = new NavPathStack()

  @Builder
  PageMap(name: string) {
    if (name === 'ComingSoon') {
      ComingSoon()
    } else if (name === 'Setting') {
      Setting()
    } else if (name === 'Playlist') {
      PlayList()
    } else if (name === 'MultiSearch') {
      MultiSearch()
    } else if (name === 'Index_page') {
      Index_page()
    } else if (name === 'Download') {
      Download()
    }
  }

  aboutToAppear(): void {
    this.pageStack.replacePath({ name: 'Index_page' })
  }

  build() {
    Navigation(this.pageStack) {
      // empty
    }
    .navDestination(this.PageMap)
    .hideNavBar(true)
    .mode(NavigationMode.Stack)
  }
}

@Component
struct Index_page {
  @State blankHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
  private breakpointSystem = new BreakpointSystem()
  private menuItems = HomePageMenuData
  private scrollController: Scroller = new Scroller()
  @StorageLink("user_data_source") adapters: SourceConfig[] = PreferencesCache.getUserDataSource()
  // 使用StorageLink保持数据同步
  @StorageLink("index_recommend_playlist") recommendPlaylist: Playlist[] = []
  @StorageLink("index_recommend_songs") recommendSongs: Song[] = []
  @StorageLink("index_recommend_artists") recommendArtists: Artist[] = []
  @StorageLink("index_recommend_toplist") topList: Playlist[] = []
  @State loading: boolean = true
  // 避让导航栏高度
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  @State HorizontalMode_ctrl: string = PreferencesCache.getUserPreference('HorizontalMode_ctrl', '0')
  // 预先计算并缓存必要的布局值
  private coverWidth: number = 120
  private segmentPadding: number = 4
  @State scrollIndexHandler: ScrollIndexHandler = new ScrollIndexHandler({
    onIndexChange: (index) => {
      this.onMenuIconClick(index)
    },
    componentTag: TAG
  }).linkController(this.scrollController)

  async aboutToAppear() {
    // 注册断点系统
    this.breakpointSystem.register()
    HorizontalMode(this.HorizontalMode_ctrl === '1')
    AppStorage.setOrCreate("pageStack", this.pageStack)
    // 立即初始化数据
    this.initData()
    let productSeries:string=deviceInfo.productSeries
    if(productSeries=='VDE') {
      PreferencesCache.setUserPreference('is_Pura_X', '1')
    }else {
      PreferencesCache.setUserPreference('is_Pura_X', '0')
    }
  }

  async initData() {
    this.loading = true

    try {
      // 并行加载数据并捕获异常
      await Promise.all([
        SourceAdapter.getRecommendList(),
        SourceAdapter.getRecommendSongs(),
        SourceAdapter.getRecommendArtists(),
        SourceAdapter.getTopList(),
        SourceAdapter.getUserPlaylist()
      ])
    } catch (error) {
      console.error('Failed to load data', error)
    } finally {
      this.loading = false
    }
  }

  private generatePlaylistMenu(playlist: Playlist): Array<MenuElement> {
    return [
      {
        value: $r('app.string.play_this_playlist'),
        action: () => {
          PushPathHelper.loading("Playing", async () => {
            const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
            const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
            if (!songs || songs.length === 0) {
              ToastUtil.showShort($r('app.string.no_playable_songs'))
              return
            }
            PlaylistManager.loadPlaylist(songs, songs[0])
          })
        }
      }
    ]
  }

  private generateSongMenu(song: Song): Array<MenuElement> {
    return [
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PlaylistManager.insertSongs([song])
        }
      }
    ]
  }

  aboutToDisappear() {
    this.breakpointSystem.unregister()
  }

  @Builder
  Title() {
    Row() {
      Text($r("app.string.homepage"))
        .fontColor($r('app.color.text_title'))
        .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
        .fontSize($r('app.float.title_font_size'))

      Row() {
        MenuIcon({
          icon: $r('app.media.ic_search'),
          active: this.scrollIndexHandler.currentIndex === 1
        })
          .onClick(() => {
            this.onMenuIconClick(1)
          })

        MenuIcon({
          icon: $r('app.media.ic_gearshape'),
          active: this.scrollIndexHandler.currentIndex === 0
        })
          .onClick(() => {
            this.onMenuIconClick(0)
          })
      }
      .height(StyleConstants.FULL_HEIGHT)
      .alignItems(VerticalAlign.Center)
    }
    .width(StyleConstants.FULL_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 16,
      right: 16
    })
    .expandSafeArea()
  }

  onMenuIconClick(index: number) {
    if (index === 0) {
      this.pageStack.pushPath({ name: 'Setting' })
    } else if (index === 1) {
      this.pageStack.pushPath({ name: 'MultiSearch' })
    } else if (index === 2) {
      this.initData()
    }
  }

  // 使用Builder模式优化各个部分的渲染
  @Builder
  MenuGrid() {
    Grid() {
      ForEach(this.menuItems, (item: HomePageMenu) => {
        GridItem() {
          MenuButton({
            title: item.title,
            onNavigate: () => {
              this.pageStack.pushPath({ name: item.path })
            }
          })
        }
        .padding(4)
      })
    }
    .columnsTemplate(this.currentBreakpoint === 'lg' ? COLUMNS_TEMPLATE_LG : COLUMNS_TEMPLATE_SM)
    .padding(12)
    .width(StyleConstants.FULL_WIDTH)
    .rowsGap(8)
    .columnsGap(8)
  }

  @Builder
  RecommendedSongs() {
    Segment({
      title: $r('app.string.hot_songs'),
      actionText: $r('app.string.rotate'),
      loading: this.loading,
      onActionClick: async () => {
        this.recommendSongs = await SourceAdapter.getRecommendSongs()
      },
    }) {
      List({ initialIndex: 0, space: 0 }) {
        LazyForEach(new LazyData(this.recommendSongs), (item: Song) => {
          ListItem() {
            Cover({
              src: cover(item.album.cover, DEFAULT_COVER_SIZE),
              title: item.name,
              subtitle: item.artists.map(artist => artist.name).join(' / '),
              menuItems: this.generateSongMenu(item)
            })
              .width(this.coverWidth)
              .padding(this.segmentPadding)
              .onClick(() => {
                PushPathHelper.loading("Playing", async () => {
                  PlaylistManager.insertSongs([item], -1, item)
                })
              })
          }
        })
      }
      .width('100%')
      .height('auto')
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .cachedCount(3) // 缓存更多项以提高性能
    }
  }

  @Builder
  RecommendedPlaylists() {
    Segment({
      title: $r('app.string.recommended_playlists'),
      actionText: $r('app.string.rotate'),
      loading: this.loading,
      onActionClick: async () => {
        this.recommendPlaylist = await SourceAdapter.getRecommendList()
      },
    }) {
      List({ initialIndex: 0, space: 0 }) {
        LazyForEach(new LazyData(this.recommendPlaylist), (item: Playlist) => {
          ListItem() {
            Cover({
              src: cover(item.cover, DEFAULT_COVER_SIZE),
              title: item.name,
              menuItems: this.generatePlaylistMenu(item)
            })
              .width(this.coverWidth)
              .padding(this.segmentPadding)
              .onClick(async () => {
                PushPathHelper.pushPathImmediately(this.pageStack, "Playlist", async () => {
                  const playlist = await SourceAdapter.getPlaylistDetail(item)
                  AppStorage.setOrCreate('current_playlist_data', playlist)
                })
              })
          }
        })
      }
      .width('100%')
      .height('auto')
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .cachedCount(3)
    }
  }

  @Builder
  RecommendedArtists() {
    Segment({
      title: $r('app.string.recommended_artists'),
      actionText: $r('app.string.rotate'),
      loading: this.loading,
      radius: "100%",
      onActionClick: async () => {
        this.recommendArtists = await SourceAdapter.getRecommendArtists()
      },
    }) {
      List({ initialIndex: 0, space: 0 }) {
        LazyForEach(new LazyData(this.recommendArtists), (item: Artist) => {
          ListItem() {
            Cover({
              src: cover(item.avatar, DEFAULT_COVER_SIZE),
              title: item.name,
              radius: "100%",
              titleAlign: HorizontalAlign.Center
            })
              .width(this.coverWidth)
              .padding(this.segmentPadding)
              .onClick(() => {
                PushPathHelper.pushPathImmediately(this.pageStack, "Playlist", async () => {
                  // 歌手复用歌单UI
                  const playlist = await SourceAdapter.getArtistDetail(item)
                  AppStorage.setOrCreate('current_playlist_data', playlist)
                })
              })
          }
        })
      }
      .width('100%')
      .height('auto')
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .cachedCount(3)
    }
  }

  @Builder
  TopLists() {
    Segment({
      title: $r('app.string.chart'),
      loading: this.loading
    }) {
      List({ initialIndex: 0, space: 0 }) {
        LazyForEach(new LazyData(this.topList), (item: Playlist) => {
          ListItem() {
            Cover({
              src: cover(item.cover, DEFAULT_COVER_SIZE),
              title: item.name,
              subtitle: item.description,
              menuItems: this.generatePlaylistMenu(item)
            })
              .width(this.coverWidth)
              .padding(this.segmentPadding)
              .onClick(async () => {
                PushPathHelper.pushPathImmediately(this.pageStack, "Playlist", async () => {
                  const playlist = await SourceAdapter.getPlaylistDetail(item)
                  console.log("zmhzmh");
                  AppStorage.setOrCreate('current_playlist_data', playlist)
                })
              })
          }
        })
      }
      .width('100%')
      .height('auto')
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .cachedCount(3)
    }
  }

  @Builder
  EmptyDataSource() {
    Column() {
      Row() {
        Text($r('app.string.add_data_source'))
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontColor($r('app.color.text_click'))
          .fontSize(16)
          .margin({ right: 2 })
          .onClick(() => {
            this.pageStack.pushPath({ name: 'Setting' })
          })
        Text("开启云上漫游！")
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontColor($r('app.color.text_hint'))
          .fontSize(15)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        List({ scroller: this.scrollController }) {
          ListItem() {
            HeaderAnimation({ scrollIndexHandler: this.scrollIndexHandler, isShowLoadingProgress: true })
          }

          if (this.adapters.length > 0) {
            if (this.recommendPlaylist.length > 0 && this.recommendSongs.length > 0
              && this.recommendArtists.length > 0 && this.topList.length > 0) {
              ListItem() {
                this.MenuGrid()
              }

              ListItem() {
                this.RecommendedSongs()
              }

              ListItem() {
                this.RecommendedPlaylists()
              }

              ListItem() {
                this.RecommendedArtists()
              }

              ListItem() {
                this.TopLists()
              }
            } else {
              ListItem() {
                this.MenuGrid()
              }
              .onAreaChange((oldValue: Area, newValue: Area) => {
                this.blankHeight = newValue.height as number
              })

              ListItem() {
                Row() {
                  Column() {
                    Text($r('app.string.no_recommendations'))
                      .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                      .fontColor($r('app.color.text_hint'))
                      .fontSize(16)
                  }
                  .width(StyleConstants.FULL_WIDTH)
                  .height(StyleConstants.FULL_HEIGHT)
                  .justifyContent(FlexAlign.Center)
                }
                .height(this.getBlankHeight())
              }
            }
          } else {
            ListItem() {
              this.EmptyDataSource()
            }
          }

          ListItem() {
            Row() {
              Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
            }
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .layoutWeight(1)
        .backToTop(true)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onWillScroll(this.scrollIndexHandler.scrollHandlers.onWillScroll)
        .onScrollStop(this.scrollIndexHandler.scrollHandlers.onScrollStop)
        .expandSafeArea()

        MiniPlaybackControl()
      }
      .height(StyleConstants.FULL_HEIGHT)
      .width(StyleConstants.FULL_WIDTH)
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
    .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .hideToolBar(true)
    .hideBackButton(true)
    .title({
      builder: this.Title(),
      height: 50,
    })
    .backgroundColor($r('app.color.page_background'))
  }

  getBlankHeight(): number {
    let sub = px2vp(this.winHeight) - this.blankHeight - 50 - px2vp(this.bottomRect + this.topRect)
    return sub > 0 ? sub : 0
  }
}