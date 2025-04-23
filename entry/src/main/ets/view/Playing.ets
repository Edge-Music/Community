import { Song } from '../type/Adapter'
import { StyleConstants } from "../constants/StyleConstants"
import { BreakpointConstants } from '../constants/BreakpointConstants'
import { cover } from '../util/AdapterHelper'
import { BreakPointType } from '../component/BreakpointSystem'
import { PlaylistManager } from '../util/PlaylistManager'
import { EventHelper } from '../util/EventHelper'
import { avPlayerManager } from '../util/AVPlayerManager'
import { ClickUtil, ToastUtil } from '@pura/harmony-utils'
import { LyricsView } from '../component/LyricsView'
import { PlaylistView } from '../component/PlaylistView'
import { PreferencesCache } from '../util/PreferenceCache'
import { SourceAdapter } from '../adapter'
import { TimerSelector } from '../component/TimerSelector'
import { isHorizontalMode } from '../util/HorizontalCheck'
import { screen_on } from '../util/On_screen_control'
import { SongDownloadManager } from '../util/SongDownloadManager'
import { hilog } from '@kit.PerformanceAnalysisKit';
import { resourceManager } from '@kit.LocalizationKit';
import { http } from '@kit.NetworkKit';
import ImageUtils from '../util/ImageUtils';
@Builder
export function PlayingBuilder() {
  Playing()
}


@Component
struct Playing {
  @Consume('NavPathStack') pageStack: NavPathStack;
  @Watch('onBreakpointChange') @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
  @State currentTime: number = 0
  @State isProgressBarExpanded: boolean = false
  @State selectedTabIndex: number = 0
  @State isPlaying: boolean = true
  @State isFavorite: boolean = false
  @State playMode: number = PlaylistManager.getPlayMode()
  @State showPlaylist: boolean = false
  @Watch('onplaying_change')@StorageLink("current_playing_song") song: Song | null = null
  @State isWideScreen: boolean = false // 是否为宽屏
  @State imageColorHex:string='1a2a3a'
  @State currentIndex: number = -1
  // 独立的按钮动画状态
  @State swipeOffset: number = 0; // 滑动偏移量
  @State isSwipingActive: boolean = false; // 是否正在滑动中
  @State swipeDirection: string = ''; // 滑动方向
  private readonly SWIPE_THRESHOLD: number = 80; // 触发切换的阈值
  @State img_playing_ctrl:string=  PreferencesCache.getUserPreference('img_playing_ctrl','0')
  @State isPrevButtonPressed: boolean = false
  @State isPlayButtonPressed: boolean = false
  @State isNextButtonPressed: boolean = false
  @State isShuffleButtonPressed: boolean = false
  @State isListButtonPressed: boolean = false
  @State isHeartButtonPressed: boolean = false
  @State isMoreButtonPressed: boolean = false
  @State isBackButtonPressed: boolean = false
  @State Playing_Next: boolean = true
  @State Fold_judge: boolean = true
  @State is_backblur: boolean = true
  private updateTimer: number = -1
  //TAB,swiper控制
  private controller: TabsController = new TabsController()
  private swiperController: SwiperController = new SwiperController()
  // 歌曲封面-歌词翻转
  @State flipCoverLyric: boolean = PreferencesCache.flipCoverLyric()
  @State  Pura_X:string =  PreferencesCache.getUserPreference('is_Pura_X', '0')//pura_x尝试适配
  // 监听屏幕断点变化
  onBreakpointChange() {
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
    this.Playing_Next = isHorizontalMode()
    console.info('Succeeded in obtaining fold status.judge: ' + this.Playing_Next);
  }

  async onplaying_change(){
    try {
      const context = getContext(this);
      let netFile = this.song?.album?.cover + "?param=64y64" ?? "";
      let httpRequest = http.createHttp()
      let data = await httpRequest.request(netFile);
      const resourceMgr: resourceManager.ResourceManager = context.resourceManager;
      let imageDealData = await ImageUtils.getImageDealDataByArr(data.result as ArrayBuffer);//imageDealData.imageColorHex.length
      this.imageColorHex=imageDealData.imageColorHex
    } catch (e) {
      hilog.error(0x0000, 'TestTag', 'Failed error.code is %{public}d,error.message is %{public}s', e.code,
        e.message);
    }
  }
  @State sheetType: "playlist" | "timer" = "playlist" // 用于控制底部弹出表单的类型，默认为播放列表

  @Builder
  PlayListBuilder() {
    Column() {
      // 播放列表内容
      Text($r('app.string.playing_list'))
        .fontSize(18)
        .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
        .fontColor($r('app.color.text_title'))
        .margin({ left: 36, top: 16, bottom: 16 })
        .width(StyleConstants.FULL_WIDTH)
        .textAlign(TextAlign.Start)
      PlaylistView()
    }
    .height(StyleConstants.FULL_HEIGHT)
    .layoutWeight(1)
    .transition({ type: TransitionType.Insert, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
    .transition({ type: TransitionType.Delete, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
  }

  @Builder
  Timer() {
    Column() {
      Text($r('app.string.scheduled_shutdown'))
        .fontSize(18)
        .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
        .fontColor($r('app.color.text_title'))
        .margin({ left: 36, top: 16, bottom: 16 })
        .width(StyleConstants.FULL_WIDTH)
        .textAlign(TextAlign.Start)
      TimerSelector()
    }
    .height(StyleConstants.FULL_HEIGHT)
    .layoutWeight(1)
    .transition({ type: TransitionType.Insert, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
    .transition({ type: TransitionType.Delete, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
  }
  handleSongChange(direction: 'next' | 'prev') {
    animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      delay: 0,
      onFinish: () => {
        this.swipeOffset = 0;
        this.isSwipingActive = false;
        this.swipeDirection = '';
      }
    }, () => {
      if (direction === 'next') {
        const nextSong = PlaylistManager.playNext();
        if (nextSong) {
          PlaylistManager.playSong(nextSong);
        }
      } else {
        const prevSong = PlaylistManager.playPrevious();
        if (prevSong) {
          PlaylistManager.playSong(prevSong);
        }
      }
    });
  }
  @Builder
  //————————————————————————
  // 函数名：Playing_HorizontalMode()
  // 参数：null
  // 功能：手机横屏播放器
  //——————————————————————————
  Playing_HorizontalMode() {
    Swiper(this.swiperController){
      Row() {
        //封面图
        Stack(){
          Column() {
            Stack(){
              Image(cover(this.song?.album?.cover ?? "", 512))
                .geometryTransition("picture", { follow: false })
                .transition(TransitionEffect.OPACITY)
                .width('100%')
                .aspectRatio(1)
                .clip(true)
                .onClick(()=>{this.swiperController.showNext()})
                .shadow({
                  radius: 0,
                  color: 'rgba(0, 0, 0, 0.15)',
                  offsetX: 0,
                  offsetY: 2
                })
                .onAppear(async ()=>{
                  try {
                    const context = getContext(this);
                    const resourceMgr: resourceManager.ResourceManager = context.resourceManager;
                    let netFile = this.song?.album?.cover + "?param=64y64" ?? "";
                    let httpRequest = http.createHttp()
                    let data = await httpRequest.request(netFile);
                    let imageDealData = await ImageUtils.getImageDealDataByArr(data.result as ArrayBuffer);//imageDealData.imageColorHex.length
                    this.imageColorHex=imageDealData.imageColorHex
                  } catch (e) {
                    hilog.error(0x0000, 'TestTag', 'Failed error.code is %{public}d,error.message is %{public}s', e.code,
                      e.message);
                  }
                })
                .borderRadius(this.img_playing_ctrl==='1'?0:24)
                .gesture(
                  PanGesture({ direction: PanDirection.Horizontal })
                    .onActionStart(() => {
                      this.isSwipingActive = true;
                    })
                    .onActionUpdate((event) => {
                      // 更新滑动偏移量
                      this.swipeOffset = event.offsetX;

                      // 确定滑动方向
                      if (event.offsetX > 10 &&this.img_playing_ctrl==='1') {
                        this.swipeDirection = 'right'; // 向右滑动，上一首
                      } else if (event.offsetX < -10) {
                        this.swipeDirection = 'left'; // 向左滑动，下一首
                      } else {
                        this.swipeDirection = '';
                      }
                    })
                    .onActionEnd(() => {
                      // 根据最终偏移量决定是切换歌曲还是回弹
                      if (this.swipeOffset > this.SWIPE_THRESHOLD &&this.img_playing_ctrl==='1') {
                        // 向右滑动超过阈值，切换到上一首
                        this.handleSongChange('prev');
                      }   else if (this.swipeOffset < -this.SWIPE_THRESHOLD &&this.img_playing_ctrl==='0') {
                        this.swiperController.showNext()
                      }else if (this.swipeOffset < -this.SWIPE_THRESHOLD&&this.img_playing_ctrl==='1') {
                        // 向左滑动超过阈值，切换到下一首
                        this.handleSongChange('next');
                      } else {
                        // 未达到阈值，回弹
                        animateTo({
                          duration: 250,
                          curve: Curve.EaseOut,
                          delay: 0,
                          onFinish: () => {
                            this.isSwipingActive = false;
                            this.swipeDirection = '';
                          }
                        }, () => {
                          this.swipeOffset = 0;
                        });
                      }
                    })
                )
                .borderImage({
                  source: {
                    angle: 90,
                    direction: GradientDirection.Left,
                    colors: [[0xAEE1E1, 0.0], [0xD3E0DC, 0.3], [0xFCD1D1, 1.0]]
                  },
                  slice: { top: this.img_playing_ctrl==='1'?10:0, bottom: this.img_playing_ctrl==='1'?10:0, left: this.img_playing_ctrl==='1'?10:0, right: this.img_playing_ctrl==='1'?10:0 },
                  width: { top:this.img_playing_ctrl==='1'? "10px":"0px", bottom: this.img_playing_ctrl==='1'? "10px":"0px", left: this.img_playing_ctrl==='1'? "10px":"0px", right: this.img_playing_ctrl==='1'? "10px":"0px" },
                  repeat: RepeatMode.Stretch,
                  fill: false
                })
              TextClock()
                .fontColor(`#ff${this.imageColorHex}`)
                .format('HH:mm')
                .blendMode(BlendMode.PLUS, BlendApplyType.OFFSCREEN)
                .margin(12)
              // .backgroundBlurStyle(BlurStyle.Thin)
            }.alignContent(Alignment.BottomEnd)

          }
          .padding({
            left: 45,
            top: 12,
            bottom: 12,
            right: 12
          })
          .width('35%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

        }.alignContent(Alignment.BottomEnd)


        Column() {
          LyricsView({
            mode_judge: false
          }).width('100%').layoutWeight(1)

          Text((this.song?.name || "未知歌曲") + '/' +
            (this.song?.artists ? this.song.artists.map(artist => artist.name).join(" / ") : "未知艺术家"))
            .fontSize(this.getFontSize(this.song?.name ?? "", 16, 16))// .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(24) // 固定高度确保布局稳定
          Column(){this.PlayerControls(this.Pura_X==='1'?false:true)}.width('50%')
          Column(){
            this.ProgressBar(true,4,false)
          }.width('65%')

        }
        .padding(18)
        .width('65%')
      }.alignItems(VerticalAlign.Center).justifyContent(FlexAlign.SpaceBetween).onAppear(()=>{
        PreferencesCache.setUserPreference('Playing_HorizontalMode_index','0')
      })
      Row() {
        //封面图
        Column() {
          Image(cover(this.song?.album?.cover ?? "", 512))
            .width('60%')
            .aspectRatio(1)
            .borderRadius(this.img_playing_ctrl==='1'?0: 24)
            .borderImage({
              source: {
                angle: 90,
                direction: GradientDirection.Left,
                colors: [[0xAEE1E1, 0.0], [0xD3E0DC, 0.3], [0xFCD1D1, 1.0]]
              },
              slice: { top: this.img_playing_ctrl==='1'?10:0, bottom: this.img_playing_ctrl==='1'?10:0, left: this.img_playing_ctrl==='1'?10:0, right: this.img_playing_ctrl==='1'?10:0 },
              width: { top:this.img_playing_ctrl==='1'? "10px":"0px", bottom: this.img_playing_ctrl==='1'? "10px":"0px", left: this.img_playing_ctrl==='1'? "10px":"0px", right: this.img_playing_ctrl==='1'? "10px":"0px" },
              repeat: RepeatMode.Stretch,
              fill: false
            })
            .onAppear(async ()=>{
              try {
                const context = getContext(this);
                const resourceMgr: resourceManager.ResourceManager = context.resourceManager;
                let netFile = this.song?.album?.cover + "?param=64y64" ?? "";
                let httpRequest = http.createHttp()
                let data = await httpRequest.request(netFile);
                let imageDealData = await ImageUtils.getImageDealDataByArr(data.result as ArrayBuffer);//imageDealData.imageColorHex.length
                this.imageColorHex=imageDealData.imageColorHex
              } catch (e) {
                hilog.error(0x0000, 'TestTag', 'Failed error.code is %{public}d,error.message is %{public}s', e.code,
                  e.message);
              }
            })
            .gesture(
              PanGesture({ direction: PanDirection.Horizontal })
                .onActionStart(() => {
                  this.isSwipingActive = true;
                })
                .onActionUpdate((event) => {
                  // 更新滑动偏移量
                  this.swipeOffset = event.offsetX;

                  // 确定滑动方向
                  if (event.offsetX > 10 &&this.img_playing_ctrl==='1') {
                    this.swipeDirection = 'right'; // 向右滑动，上一首
                  } else if (event.offsetX < -10) {
                    this.swipeDirection = 'left'; // 向左滑动，下一首
                  } else {
                    this.swipeDirection = '';
                  }
                })
                .onActionEnd(() => {
                  // 根据最终偏移量决定是切换歌曲还是回弹
                  if (this.swipeOffset > this.SWIPE_THRESHOLD &&this.img_playing_ctrl==='1') {
                    // 向右滑动超过阈值，切换到上一首
                    this.handleSongChange('prev');
                  }                else  if (this.swipeOffset > this.SWIPE_THRESHOLD &&this.img_playing_ctrl==='0') {
                    // 向右滑动超过阈值，切换到上一首
                    this.swiperController.showPrevious()
                  }  else if (this.swipeOffset < -this.SWIPE_THRESHOLD&&this.img_playing_ctrl==='1') {
                    // 向左滑动超过阈值，切换到下一首
                    this.handleSongChange('next');
                  } else {
                    // 未达到阈值，回弹
                    animateTo({
                      duration: 250,
                      curve: Curve.EaseOut,
                      delay: 0,
                      onFinish: () => {
                        this.isSwipingActive = false;
                        this.swipeDirection = '';
                      }
                    }, () => {
                      this.swipeOffset = 0;
                    });
                  }
                })
            )
            .margin({bottom:5,top:20})
            .onClick(()=>{
              this.swiperController.showPrevious()
            })
          this.ProgressBar(false)

          Text((this.song?.name || "未知歌曲") + '/' +
            (this.song?.artists ? this.song.artists.map(artist => artist.name).join(" / ") : "未知艺术家"))
            .fontSize(this.getFontSize(this.song?.name ?? "", 16, 16))// .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(Color.White)
            .height(24) // 固定高度确保布局稳定
            .margin({top:5})
          this.PlayerControls(false)
        }
        .padding({
          left: 45,
          top: 12,
          bottom: 12,
          right: 12
        })
        .width('35%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        Column() {
          LyricsView({
            mode_judge: false
          }).width('100%').layoutWeight(1)
        }
        .padding(18)
        .width('65%')
      }.alignItems(VerticalAlign.Top).justifyContent(FlexAlign.SpaceBetween)
    }.loop(false)
    .onAppear( ()=>{
      this.img_playing_ctrl=  PreferencesCache.getUserPreference('img_playing_ctrl','0')
      this.is_backblur=false

    })
    .onDisAppear(()=>{
      this.is_backblur=true
    })
    .linearGradient({
      direction: GradientDirection.Bottom,
      repeating: false,
      colors: [[`#ff${this.imageColorHex}`, 0.0], [`#aa${this.imageColorHex}`, 0.3], [`#cc${this.imageColorHex}`, 0.5], [`#ff${this.imageColorHex}`, 1.0]]
    })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .animation({
      duration: 300,
      curve: Curve.Friction,
      iterations: 1,
      playMode: PlayMode.Normal
    })
    .effectMode(EdgeEffect.None)
    .curve(Curve.Smooth)
    .onChange((index:number)=>{
      if (index===1) {
        PreferencesCache.setUserPreference('Playing_HorizontalMode_index','1')
      }else {
        PreferencesCache.setUserPreference('Playing_HorizontalMode_index','0')
      }
    })
    .indicator(
      new DotIndicator().top(10)
        // .itemWidth(15)
        // .itemHeight(15)
        // .selectedItemWidth(15)
        // .selectedItemHeight(15)
        .color(Color.Gray)
        .selectedColor(Color.White)
    )
    .expandSafeArea()
    .onAppear(() => {
      if (PreferencesCache.getUserPreference('Playing_HorizontalMode_index')==='1') {
        this.swiperController.changeIndex(1)
      }else{
        this.swiperController.changeIndex(0)
      }
      screen_on(true)
    }).onDisAppear(() => {
      screen_on(false)
    })
  }

  async aboutToAppear() {
    const player = await avPlayerManager.getAVPlayerInstance()
    this.Playing_Next = isHorizontalMode()
    // 初始化当前时间和持续时间
    this.currentTime = player.currentTime
    this.isPlaying = player.state === 'playing'

    this.isFavorite = this.song?.meta?.isFavorite || false

    // 初始化宽屏检测
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;

    // 播放位置更新计时器
    this.updateTimer = setInterval(() => {
      if (this.isPlaying && this.currentTime < (this.song?.duration || 0)) {
        this.currentTime = player.currentTime;
      }
    }, 1000)

    // 初始化监听
    EventHelper.subscribeLoopMode((mode: number) => {
      animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.playMode = mode;
        this.isShuffleButtonPressed = true;
        setTimeout(() => {
          this.isShuffleButtonPressed = false;
        }, 300);
      })
    })

    EventHelper.subscribeSongState((state: "PLAY" | "PAUSE") => {
      animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
        this.isPlaying = state === "PLAY";
      })
    })

    EventHelper.subscribeFavoriteToggle(() => {
      animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
        this.isFavorite = !this.isFavorite;
      })
    })

    EventHelper.subscribePlaySong(() => {
      // 当歌曲改变时，更新当前时间和歌词
      this.isFavorite = this.song?.meta?.isFavorite || false
      this.currentTime = 0
    })

    // 添加事件监听
    avPlayerManager.addListener('onPlay', () => {
      this.isPlaying = true;
    });

    avPlayerManager.addListener('onPause', () => {
      this.isPlaying = false;
    });
  }

  aboutToDisappear() {
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer)
      this.updateTimer = -1
    }
  }

  formatTime(milliseconds: number): string {
    if (isNaN(milliseconds) || milliseconds < 0) {
      return '0:00'
    }
    const seconds = Math.floor(milliseconds / 1000)
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  getFontSize(text: string, baseSize = 18, maxLength = 36): number {
    if (!text) {
      return baseSize
    }
    if (text.length <= maxLength) {
      return baseSize
    }
    return Math.max(12, baseSize * maxLength / text.length)
  }

  calculateCurrentIndex(offset: number) {
    offset = Math.abs(offset)
    if (offset < 32) {
      return -1
    }
    return 0
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  @Builder
  BlurBackground(judge:boolean = true) {
    Stack() {
      Image(cover(this.song?.album?.cover ?? "", 512))
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .objectFit(ImageFit.Cover)
        .blur(98)
        .opacity(0.6)
        .expandSafeArea()

      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .linearGradient({
          angle: 180,
          colors: [['rgba(0,0,0,0.3)', 0.0], ['rgba(0,0,0,0.7)', 1.0]]
        })
        .expandSafeArea()
    }
    .width(judge?StyleConstants.FULL_WIDTH:0)
    .height(judge?StyleConstants.FULL_HEIGHT:0)
    .position({ x: 0, y: 0 })
    .expandSafeArea()
  }

  @Builder
  ProgressBar(judge:boolean=true,weight:number=0,judge_time_area:boolean=true) {
    Column() {
      if (judge&&judge_time_area){
        Row() {
          Text(this.formatTime(this.currentTime))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16)// 固定高度以保持布局稳定
            .animation({
              duration: 500,
              curve: Curve.Linear,
              iterations: 1,
              playMode: PlayMode.Normal
            })

          Blank()

          Text(this.formatTime(this.song?.duration || 0))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16) // 固定高度以保持布局稳定
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({ left: 8, right: 8 })
        .height(20) // 固定高度以保持布局稳定
      }


      Slider({
        value: this.currentTime,
        max: this.song?.duration || 0,
        step: 1,
        style: SliderStyle.NONE
      })
        .trackThickness(this.isProgressBarExpanded ? 8 : 4+weight)
        .selectedColor(Color.White)
        .trackColor('rgba(255, 255, 255, 0.3)')// 半透明背景
        .width(StyleConstants.FULL_WIDTH)
        .height(32)// 固定高度以保持布局稳定
        .animation({
          duration: 250,
          curve: Curve.EaseOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
        .onChange((value: number) => {
          animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
            this.currentTime = value;
          })
        })
        .onTouch((event) => {
          if (event.type === TouchType.Down) {
            this.isProgressBarExpanded = true
          } else if (event.type === TouchType.Up) {
            this.isProgressBarExpanded = false
            avPlayerManager.seek(this.currentTime)
          }
        })
      if (judge&&judge_time_area===false){
        Row() {
          Text(this.formatTime(this.currentTime))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16)// 固定高度以保持布局稳定
            .animation({
              duration: 500,
              curve: Curve.Linear,
              iterations: 1,
              playMode: PlayMode.Normal
            })

          Blank()

          Text(this.formatTime(this.song?.duration || 0))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16) // 固定高度以保持布局稳定
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({ left: 8, right: 8 })
        .height(20) // 固定高度以保持布局稳定
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: 16,
      right: 16,
      top: judge_time_area?8:0 ,
      bottom: 4
    })
    .height( judge?64:32) // 固定整个进度条区域的高度
  }

  private coverWidth = new BreakPointType({
    sm: '70%',
    md: '60%',
    lg: '50%'
  })
  private buttonSize = 48
  private smallButtonSize = 36

  @Builder
  PlayerControls(judge:boolean=true) {
    Row() {
      // Shuffle/repeat button (Left)
      if(judge){ Button({ type: ButtonType.Circle }) {
        Image(this.getPlayModeResource(this.playMode))
          .width(22)
          .height(22)
          .fillColor(Color.White)
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isShuffleButtonPressed ? 1.3 : 1.0, y: this.isShuffleButtonPressed ? 1.3 : 1.0 })
      .rotate({ angle: this.isShuffleButtonPressed ? 30 : 0 })
      .animation({
        duration: 300,
        curve: Curve.EaseOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.isShuffleButtonPressed = true
          PlaylistManager.switchPlayMode();
          setTimeout(() => {
            this.isShuffleButtonPressed = false
          }, 300)
        })
      })}



      // Previous button
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_prev'))
          .width(28)
          .height(28)
          .fillColor(Color.White)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isPrevButtonPressed ? 0.85 : 1.0, y: this.isPrevButtonPressed ? 0.85 : 1.0 })
      .opacity(this.isPrevButtonPressed ? 0.8 : 1.0)
      .animation({
        duration: 150,
        curve: Curve.EaseIn,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isPrevButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isPrevButtonPressed = false
        }
      })
      .onClick(() => {
        ClickUtil.debounce(async () => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            const prevSong = PlaylistManager.playPrevious()
            if (prevSong) {
              PlaylistManager.playSong(prevSong)
            }
          })
        }, 500, "playPrev")
      })

      // Play/pause button (center)
      Button({ type: ButtonType.Circle }) {
        Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
          .width(36)
          .height(36)
          .fillColor(Color.White)
          .animation({
            duration: 200,
            curve: Curve.EaseInOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .backgroundColor(this.isPlayButtonPressed ? 'rgba(255, 255, 255, 0.2)' : Color.Transparent)
      .width(this.buttonSize + 16)
      .height(this.buttonSize + 16)
      .scale({ x: this.isPlayButtonPressed ? 0.9 : 1.0, y: this.isPlayButtonPressed ? 0.9 : 1.0 })
      .shadow({
        radius: this.isPlaying ? 24 : 0,
        color: this.isPlaying ? 'rgba(255, 255, 255, 0.4)' : 'transparent',
        offsetX: 0,
        offsetY: 0
      })
      .animation({
        duration: 200,
        tempo: 1.0,
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal,
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isPlayButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isPlayButtonPressed = false
        }
      })
      .onClick(() => {
        animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.isPlaying = !this.isPlaying
          if (this.isPlaying) {
            avPlayerManager.play()
          } else {
            avPlayerManager.pause()
          }
        })
      })

      // Next button
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_next'))
          .width(28)
          .height(28)
          .fillColor(Color.White)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isNextButtonPressed ? 0.85 : 1.0, y: this.isNextButtonPressed ? 0.85 : 1.0 })
      .opacity(this.isNextButtonPressed ? 0.8 : 1.0)
      .animation({
        duration: 150,
        curve: Curve.EaseIn,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isNextButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isNextButtonPressed = false
        }
      })
      .onClick(() => {
        ClickUtil.debounce(async () => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            const nextSong = PlaylistManager.playNext()
            if (nextSong) {
              PlaylistManager.playSong(nextSong)
            }
          })
        }, 500, "playNext")
      })
      // Playlist button (Right)
      if (judge){      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_list'))
          .width(22)
          .height(22)
          .fillColor(Color.White)
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .translate({ x: this.isListButtonPressed ? 5 : 0, y: this.isListButtonPressed ? -5 : 0 })
      .scale({ x: this.isListButtonPressed ? 1.2 : 1.0, y: this.isListButtonPressed ? 1.2 : 1.0 })
      .animation({
        duration: 200,
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.isListButtonPressed = true
        animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.sheetType = "playlist"; // 设置当前类型为播放列表
          this.showPlaylist = true;
          setTimeout(() => {
            this.isListButtonPressed = false
          }, 300)
        })
      })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween) // Space between all buttons
    .alignItems(VerticalAlign.Center)
    .height(80) // Fixed height
  }

  // 下载歌曲
  async downloadSong() {
    if (this.song) {
      ToastUtil.showShort($r('app.string.added_to_the_download_queue'))
      SongDownloadManager.downloadSong(
        this.song.id.toString(),
        this.song,
        undefined,
        () => {
          ToastUtil.showShort($r('app.string.download_successful'))
        },
      )
    }
  }

  getWideScreenMenu(): MenuElement[] {
    return [
      {
        value: '布局翻转',
        action: () => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.flipCoverLyric = !this.flipCoverLyric
            PreferencesCache.flipCoverLyric(this.flipCoverLyric)
          })
        }
      },
      {
        value: $r('app.string.download_this_song'),
        action: () => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.downloadSong()
          })
        }
      },
      {
        value: $r('app.string.scheduled_shutdown'),
        action: () => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.sheetType = "timer";
            this.showPlaylist = true;
          })
        }
      },
    ]
  }

  getNarrowScreenMenu(): MenuElement[] {
    return [
      {
        value: $r('app.string.download_this_song'),
        action: () => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.downloadSong()
          })
        }
      },
      {
        value: $r('app.string.scheduled_shutdown'),
        action: () => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.sheetType = "timer";
            this.showPlaylist = true;
          })
        }
      },
    ]
  }

  @Builder
  BottomControls() {
    Row() {
      // 红心点赞按钮
      Button({ type: ButtonType.Circle }) {
        Image(this.isFavorite ? $r('app.media.ic_heart_fill') : $r('app.media.ic_heart'))
          .width(24)
          .height(24)
          .fillColor(this.isFavorite ? '#FF4081' : Color.White)
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isHeartButtonPressed ? 1.3 : 1.0, y: this.isHeartButtonPressed ? 1.3 : 1.0 })
      .animation({
        duration: 300,
        curve: Curve.EaseOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.isHeartButtonPressed = true
        animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
          if (this.song) {
            SourceAdapter.likeSong(this.song, !this.isFavorite)
          }
          EventHelper.postFavoriteToggle("")

          // 重置按钮状态
          setTimeout(() => {
            this.isHeartButtonPressed = false
          }, 400)
        })
      })

      // 更多菜单按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_more'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .rotate({ angle: this.isMoreButtonPressed ? 90 : 0 })
      .animation({
        duration: 300,
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.isMoreButtonPressed = true

        // 重置按钮状态
        setTimeout(() => {
          this.isMoreButtonPressed = false
        }, 300)
      })
      .bindMenu(this.isWideScreen ? this.getWideScreenMenu() : this.getNarrowScreenMenu())
    }
    .width(StyleConstants.FULL_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 16, right: 16, top: 16 })
    .height(64) // 固定高度保持布局稳定
  }

  getPlayModeResource(playMode: number) {
    switch (playMode) {
      case 0:
        return $r('app.media.ic_order_play')
      case 3:
        return $r('app.media.ic_shuffle')
      case 2:
        return $r('app.media.ic_repeat')
      case 1:
        return $r('app.media.ic_repeat_1')
      default:
        return $r('app.media.ic_order_play')
    }
  }

  @Builder
  LyricsPlaceholder() {
    Column() {
      LyricsView({
        mode_judge: true
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .transition({ type: TransitionType.All, opacity: 0.0, translate: { y: 20 } })
  }

  @Builder
  PlayingContent() {
    Column() {
      // 封面图
      Image(cover(this.song?.album?.cover ?? "", 512))
        .width(this.coverWidth.getValue(this.currentBreakpoint))
        .aspectRatio(1)
        .borderRadius(24)
        .margin({ top: 36 })
          // .geometryTransition('song-cover', { follow: true })
        .transition(TransitionEffect.OPACITY)
        .onClick(() => {
          if (!this.isWideScreen) {
            this.controller.changeIndex(1)
          }
        }) //点击图片切换到歌词页面
        .borderRadius(this.img_playing_ctrl==='1'?0:24)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart(() => {
              this.isSwipingActive = true;
            })
            .onActionUpdate((event) => {
              // 更新滑动偏移量
              this.swipeOffset = event.offsetX;

              // 确定滑动方向
              if (event.offsetX > 10 &&this.img_playing_ctrl==='1') {
                this.swipeDirection = 'right'; // 向右滑动，上一首
              } else if (event.offsetX < -10) {
                this.swipeDirection = 'left'; // 向左滑动，下一首
              } else {
                this.swipeDirection = '';
              }
            })
            .onActionEnd(() => {
              // 根据最终偏移量决定是切换歌曲还是回弹
              if (this.swipeOffset > this.SWIPE_THRESHOLD &&this.img_playing_ctrl==='1') {
                // 向右滑动超过阈值，切换到上一首
                this.handleSongChange('prev');
              } else if (this.swipeOffset < -this.SWIPE_THRESHOLD&&this.img_playing_ctrl==='1') {
                // 向左滑动超过阈值，切换到下一首
                this.handleSongChange('next');
              } else {
                // 未达到阈值，回弹
                animateTo({
                  duration: 250,
                  curve: Curve.EaseOut,
                  delay: 0,
                  onFinish: () => {
                    this.isSwipingActive = false;
                    this.swipeDirection = '';
                  }
                }, () => {
                  this.swipeOffset = 0;
                });
              }
            })
        )
        .borderImage({
          source: {
            angle: 90,
            direction: GradientDirection.Left,
            colors: [[0xAEE1E1, 0.0], [0xD3E0DC, 0.3], [0xFCD1D1, 1.0]]
          },
          slice: { top: this.img_playing_ctrl==='1'?10:0, bottom: this.img_playing_ctrl==='1'?10:0, left: this.img_playing_ctrl==='1'?10:0, right: this.img_playing_ctrl==='1'?10:0 },
          width: { top:this.img_playing_ctrl==='1'? "10px":"0px", bottom: this.img_playing_ctrl==='1'? "10px":"0px", left: this.img_playing_ctrl==='1'? "10px":"0px", right: this.img_playing_ctrl==='1'? "10px":"0px" },
          repeat: RepeatMode.Stretch,
          fill: false
        })
      // 进度条
      this.ProgressBar()

      // 歌曲信息
      Column({ space: 4 }) {
        Text(this.song?.name || "未知歌曲")
          .fontSize(this.getFontSize(this.song?.name ?? "", 24, 24))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(Color.White)
          .height(32) // 固定高度确保布局稳定

        Text(this.song?.artists ? this.song.artists.map(artist => artist.name).join(" / ") : "未知艺术家")
          .fontSize(16)
          .fontColor('rgba(255, 255, 255, 0.6)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .height(24) // 固定高度确保布局稳定
      }
      .width(StyleConstants.FULL_WIDTH)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 4, bottom: 16 })
      .height(60) // 固定整个信息区的高度

      // 底部控件 - 使用Blank占据空间，将控件推到底部
      Blank()
        .layoutWeight(1)

      // 播放控制区
      this.PlayerControls()

      // 底部控件 - 使用Blank占据空间，将控件推到底部
      Blank()
        .layoutWeight(2)

      // 底部控件
      Column() {
        this.BottomControls()
      }
    }
    .padding(16)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  sheet() {
    // 根据当前的sheetType渲染不同的内容
    if (this.sheetType === "playlist") {
      this.PlayListBuilder()
    } else if (this.sheetType === "timer") {
      this.Timer()
    }
  }

  @Builder
  Title() {
    Row() {
      Image($r('app.media.ic_arrow_down_3'))
        .width(36)
        .height(36)
        .fillColor(Color.White)
        .margin({ left: 24 })
        .rotate({ angle: this.isBackButtonPressed ? 180 : 0 })
        .scale({ x: this.isBackButtonPressed ? 0.8 : 1.0, y: this.isBackButtonPressed ? 0.8 : 1.0 })
        .animation({
          duration: 300,
          curve: Curve.EaseOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
        .onClick(() => {
          this.isBackButtonPressed = true
          this.pageStack.pop()
        })
      if (this.Pura_X==='1'){
        Blank().layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          Image(this.isFavorite ? $r('app.media.ic_heart_fill') : $r('app.media.ic_heart'))
            .width(24)
            .height(24)
            .fillColor(this.isFavorite ? '#FF4081' : Color.White)
            .animation({
              duration: 300,
              curve: Curve.EaseOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .width(this.buttonSize)
        .height(this.buttonSize)
        .backgroundColor(Color.Transparent)
        .scale({ x: this.isHeartButtonPressed ? 1.3 : 1.0, y: this.isHeartButtonPressed ? 1.3 : 1.0 })
        .animation({
          duration: 300,
          curve: Curve.EaseOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
        .onClick(() => {
          this.isHeartButtonPressed = true
          animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
            if (this.song) {
              SourceAdapter.likeSong(this.song, !this.isFavorite)
            }
            EventHelper.postFavoriteToggle("")

            // 重置按钮状态
            setTimeout(() => {
              this.isHeartButtonPressed = false
            }, 400)
          })
        })

        // 更多菜单按钮
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_more'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
        }
        .width(this.buttonSize)
        .height(this.buttonSize)
        .backgroundColor(Color.Transparent)
        .rotate({ angle: this.isMoreButtonPressed ? 90 : 0 })
        .animation({
          duration: 300,
          curve: Curve.EaseInOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
        .onClick(() => {
          this.isMoreButtonPressed = true

          // 重置按钮状态
          setTimeout(() => {
            this.isMoreButtonPressed = false
          }, 300)
        })
        .bindMenu(this.isWideScreen ? this.getWideScreenMenu() : this.getNarrowScreenMenu())
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(VerticalAlign.Center)
    .height(48) // 固定标题栏高度
  }

  build() {
    NavDestination() {
      FolderStack() {
        // 背景

          this.BlurBackground(this.is_backblur)


        Column() {
          // 标题栏


          // 根据屏幕尺寸显示不同布局
          if (this.isWideScreen && this.Playing_Next == false) {
            this.Title()
            // 宽屏布局 - 左右分栏
            Row() {
              if (this.flipCoverLyric) {
                Column() {
                  // 右侧歌词
                  this.LyricsPlaceholder()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: 20 }, opacity: 0.0 })

                Column() {
                  // 左侧播放内容
                  this.PlayingContent()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: -20 }, opacity: 0.0 })
              } else {
                Column() {
                  // 左侧播放内容
                  this.PlayingContent()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: -20 }, opacity: 0.0 })

                Column() {
                  // 右侧歌词
                  this.LyricsPlaceholder()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: 20 }, opacity: 0.0 })
              }
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .layoutWeight(1)
          } else if (this.isWideScreen && this.Playing_Next) {
            this.Playing_HorizontalMode()
          } else {

            this.Title()
            // 窄屏布局 - Tabs切换
            Tabs({ barPosition: BarPosition.End, index: this.selectedTabIndex, controller: this.controller }) {
              TabContent() {
                // 播放内容
                Column() {
                  this.PlayingContent()
                }
              }
              .transition({ type: TransitionType.All, opacity: 0.0, translate: { x: -20 } })

              TabContent() {
                // 歌词
                this.LyricsPlaceholder()
              }
              .transition({ type: TransitionType.All, opacity: 0.0, translate: { x: 20 } })
            }
            .scrollable(true)
            .barMode(BarMode.Fixed)
            .layoutWeight(1)
            .clip(false)
            .barHeight(0)
            .onChange((index: number) => {
              animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
                this.selectedTabIndex = index
              })
            })
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .onHoverStatusChange((msg) => {
        console.log('this foldStatus:' + msg.foldStatus);
        console.log('this isHoverMode:' + msg.isHoverMode);
        console.log('this appRotation:' + msg.appRotation);
        console.log('this windowStatusType:' + msg.windowStatusType);
      })
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .expandSafeArea()
    }
    .systemTransition(NavigationSystemTransitionType.FADE)
    .hideToolBar(true)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .expandSafeArea()
    .onAppear(()=>{
      this.img_playing_ctrl=  PreferencesCache.getUserPreference('img_playing_ctrl','0')
    })
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // .onBackPressed(()=> {
    //   animateTo({
    //     duration: 100,
    //     // 构造插值器弹簧曲线对象，生成一条从0到1的动画曲线
    //     curve: curves.interpolatingSpring(0, 1, 324, 38),
    //     // curve:Curve.Linear
    //   }, () => {
    //     this.pageStack.pop()
    //   })
    //   return true
    // })
    .gesture(
      SwipeGesture({
        // 竖直方向滑动
        direction: SwipeDirection.Vertical,
      }).onAction((event) => {
        if (event.angle < -45 && event.angle > -135) {
          // 向上滑，显示播放列表
          animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
            this.sheetType = "playlist";
            this.showPlaylist = true;
          })
        } else if (event.angle > 45 && event.angle < 135) {
          this.pageStack.pop()
        }
      })
    )
    .onSizeChange(() => {
      this.Playing_Next = isHorizontalMode()
    })
    .bindSheet($$this.showPlaylist, this.sheet, {
      showClose: false,
      height: SheetSize.MEDIUM,
      dragBar: false,
      preferType: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ? SheetType.BOTTOM : SheetType.CENTER,
      onWillDismiss: () => {
        this.showPlaylist = false;
        this.sheetType = "playlist";
      }
    })
  }
}