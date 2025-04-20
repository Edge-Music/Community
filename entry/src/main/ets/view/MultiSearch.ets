import { ToastUtil } from "@pura/harmony-utils";
import { SourceAdapter } from "../adapter";
import { Cover } from "../component/Cover";
import { HeaderAnimation } from "../component/HeaderAnimation";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import { Segment } from "../component/Segment";
import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { Album, Artist, Playlist, SearchResult, Song } from "../type/Adapter";
import { cover } from "../util/AdapterHelper";
import { PlaylistManager } from "../util/PlaylistManager";
import { PushPathHelper } from "../util/PushPathHelper";
import { ResourceManager } from "../util/ResourceManager";
import { ScrollIndexHandler } from "../util/ScrollIndexHandler";

const TAG = 'MultiSearch'

@Component
export struct MultiSearch {
  @State groupHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State keywords: string = '';
  @State result: SearchResult | null = null;
  @State loading: boolean = false;
  @State nullResultFlag: boolean = true
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  private scrollController: Scroller = new Scroller();
  @State scrollIndexHandler: ScrollIndexHandler = new ScrollIndexHandler({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scrollController)

  private generatePlaylistMenu(playlist: Playlist) {
    return [
      {
        value: $r('app.string.play_this_playlist'),
        action: () => {
          PushPathHelper.loading("Playing", async () => {
            const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
            const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
            if (!songs || songs.length === 0) {
              ToastUtil.showShort("此歌单无可播放歌曲")
              return
            }
            PlaylistManager.loadPlaylist(songs, songs[0])
          })
        }
      },
    // {
    //   value: '收藏此歌单',
    //   action: () => {
    //   }
    // }
    ] as MenuElement[]
  }

  private generateSongMenu(song: Song) {
    return [
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PlaylistManager.insertSongs([song])
        }
      },
    // {
    //   value: '收藏到歌单',
    //   action: () => {
    //   }
    // }
    ] as MenuElement[]
  }

  async search() {
    this.loading = true
    this.nullResultFlag = true
    this.result = await SourceAdapter.search(this.keywords)
    this.loading = false
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }){
        Column(){
          this.Title()

          List({ scroller: this.scrollController}){

            ListItem(){
              HeaderAnimation({ scrollIndexHandler: this.scrollIndexHandler })
            }

            ListItemGroup({ header: this.SearchComponent() }){
              if(this.result){
                // 歌曲
                if(this.isNullResult(this.result.songs)){
                  ListItem(){
                    Segment({
                      title: "歌曲",
                      loading: this.loading,
                    }) {
                      ForEach(this.result.songs, (item: Song) => {
                        Cover({
                          src: cover(item.album.cover, 256),
                          title: item.name,
                          subtitle: item.artists.map(artist => artist.name).join(' / '),
                          menuItems: this.generateSongMenu(item)
                        })
                          .width(120)
                          .padding(4)
                          .onClick(() => {
                            PushPathHelper.loading("Playing", async () => {
                              PlaylistManager.insertSongs([item], -1, item)
                            })
                          })
                      })
                    }
                  }
                }
                // 歌单
                if(this.isNullResult(this.result.playlists)){
                  ListItem(){
                    Segment({
                      title: "歌单",
                      loading: this.loading,
                    }) {
                      ForEach(this.result.playlists, (item: Playlist) => {
                        Cover({
                          src: cover(item.cover, 256),
                          title: item.name,
                          menuItems: this.generatePlaylistMenu(item)
                        })
                          .width(120)
                          .padding(4)
                          .onClick(() => {
                            PushPathHelper.pushPathImmediately(this.pageStack, "Playlist", async () => {
                              const playlist = await SourceAdapter.getPlaylistDetail(item)
                              AppStorage.setOrCreate('current_playlist_data', playlist)
                            })
                          })
                      })
                    }
                  }
                }
                // 艺人
                if(this.isNullResult(this.result.artists)){
                  ListItem(){
                    Segment({
                      title: "歌手",
                      loading: this.loading,
                      radius: "100%",
                    }) {
                      ForEach(this.result.artists, (item: Artist) => {
                        Cover({
                          src: cover(item.avatar, 256),
                          title: item.name,
                          radius: "100%",
                        })
                          .width(120)
                          .padding(4)
                          .onClick(() => {
                            PushPathHelper.pushPathImmediately(this.pageStack, "Playlist", async () => {
                              const artist = await SourceAdapter.getArtistDetail(item)
                              AppStorage.setOrCreate('current_playlist_data', artist)
                            })
                          })
                      })
                    }
                  }
                }
                // 专辑
                if(this.isNullResult(this.result.albums)){
                  ListItem(){
                    Segment({
                      title: "专辑",
                      loading: this.loading,
                    }) {
                      ForEach(this.result.albums, (item: Album) => {
                        Cover({
                          src: cover(item.cover, 256),
                          title: item.name,
                          subtitle: item.artists?.map(artist => artist.name).join(' / '),
                        })
                          .width(120)
                          .padding(4)
                          .onClick(() => {
                            PushPathHelper.pushPathImmediately(this.pageStack, "Playlist", async () => {
                              const album = await SourceAdapter.getAlbumDetail(item)
                              AppStorage.setOrCreate('current_playlist_data', album)
                            })
                          })
                      })
                    }
                  }
                }
                // 如果结果为空
                if(this.nullResultFlag){
                  ListItem(){
                    this.EmptySearchResult(ResourceManager.getStringValueSync($r('app.string.search_no_result')))
                  }
                }
              } else {
                ListItem(){
                  this.EmptySearchResult(ResourceManager.getStringValueSync($r('app.string.start_search')))
                }
              }

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

            ListItem(){
              Row(){
                // 搜索页底部避让高度：播控组件高度(64) + 导航栏避让高度 + 播控组件下方margin值(16)
                Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16).layoutWeight(1)
              }
            }
          }
          .expandSafeArea()
          .backToTop(true)
          .layoutWeight(1)
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
          .sticky(StickyStyle.Header | StickyStyle.Footer)
          .onWillScroll(this.scrollIndexHandler.scrollHandlers.onWillScroll)
          .onScrollStop(this.scrollIndexHandler.scrollHandlers.onScrollStop)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .expandSafeArea()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        MiniPlaybackControl()
      }
      .expandSafeArea()
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .expandSafeArea()
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .gesture(
      SwipeGesture({
        direction: SwipeDirection.Vertical,
      }).onAction((event) => {
        if (event.angle >= 0) {
          this.pageStack.pop()
        }
      })
    )
  }

  /**
   * 判断结果非空公共方法
   * @param list
   * @returns
   */
  isNullResult(list: Song[] | Playlist[] | Artist[] | Album[] | undefined) {
    if(list && list.length > 0){
      this.nullResultFlag = false
      return true
    }
    return false
  }

  getBlankHeight(): Length {
    let sub = px2vp(this.winHeight) - this.groupHeight - 50 - px2vp(this.bottomRect+this.topRect)
    return sub > 0 ? sub : 0
  }

  @Builder
  SearchComponent() {
    Column(){
      Search({ value: this.keywords, placeholder: $r('app.string.search_what_you_want') })
        .searchButton(ResourceManager.getStringValueSync($r('app.string.search')))
        .onSubmit(async (value: string) => {
          this.keywords = value
          await this.search()
        })
        .margin(0)
        .backgroundBlurStyle(BlurStyle.Regular)
    }
    .padding(12)

  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.search'),
      backActive: this.scrollIndexHandler.currentIndex === 0
    })
  }

  @Builder
  EmptySearchResult(reason: string) {
    Column() {
      Row() {
        Text(reason)
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontColor($r('app.color.text_hint'))
          .fontSize(16)
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

  onMenuIconClick(index: number) {
    if (index === 0) {
      this.pageStack.pop();
    } else if (index === 1) {
      // 触发other
    }
  }
}