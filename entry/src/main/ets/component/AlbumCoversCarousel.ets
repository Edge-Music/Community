import { Song } from '../type/Adapter';
import { cover } from '../util/AdapterHelper';
import { Cover } from './Cover';

/**
 * 专辑封面流动展示组件
 * 将所有歌曲按指定顺序排列，并实现平滑滚动
 */
@Component
export struct AlbumCoversCarousel {
  // 歌曲列表
  @Prop songs: Song[] = [];
  // 封面尺寸
  @Prop coverSize: number = 80;
  // 间距
  @Prop spacing: number = 12;
  // 显示的行数
  @Prop rows: number = 3;
  // 滚动速度(像素/秒)
  @Prop scrollSpeed: number = 40;
  // 点击封面回调
  onCoverClick?: (song: Song, index: number) => void;

  // 滚动位置
  @State scrollPosition: number = 0;
  // 所有排列好的歌曲
  private allSongs: Song[][] = [];

  // 定时器ID
  private timer: number = 0;
  // 容器宽度
  private containerWidth: number = 0;

  aboutToAppear() {
    // 预先排列所有歌曲
    this.arrangeAllSongs();
  }

  aboutToDisappear() {
    // 清除定时器
    this.clearTimer();
  }

  // 清除定时器
  private clearTimer() {
    if (this.timer !== 0) {
      clearInterval(this.timer);
      this.timer = 0;
    }
  }

  // 按照指定的顺序排列所有歌曲
  // 排列方式：1,4,7,10... / 2,5,8,11... / 3,6,9,12...
  private arrangeAllSongs() {
    if (this.songs.length === 0) return;

    // 初始化歌曲行数组
    this.allSongs = Array(this.rows).fill(0).map(() => []);

    // 限制最多使用99首歌曲
    const songCount = Math.min(this.songs.length, 99);

    // 按照指定顺序排列歌曲
    for (let i = 0; i < songCount; i++) {
      const rowIndex = i % this.rows;
      this.allSongs[rowIndex].push(this.songs[i]);
    }
  }

  // 启动滚动动画
  private startScrolling(width: number) {
    this.containerWidth = width;
    this.clearTimer();

    // 设置计时器
    this.timer = setInterval(() => {
      // 计算移动距离
      const moveDistance = this.scrollSpeed / 60;

      // 更新滚动位置
      this.scrollPosition -= moveDistance;

      // 当滚动到的位置超过所有歌曲的总宽度时，重置回开始位置
      // 获取每行歌曲数量中的最大值
      const maxSongsInRow = Math.max(...this.allSongs.map(row => row.length));

      // 计算所有歌曲的总宽度
      const totalWidth = (this.coverSize + this.spacing) * maxSongsInRow;

      // 当滚动位置超过总宽度时重置
      if (Math.abs(this.scrollPosition) >= totalWidth) {
        animateTo({
          duration: 500,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.scrollPosition = 0
        });
      }
    }, 16) as number;
  }

  build() {
    Column({ space: this.spacing }) {
      if (this.songs.length === 0) {
        // 显示空状态
        Text($r('app.string.no_songs_available'))
          .fontSize(16)
          .fontColor("#999999")
          .margin(20)
      } else {
        // 创建多行
        ForEach(this.allSongs, (rowSongs: Song[], _rowIndex: number) => {
          Row() {
            // 显示本行所有歌曲
            ForEach(rowSongs, (song: Song) => {
              Column() {
                Cover({
                  src: cover(song.album?.cover, this.coverSize * 2),
                  radius: 8,
                })
                  .width(this.coverSize)
                  .height(this.coverSize)
              }
              .margin({ right: this.spacing })
              .onClick(() => {
                if (this.onCoverClick) {
                  const originalIndex = this.songs.findIndex(s => s.id === song.id);
                  this.onCoverClick(song, originalIndex >= 0 ? originalIndex : 0);
                }
              })
            })

          }
          .margin({ left: this.scrollPosition })
          .width('100%')
          .height(this.coverSize)
        })
      }
    }
    .width('100%')
    .height((this.coverSize + this.spacing) * this.rows - this.spacing)
    .padding({ left: 16, right: 16 })
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      // 只在宽度变化时启动滚动
      if (newArea.width !== this.containerWidth) {
        this.startScrolling(newArea.width as number);
      }
    })
  }
}