import { AlbumCoversCarousel } from "../component/AlbumCoversCarousel";
import { SongInfo } from "../component/SongInfo";
import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { Playlist, Song } from "../type/Adapter";
import { BasicPrefetcher } from '@kit.ArkUI';
import { SongDataSourcePrefetching } from "../util/SongDataSourcePrefetching";
import { BreakpointConstants } from "../constants/BreakpointConstants";
import { cover } from "../util/AdapterHelper";
import { PushPathHelper } from "../util/PushPathHelper";
import { PlaylistManager, PlayMode } from "../util/PlaylistManager";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import { SongDownloadManager } from "../util/SongDownloadManager";
import { ScrollIndexHandler } from "../util/ScrollIndexHandler";
import { HeaderAnimation } from "../component/HeaderAnimation";
import { ResourceManager } from "../util/ResourceManager";
import { ToastUtil } from "@pura/harmony-utils";

const TAG = 'PlayList'

@Component
export struct PlayList {
  @State searchContext: string = ResourceManager.getStringValueSync($r('app.string.search'))
  @State groupHeight: number = 0;
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageLink("current_playlist_data") playlist: Playlist | null = null
  @Watch('onBreakpointChange') @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
  private songDataSource: SongDataSourcePrefetching = new SongDataSourcePrefetching(null);
  private prefetcher: BasicPrefetcher | null = null;
  private sourceOk: boolean = false;
  private scrollController: Scroller = new Scroller();
  @State isLoading: boolean = false;
  // 点击跳转后的闪烁效果索引
  @State billingIndex: number = -1
  // 是否为宽屏模式
  @State isWideScreen: boolean = false
  @StorageLink("cache_data_create_time") cacheTime: number = -1
  @StorageLink("current_playing_song") song: Song | null = null
  @StorageProp('bottomRect') bottomRect: number = 0;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('winHeight') winHeight: number = 0;
  // 搜索相关状态
  @State searchKeywords: string = ''
  @State filteredSongs: Song[] = []
  @State isSearching: boolean = false
  @State scrollIndexHandler: ScrollIndexHandler = new ScrollIndexHandler({
    onIndexChange: (index) => {
      this.onMenuIconClick(index)
    },
    componentTag: TAG
  }).linkController(this.scrollController)

  @Builder
  Title() {
    TitleHeader({
      title: this.playlist?.name,
      backActive: this.scrollIndexHandler.currentIndex === 0,
    })
  }

  aboutToAppear(): void {
    // 初始化数据源
    this.songDataSource = new SongDataSourcePrefetching(this.playlist);
    // 创建预取器
    this.prefetcher = new BasicPrefetcher(this.songDataSource);
    // 设置屏幕模式
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;

    this.sourceOk = true;
  }

  // 监听屏幕断点变化
  onBreakpointChange() {
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
  }

  aboutToDisappear(): void {
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  @Builder
  PlayListAction() {
    Stack() {
      // Column()
      //   .width(StyleConstants.FULL_WIDTH)
      //   .height(54)
      //   .linearGradientBlur(10, {
      //     fractionStops: [
      //       [0.00, 0.00],
      //       [0.50, 0.10],
      //       [1.00, 1.00]
      //     ],
      //     direction: GradientDirection.Top
      //   })

      Row() {
        // 主要播放按钮（占据大部分空间）
        Row() {
          Image($r('app.media.ic_repeat'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_primary'))
          Text($r('app.string.play_all'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 8 })
        }
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .height(40)
        .width(120)
        // .layoutWeight(1)
        .borderRadius(8)
        .backgroundColor($r('app.color.setting_item_background'))
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.playlist?.songs && this.playlist.songs.length > 0) {
            // 寻找第一个可以播放的歌曲
            const song = this.playlist.songs.find(song => song.privilege.playable)
            this.handlePlaylistPlayAll(song || this.playlist.songs[0])
            PlaylistManager.switchPlayMode(PlayMode.LOOP)
          }
        })

        // 更多选项按钮（正方形）
        Row() {
          Image($r('app.media.ic_more'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_primary'))
        }
        .width(40)
        .height(40)
        .borderRadius(8)
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .backgroundColor($r('app.color.setting_item_background'))
        .justifyContent(FlexAlign.Center)
        .bindMenu([{
          value: $r('app.string.download_all_songs'),
          action: () => {
            if (this.playlist?.songs && this.playlist.songs.length > 0) {
              const songs = this.playlist.songs.filter(song => song.privilege.playable)
              SongDownloadManager.batchDownloadSongs(songs)
            }
          }
        }])
      }
      .backgroundColor('transparent')
      .justifyContent(FlexAlign.SpaceBetween)
      .width(StyleConstants.FULL_WIDTH)
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })

    }

  }

  // 歌曲列表逻辑
  @Builder
  SongListSection() {
    Column() {
      // Row() {
      //   Column() {
      //     Text('歌曲列表')
      //       .fontSize(18)
      //       .fontWeight(FontWeight.Bold)
      //       .fontColor($r('app.color.text_secondary'))
      //   }
      //
      //   // 显示缓存提醒
      //   if (this.cacheTime !== -1) {
      //     Column() {
      //       Row() {
      //         Text('缓存于')
      //           .fontSize(14)
      //           .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
      //           .fontColor($r('app.color.text_hint'))
      //         Text(`${formatRelativeTime(this.cacheTime)}`)
      //           .fontSize(14)
      //           .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
      //           .fontColor($r('app.color.text_secondary'))
      //       }
      //     }
      //   }
      // }
      // .justifyContent(FlexAlign.SpaceBetween)
      // .width(StyleConstants.FULL_WIDTH)
      // .padding({
      //   left: 24,
      //   right: 16,
      // })

      List({ scroller: this.scrollController }) {
        ListItem() {
          // 下拉提示动画
          HeaderAnimation({ scrollIndexHandler: this.scrollIndexHandler })
        }

        ListItem() {
          // 轮播图部分（如果符合条件）
          this.AlbumCoversSection()
        }

        ListItemGroup({ header: this.ListHeader() }) {
          if (this.isSearching) {
            ForEach(this.filteredSongs, (song: Song, index: number) => {
              ListItem() {
                SongInfo({
                  song: song,
                  index: index,
                  active: this.song?.id === song.id,
                  highlight: this.billingIndex === index,
                  onTap: (song: Song) => {
                    this.onSongTap(song, index);
                  }
                })
              }
              .key(`${song.id}-${index}`)
            })
          } else {
            LazyForEach(this.songDataSource, (song: Song, index: number) => {
              ListItem() {
                SongInfo({
                  song: song,
                  index: index,
                  active: this.song?.id === song.id,
                  highlight: this.billingIndex === index,
                  onTap: (song: Song) => {
                    this.onSongTap(song, index);
                  }
                })
              }
              .key(`${song.id}-${index}`)
            }, (song: Song, index: number) => `${song.id}-${index}`)
          }
        }
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.groupHeight = newValue.height as number
        })

        ListItem() {
          Row() {
            Blank().height(this.countSubVp())
          }
        }

        ListItem() {
          Row() {
            // 底部避让空间，高度为播控高度(64) + 播控底部padding高度(16)
            Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
          }
        }
      }
      .backToTop(true)
      .sticky(StickyStyle.Header | StickyStyle.Footer)
      .height(StyleConstants.FULL_HEIGHT)
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .expandSafeArea()
      .edgeEffect(EdgeEffect.Spring)
      .listDirection(Axis.Vertical)
      .divider({ strokeWidth: 0 })
      .cachedCount(5)
      .onScrollIndex((firstIndex: number, lastIndex: number) => {
        if (this.prefetcher) {
          this.prefetcher.visibleAreaChanged(firstIndex, lastIndex);
        }
      })
      .onWillScroll(this.scrollIndexHandler.scrollHandlers.onWillScroll)
      .onScrollStop(this.scrollIndexHandler.scrollHandlers.onScrollStop)
      .onReachEnd(async () => {
        if (this.isLoading || !this.sourceOk || this.isSearching) {
          return;
        }

        this.isLoading = true;
        try {
          const hasMoreData = await this.songDataSource.loadMoreData(10);
          if (!hasMoreData) {
            return
          }
        } finally {
          this.isLoading = false;
        }
      })

    }
    .expandSafeArea()
    .width(StyleConstants.FULL_WIDTH)
    .layoutWeight(1)
  }

  // 处理封面点击，确保在任何屏幕模式下都能正确滚动和高亮
  private handleCoverClick(_song: Song, index: number) {
    // 确保数据被预取
    this.songDataSource.prefetch(index);

    // 触发滚动到对应位置
    // this.scrollController.scrollToIndex(index, true);
    // 使用ListItemGroup之后会导致scrollToIndex方法失效，无法穿透滚动，使用scrollTo滚动指定距离
    // 滚动位置为每个歌曲卡片高度(68) + 上下padding距离(2*4)，并向上便宜3个卡片的距离，使后面的滚动可以屏幕居中
    this.scrollController.scrollTo({ xOffset: 0, yOffset: (68 + 8) * (index - 3), animation: true })
    // 设置高亮效果
    this.billingIndex = index;

    // 延迟重置闪烁索引
    setTimeout(() => {
      this.billingIndex = -1;
    }, 1000);
  }

  @Builder
  AlbumCoversSection() {
    if (this.playlist?.songs && this.playlist.songs.length >= 50) {
      Column() {
        AlbumCoversCarousel({
          coverSize: 56,
          scrollSpeed: 60,
          rows: 1,
          songs: this.playlist?.songs.slice(0, 99) || [],
          onCoverClick: (song: Song, index: number) => {
            this.handleCoverClick(song, index);
          }
        })
      }
      .backgroundColor($r('app.color.page_background'))
      .width(StyleConstants.FULL_WIDTH)
      .padding({ top: 12 })
    }
  }

  handlePlaylistPlayAll(song: Song) {
    PushPathHelper.loading("Playing", async () => {
      PlaylistManager.loadPlaylist(this.playlist?.songs?.filter(song => song.privilege.playable) || [], song);
    })
  }

  onSongTap(song: Song, _index: number) {
    this.handlePlaylistPlayAll(song);
  }

  // 小屏幕布局
  @Builder
  MobileLayout() {
    Column() {
      this.SongListSection()
    }
    .expandSafeArea()
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
  }

  // 左侧面板 - 宽屏模式（大卡片设计，歌曲数量在底部）
  @Builder
  LeftPanel() {
    Column() {
      if (this.playlist) {
        // 创建一个填满整个区域的大卡片
        Column() {
          // 歌单封面
          Column() {
            // 封面图
            Image(cover(this.playlist.cover || '', 300))
              .width(StyleConstants.FULL_WIDTH)
              .aspectRatio(1)// 保持正方形比例
              .borderRadius(16)
              .backgroundColor($r('app.color.setting_button_normal'))
          }
          .margin({ top: 20, bottom: 16 })
          .width('80%')

          // 歌单信息
          Column({ space: 12 }) {
            // 创作者信息（如果有）
            if (this.playlist.creator) {
              Row() {
                Text('创建者: ')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                Text(this.playlist.creator.name || '未知')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)
              }
              .justifyContent(FlexAlign.Center)
            }

            // 歌单描述（如果有）
            if (this.playlist.description) {
              Column({ space: 8 }) {
                Text('歌单简介')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .margin({ top: 8, bottom: 4 })

                Text(this.playlist.description.length > 50 ? `${this.playlist.description.slice(0, 50)}...` :
                this.playlist.description)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .width('90%')
                  .textAlign(TextAlign.Center)
              }
              .alignItems(HorizontalAlign.Center)
              .margin({ top: 8 })
              .width(StyleConstants.FULL_WIDTH)
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 16, right: 16 })
          .layoutWeight(1) // 使中间部分可以自适应伸缩

          // 歌曲数量 - 放在底部
          Row() {
            Text('共')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Text(`${this.playlist.songs?.length || 0}`)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Bold)
            Text('首歌曲')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .justifyContent(FlexAlign.Center)
          .padding({ bottom: 24, top: 12 })
          .width(StyleConstants.FULL_WIDTH)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(`calc(100% - ${StyleConstants.PLAYER_CONTROL_HEIGHT + px2vp(this.bottomRect)}px)`) // 避让播放控制器
        .backgroundColor($r('app.color.card_background'))
        .opacity(0.8)
        .borderRadius(24)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.SpaceBetween) // 使用SpaceBetween将歌曲数量推到底部
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .padding(16)
  }

  // 右侧面板 - 宽屏模式
  @Builder
  RightPanel() {
    Column() {
      // 歌曲列表组件
      this.SongListSection()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  // 宽屏布局
  @Builder
  WideScreenLayout() {
    Row() {
      // 左侧面板 (1份宽度)
      Column() {
        this.LeftPanel()
      }
      .width('33%') // 1/3 的宽度
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor($r('app.color.page_background'))

      // 右侧面板 (2份宽度)
      Column() {
        this.RightPanel()
      }
      .width('67%') // 2/3 的宽度
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor($r('app.color.page_background'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // 标题区域
          this.Title()

          Column() {
            if (this.playlist && this.playlist.songs && this.playlist.songs.length > 0) {
              // 根据屏幕宽度选择布局
              if (this.isWideScreen) {
                // 宽屏布局
                this.WideScreenLayout()
              } else {
                // 小屏幕布局
                this.SongListSection()
              }
            } else {
              // 显示空状态
              List({ scroller: this.scrollController }) {
                ListItem() {
                  // 下拉提示动画
                  HeaderAnimation({ scrollIndexHandler: this.scrollIndexHandler })
                }

                ListItem() {
                  Column() {
                    Text($r('app.string.no_songs_available'))
                      .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                      .fontColor($r('app.color.text_hint'))
                      .fontSize(16)
                  }
                  .width(StyleConstants.FULL_WIDTH)
                  .height(StyleConstants.FULL_HEIGHT)
                  .justifyContent(FlexAlign.Center)
                }

                ListItem() {
                  Column() {
                    // 底部避让空间，高度为播控高度(64) + 播控底部padding高度(16)
                    Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
                  }
                }
              }
              .onWillScroll(this.scrollIndexHandler.scrollHandlers.onWillScroll)
              .onScrollStop(this.scrollIndexHandler.scrollHandlers.onScrollStop)
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
            }
          }
          .layoutWeight(1)
          .width(StyleConstants.FULL_WIDTH)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        // 底部迷你播放控制器 - 直接放在Stack底部
        MiniPlaybackControl()
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .systemTransition(NavigationSystemTransitionType.EXPLODE)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .expandSafeArea()
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  @Builder
  ListHeader() {
    if (this.isWideScreen) {
      // 宽屏布局：一行显示所有元素
      Row() {
        // 搜索框
        Search({ value: this.searchKeywords, placeholder: $r('app.string.search_songs') })
          .searchButton(ResourceManager.getStringValueSync($r('app.string.search')))
          .onSubmit((value: string) => {
            this.searchKeywords = value
            this.filterSongs()
          })
          .onChange((value: string) => {
            this.searchKeywords = value
          })
          .margin(0)
          .backgroundBlurStyle(BlurStyle.Regular)
          .layoutWeight(1)
          .height(36)

        // 播放全部按钮
        Row() {
          Image($r('app.media.ic_repeat'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_primary'))
          Text($r('app.string.play_all'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 4 })
        }
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .height(36)
        .width(100)
        .borderRadius(8)
        .backgroundColor($r('app.color.setting_item_background'))
        .justifyContent(FlexAlign.Center)
        .margin({ left: 8 })
        .onClick(() => {
          if (this.playlist?.songs && this.playlist.songs.length > 0) {
            const song = this.playlist.songs.find(song => song.privilege.playable)
            this.handlePlaylistPlayAll(song || this.playlist.songs[0])
            PlaylistManager.switchPlayMode(PlayMode.LOOP)
          }
        })

        // 更多选项按钮
        Row() {
          Image($r('app.media.ic_more'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_primary'))
        }
        .width(36)
        .height(36)
        .borderRadius(8)
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .backgroundColor($r('app.color.setting_item_background'))
        .justifyContent(FlexAlign.Center)
        .margin({ left: 8 })
        .bindMenu([{
          value: $r('app.string.download_all_songs'),
          action: () => {
            if (this.playlist?.songs && this.playlist.songs.length > 0) {
              ToastUtil.showToast("开始下载全部歌曲")
              const songs = this.playlist.songs.filter(song => song.privilege.playable)
              SongDownloadManager.batchDownloadSongs(songs)
            }
          }
        }])
      }
      .padding({
        left: 8,
        right: 8,
        top: 4,
        bottom: 4
      })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(8)
    } else {
      // 小屏幕布局：搜索框和按钮一行显示
      Row() {
        // 搜索框
        Search({ value: this.searchKeywords, placeholder: $r('app.string.search_songs') })
          .searchButton(ResourceManager.getStringValueSync($r('app.string.search')))
          .onSubmit((value: string) => {
            this.searchKeywords = value
            this.filterSongs()
          })
          .onChange((value: string) => {
            this.searchKeywords = value
            if (value.trim() === '' || !value) {
              this.filterSongs()
            }
          })
          .backgroundBlurStyle(BlurStyle.Regular)
          .layoutWeight(1)
          .height(36)

        // 播放全部按钮
        Row() {
          Image($r('app.media.ic_repeat'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_primary'))
          Text($r('app.string.play_all'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 4 })
        }
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .height(36)
        .width(100)
        .borderRadius(8)
        .backgroundColor($r('app.color.setting_item_background'))
        .justifyContent(FlexAlign.Center)
        .margin({ left: 8 })
        .onClick(() => {
          if (this.playlist?.songs && this.playlist.songs.length > 0) {
            const song = this.playlist.songs.find(song => song.privilege.playable)
            this.handlePlaylistPlayAll(song || this.playlist.songs[0])
            PlaylistManager.switchPlayMode(PlayMode.LOOP)
          }
        })

        // 更多选项按钮
        Row() {
          Image($r('app.media.ic_more'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_primary'))
        }
        .width(36)
        .height(36)
        .borderRadius(8)
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .backgroundColor($r('app.color.setting_item_background'))
        .justifyContent(FlexAlign.Center)
        .margin({ left: 8 })
        .bindMenu([{
          value: $r('app.string.download_all_songs'),
          action: () => {
            if (this.playlist?.songs && this.playlist.songs.length > 0) {
              ToastUtil.showToast("开始下载全部歌曲")
              const songs = this.playlist.songs.filter(song => song.privilege.playable)
              SongDownloadManager.batchDownloadSongs(songs)
            }
          }
        }])
      }
      .padding({
        left: 8,
        right: 8,
        top: 4,
        bottom: 4
      })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(8)
    }
  }

  countSubVp(): number {
    let sub: number = px2vp(this.winHeight) - 50 - this.groupHeight - (this.bottomRect + this.topRect)
    // if(this.songDataSource.totalCount() <= 15){
    //   // 填补高度=屏幕高度 - title高度50 - (播放组件高度40+上下padding高度2*4) - 状态栏高度 - 导航栏高度
    //   sub = px2vp(this.winHeight) - (50+40+12*2+(68+2*4)*this.songDataSource.totalCount()) - px2vp(this.topRect) - px2vp(this.bottomRect)
    // }
    return sub > 0 ? sub : 0
  }

  private filterSongs() {
    if (!this.playlist?.songs) {
      return
    }

    if (!this.searchKeywords.trim()) {
      this.filteredSongs = this.playlist.songs
      this.isSearching = false
      return
    }

    const keywords = this.searchKeywords.toLowerCase().trim()
    this.filteredSongs = this.playlist.songs.filter(song =>
    song.name.toLowerCase().includes(keywords) ||
    song.artists.some(artist => artist.name.toLowerCase().includes(keywords)) ||
    song.album.name.toLowerCase().includes(keywords)
    )
    this.isSearching = true
  }
}