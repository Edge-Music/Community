import { SongInfo } from '../component/SongInfo';
import { StyleConstants } from '../constants/StyleConstants';
import { Playlist, Song } from '../type/Adapter';
import { PlaylistManager } from '../util/PlaylistManager';
import { SongDataSourcePrefetching } from '../util/SongDataSourcePrefetching';
import { BasicPrefetcher } from '@kit.ArkUI';
import { ToastUtil } from '@pura/harmony-utils';
import { LogUtil } from '@pura/harmony-utils';

@Component
export struct PlaylistView {
  @StorageLink('current_playing_song') currentSong: Song | null = null;
  @StorageLink('current_playing_playlist') @Watch('onPlaylistChanged') playlist: Array<Song> = [];
  @State isLoading: boolean = false;
  @State highlightIndex: number = -1;

  // 数据源和预取器
  private songDataSource: SongDataSourcePrefetching = new SongDataSourcePrefetching(null);
  private prefetcher: BasicPrefetcher | null = null;
  private scrollController: Scroller = new Scroller();
  private sourceReady: boolean = false;

  // 可选的事件回调
  onSongSelected?: (song: Song) => void;
  onPlaylistEmpty?: () => void;

  aboutToAppear(): void {
    this.initDataSource();
  }

  // 监听播放列表变化
  onPlaylistChanged(): void {

    // 如果数据源已初始化，同步数据
    if (this.sourceReady && this.songDataSource) {
      this.songDataSource.syncWithPlaylist(this.playlist || []);
    } else {
      // 否则重新初始化数据源
      this.initDataSource();
    }

    // 检查歌单是否为空
    if (!this.playlist || this.playlist.length === 0) {
      if (this.onPlaylistEmpty) {
        this.onPlaylistEmpty();
      }
    }
  }

  // 初始化数据源
  private initDataSource(): void {
    LogUtil.info('PlaylistView', 'Initializing data source');

    // 清理旧的预取器
    this.prefetcher = null;
    this.sourceReady = false;

    // 创建临时Playlist对象
    const tempPlaylist: Playlist = {
      id: 'current_playing',
      songs: this.playlist || []
    };

    // 初始化新的数据源
    this.songDataSource = new SongDataSourcePrefetching(tempPlaylist);

    // 创建预取器
    this.prefetcher = new BasicPrefetcher(this.songDataSource);
    this.sourceReady = true;

    // 检查歌单是否为空
    if (!this.playlist || this.playlist.length === 0) {
      if (this.onPlaylistEmpty) {
        this.onPlaylistEmpty();
      }
    }

    // 滚动到当前播放的歌曲
    this.scrollToCurrentSong();
  }

  // 处理歌曲点击
  private handleSongTap(song: Song): void {
    LogUtil.info('PlaylistView', 'Song tapped:', song.name || 'unknown');

    // 播放选中的歌曲
    if (this.playlist && this.playlist.length > 0) {
      PlaylistManager.playSong(song);
    }

    // 触发选中事件
    if (this.onSongSelected) {
      this.onSongSelected(song);
    }
  }

  // 处理歌曲删除
  private handleSongDelete(song: Song): void {

    // 从播放列表中移除歌曲
    PlaylistManager.removeSong(song);

    // 直接从数据源删除
    this.songDataSource.removeData(song);

    // 显示删除成功提示
    ToastUtil.showShort($r('app.string.removed_from_the_playlist'));
  }

  // 滚动到当前播放的歌曲
  scrollToCurrentSong(): void {
    if (!this.currentSong || !this.playlist || this.playlist.length === 0) {
      return;
    }

    // 查找当前歌曲的索引
    const currentIndex = this.playlist.findIndex(song =>
    song.id === this.currentSong?.id
    );


    if (currentIndex !== -1) {
      // 确保数据被预取
      if (this.prefetcher) {
        this.songDataSource.prefetch(currentIndex);
      }

      // 设置高亮效果
      this.highlightIndex = currentIndex;
      setTimeout(() => {
        this.highlightIndex = -1;
      }, 1500);

      // 滚动到指定位置
      setTimeout(() => {
        this.scrollController.scrollToIndex(Math.max(0, currentIndex), true);
      }, 100);
    }
  }

  // 删除按钮构建器
  @Builder
  DeleteButton(song: Song) {
    Button({ type: ButtonType.Circle }) {
      Image($r('app.media.ic_close'))
        .width(20)
        .height(20)
        .fillColor($r('app.color.text_secondary'))
    }
    .width(36)
    .height(36)
    .backgroundColor('rgba(200, 200, 200, 0.1)')
    .margin({ left: 8 })
    .onClick(() => {
      this.handleSongDelete(song);
    })
  }

  // 空状态构建器
  @Builder
  EmptyState() {
    Column() {
      Text($r('app.string.no_songs_available'))
        .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
        .fontColor($r('app.color.text_hint'))
        .fontSize(16)
        .margin({ bottom: 8 })

      Text('点击添加按钮添加歌曲')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(300)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (!this.playlist || this.playlist.length === 0) {
        this.EmptyState()
      } else {
        List({ scroller: this.scrollController }) {
          // 使用LazyForEach实现懒加载歌曲列表
          LazyForEach(this.songDataSource, (song: Song, index: number) => {
            ListItem() {
              SongInfo({
                song: song,
                showIndex: false,
                active: this.currentSong?.id === song.id,
                highlight: this.highlightIndex === index,
                disabled: song.privilege && !song.privilege.playable,
                onTap: (song: Song) => this.handleSongTap(song)
              }) {
                // 使用rightSlot插槽添加删除按钮
                this.DeleteButton(song)
              }
            }
            .key(`song-${song.id}`) // 使用唯一歌曲ID作为key，不再使用index
            .margin({ bottom: 4 })
          }, (song: Song) => `song-${song.id}`) // 使用歌曲ID作为唯一标识符

          // 加载中状态显示
          if (this.isLoading) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(24)
                  .height(24)
                  .color($r('app.color.text_secondary'))

                Text('加载中...')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
              }
              .width(StyleConstants.FULL_WIDTH)
              .justifyContent(FlexAlign.Center)
              .padding({ top: 16, bottom: 16 })
            }
          }

          ListItem(){
            Column(){
              Blank().height(64)
            }
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .layoutWeight(1)
        .listDirection(Axis.Vertical)
        .divider({ strokeWidth: 0 })
        .scrollBar(BarState.Off)
        .cachedCount(8)
        .onScrollIndex((firstIndex: number, lastIndex: number) => {
          // 通知预取器可见区域变化
          if (this.prefetcher && this.sourceReady) {
            this.prefetcher.visibleAreaChanged(firstIndex, lastIndex);
          }
        })
        .onReachEnd(async () => {
          // 到达底部时加载更多数据
          if (this.isLoading || !this.sourceReady) {
            return;
          }

          this.isLoading = true;
          try {
            const hasMoreData = await this.songDataSource.loadMoreData(10);
            if (!hasMoreData) {
              LogUtil.info('PlaylistView', 'No more data to load');
            }
          } finally {
            this.isLoading = false;
          }
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }
}