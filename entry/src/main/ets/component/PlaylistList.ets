import { LazyData } from "@pie/lazy-data";
import { ID, Playlist, SourceConfig } from "../type/Adapter";
import { ToastUtil } from '@pura/harmony-utils';
import { SourceAdapter } from '../adapter';
import { StyleConstants } from '../constants/StyleConstants';
import { cover } from '../util/AdapterHelper';
import { PlaylistManager } from '../util/PlaylistManager';
import { PushPathHelper } from '../util/PushPathHelper';
import { PreferencesCache } from "../util/PreferenceCache";

@Component
export struct PlaylistList {
  @StorageProp('bottomRect') bottomRect: number = 0
  @Prop playlists: Playlist[] = [];
  onPlaylistSelected?: (playlist: Playlist) => void;
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';
  @StorageLink("show_user_data_source") showAdapters: SourceConfig[] = PreferencesCache.getShowUserDataSource()
  @State dataSource: LazyData<Playlist> = new LazyData<Playlist>(this.playlists);
  @Prop adapters: SourceConfig[] = []
  @Link sIndex: number
  @Link subTitleIndex: number

  build() {
    Column() {
      if (this.playlists.length === 0) {
        // 空状态展示
        Column() {
          Text('暂无歌单')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .justifyContent(FlexAlign.Center)
      } else {
        // 版本三：歌单分类项
        Tabs({ index: this.subTitleIndex }) {
          TabContent(){
            this.TabContentList(0)
          }
          TabContent(){
            this.TabContentList(1)
          }
          TabContent(){
            this.TabContentList(2)
          }
        }
        .scrollable(false)
        .edgeEffect(EdgeEffect.Spring)
        .barHeight(0)

        // 版本二：不包含歌单分类项（暂不删除，万一以后用的上）
        // LazyForEach(this.dataSource, (playlist: Playlist, pIndex) => {
        //   if(this.judgeSourceByDataSourceId(playlist)){
        //     ListItem(){
        //       this.PlaylistItem(playlist)
        //     }
        //   }
        // })

        // 版本一：歌单列表展示（暂不删除，万一以后用的上）
        // Tabs({ index: this.sIndex }){
        //   ForEach(this.adapters, (adapter: SourceConfig, SIndex) => {
        //     TabContent(){
        //       List() {
        //         ListItem(){
        //           Row().height(12)
        //         }
        //         ForEach(this.playlists, (playlist: Playlist, pIndex) => {
        //           if(this.judgeSource(playlist, adapter)){
        //             ListItem(){
        //               this.PlaylistItem(playlist)
        //             }
        //           }
        //         })
        //         ListItem(){
        //           Column()
        //             .height(StyleConstants.PLAYER_CONTROL_HEIGHT + 32 + px2vp(this.bottomRect))
        //         }
        //       }
        //       .nestedScroll({ scrollForward: NestedScrollMode.SELF_ONLY, scrollBackward: NestedScrollMode.SELF_FIRST})
        //       .width('100%')
        //       .height('100%')
        //       .listDirection(Axis.Vertical)
        //       .edgeEffect(EdgeEffect.Spring)
        //       .scrollBar(BarState.Off)
        //       // .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 16, endMargin: 16 })
        //       .backgroundColor($r('app.color.page_background'))
        //     }
        //     .tabBar(adapter.name+" "+adapter.auth?.user?.name)
        //   })
        // }
        // .scrollable(false)
        // .edgeEffect(EdgeEffect.Spring)
        // .barHeight(0)
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
    .expandSafeArea()
  }

  judgeSourceByDataSourceId(playlist: Playlist, index: number): boolean {
    let exists: boolean = false
    const showAdapterIDs: ID[] = this.showAdapters.map(adapter => adapter.id)
    if(showAdapterIDs.includes(playlist.source?.id as ID)){
      switch(index){
        case 0:
          exists = true
          break
        case 1:
          exists = playlist.creator?.id == playlist.source?.auth?.user?.id
          break
        case 2:
          exists = playlist.creator?.id != playlist.source?.auth?.user?.id
          break
      }
    }
    return exists
  }

  judgeSource(playlist: Playlist, sourceConfig: SourceConfig): boolean {
    if(playlist.source?.auth?.user && sourceConfig.auth?.user){
      if(playlist.source.auth?.user?.id === sourceConfig.auth?.user?.id){
        return true
      }
    }
    return false
  }

  @Builder
  TabContentList(index: number){
    List(){
      ListItem(){
        Row().height(12)
      }
      ForEach(this.playlists, (playlist: Playlist) => {
        if(this.judgeSourceByDataSourceId(playlist, index)){
          ListItem(){
            this.PlaylistItem(playlist)
          }
        }
      })
      ListItem(){
        Column()
          .height(StyleConstants.PLAYER_CONTROL_HEIGHT + 32 + px2vp(this.bottomRect))
      }
    }
    .nestedScroll({ scrollForward: NestedScrollMode.SELF_ONLY, scrollBackward: NestedScrollMode.SELF_FIRST})
    .width('100%')
    .height('100%')
    .listDirection(Axis.Vertical)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  PlaylistItem(playlist: Playlist) {
    Row() {
      // 封面图 - 现代直角设计
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(cover(playlist?.cover || '', 120))
          .width(58)
          .height(58)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
      }
      .margin({ right: 12 })

      // 歌单信息 - 层次分明的布局
      Column({ space: 12 }) {
        Text(playlist?.name || '未知歌单')
          .fontSize(15)
          .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 歌曲信息
        if (playlist?.size) {
          Text(`${playlist.size}首`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 更多操作按钮
      Image($r('app.media.ic_more'))
        .width(20)
        .height(20)
        .fillColor($r('app.color.icon_normal'))
        .opacity(0.9)
        .bindMenu(this.generatePlaylistMenu(playlist))
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 16, right: 16, top: 0, bottom: 0 })
    .height(74)
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      if (this.onPlaylistSelected) {
        this.onPlaylistSelected(playlist);
      }
    })
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
              ToastUtil.showShort("此歌单无可播放歌曲")
              return
            }
            PlaylistManager.loadPlaylist(songs, songs[0])
          })
        }
      },
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PushPathHelper.loading("Playing", async () => {
            const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
            const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
            if (!songs || songs.length === 0) {
              ToastUtil.showShort("此歌单无可播放歌曲")
              return
            }
            PlaylistManager.insertSongs(songs)
          })
        }
      }
    ]
  }

}