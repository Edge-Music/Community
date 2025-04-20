import { DialogAction, DialogHelper } from "@pura/harmony-dialog"
import { ToastUtil } from "@pura/harmony-utils"
import { EventHelper } from "../util/EventHelper"

@Component
export struct TimerSelector {
  @StorageLink('playing_pause_time') pauseAt: number = -1
  @State remainingTime: string = ''
  @State selectedOption: number = -1
  @State isVisible: boolean = false
  @State showTimerUI: boolean = false
  private timerId: number | null = null
  // 预设时间选项（分钟）
  private readonly timeOptions: number[] = [10, 15, 20, 30, 45, 60, 90, 120]

  aboutToAppear() {
    this.startCountdown()
    // Initialize selected option if timer is active
    if (this.pauseAt > 0) {
      const remainingMinutes = Math.floor((this.pauseAt - Date.now()) / 60000)
      this.selectedOption = this.timeOptions.includes(remainingMinutes) ? remainingMinutes : -1
      this.showTimerUI = true
    }

    // Trigger entrance animation
    setTimeout(() => {
      this.isVisible = true
    }, 50)
  }

  aboutToDisappear() {
    if (this.timerId !== null) {
      clearInterval(this.timerId)
      this.timerId = null
    }
  }

  private updateRemainingTime() {
    const remaining = this.pauseAt - Date.now()
    if (remaining <= 0) {
      // Animate out the timer UI first, then clear the time
      if (this.showTimerUI) {
        this.showTimerUI = false
        setTimeout(() => {
          this.remainingTime = ''
          this.selectedOption = -1
        }, 300) // Match animation duration
      } else {
        this.remainingTime = ''
        this.selectedOption = -1
      }
      return
    }

    const hours = Math.floor(remaining / 3600000)
    const minutes = Math.floor((remaining % 3600000) / 60000)
    const seconds = Math.floor((remaining % 60000) / 1000)

    if (hours > 0) {
      this.remainingTime = `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    } else {
      this.remainingTime = `${minutes}:${seconds.toString().padStart(2, '0')}`
    }

    // Show timer UI if it's not already visible
    if (!this.showTimerUI) {
      this.showTimerUI = true
    }
  }

  private startCountdown() {
    if (this.timerId !== null) {
      clearInterval(this.timerId)
    }
    this.updateRemainingTime() // Update immediately
    this.timerId = setInterval(() => {
      this.updateRemainingTime()
    }, 1000)
  }

  private setTimer(minutes: number) {
    animateTo({
      duration: 300,
      curve: Curve.EaseInOut
    }, () => {
      this.showTimerUI = true
      const now = Date.now()
      const endTime = now + minutes * 60000 // 计算结束时间
      this.pauseAt = endTime // 更新暂停时间
      this.selectedOption = minutes // 更新选中选项
      EventHelper.postPauseTimer(endTime)
    })
  }

  private cancelTimer() {
    animateTo({
      duration: 300,
      curve: Curve.EaseInOut
    }, () => {
      this.showTimerUI = false
      this.pauseAt = -1
      this.selectedOption = -1
      EventHelper.postPauseTimer(-1)
    })
  }

  @Builder
  TimeOption(minutes: number, index: number) {
    Button({ type: ButtonType.Capsule }) {
      Row() {
        Text(minutes.toString())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(minutes === this.selectedOption ? $r('app.color.dialog_background') : $r('app.color.text_primary'))

        Text($r('app.string.minute'))
          .fontSize(12)
          .opacity(0.9)
          .margin({ left: 4 })
          .fontColor(minutes === this.selectedOption ? $r('app.color.dialog_background') :
          $r('app.color.text_secondary'))
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16 })
    }
    .height(44)
    .backgroundColor(minutes === this.selectedOption ? $r('app.color.text_primary') :
    $r('app.color.back_button_normal'))
    .margin({ right: 12, bottom: 16 })
    .borderRadius(22)
    .stateEffect(true)
    .onClick(() => this.setTimer(minutes))
    .animation({
      duration: 300,
      curve: Curve.EaseOut,
      delay: 50 + index * 30,
      iterations: 1,
      playMode: PlayMode.Normal
    })
    .transition({ type: TransitionType.All })
    .opacity(this.isVisible ? 1 : 0)
    .translate({ y: this.isVisible ? 0 : 20 })
  }

  build() {
    Column() {
      // Use fixed heights for transition areas to prevent content jump
      Column() {
        if (this.remainingTime !== '') {
          // Timer controls area - animate its height and opacity
          Row() {
            Text('开启')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ right: 12 })

            Toggle({ type: ToggleType.Switch, isOn: true })
              .width(44)
              .height(24)
              .switchPointColor($r('app.color.icon_normal'))
              .selectedColor($r('app.color.back_button_normal'))
              .onChange((isOn) => {
                if (!isOn) {
                  this.cancelTimer()
                }
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .animation({
            duration: 300,
            curve: Curve.EaseInOut
          })
          .opacity(this.showTimerUI ? 1 : 0)
          .height(this.showTimerUI ? 40 : 0)
        }
      }
      .width('100%')
      .height(this.remainingTime !== '' ? 40 : 0)
      .transition({ type: TransitionType.All })

      // Timer display area - fixed height container that animates
      Column() {
        if (this.remainingTime) {
          Column() {
            Text('剩余时间')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 8 })

            Text(this.remainingTime)
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .padding({ top: 20, bottom: 20 })
          .backgroundColor($r('app.color.background_gray'))
          .borderRadius(16)
          .animation({
            duration: 300,
            curve: Curve.EaseInOut
          })
          .opacity(this.showTimerUI ? 1 : 0)
          .scale({ x: this.showTimerUI ? 1 : 0.95, y: this.showTimerUI ? 1 : 0.95 })
        }
      }
      .animation({
        duration: 300,
        curve: Curve.EaseInOut
      })
      .height(this.remainingTime ? (this.showTimerUI ? 120 : 0) : 0)
      .margin({ bottom: this.remainingTime && this.showTimerUI ? 24 : 0 })
      .transition({ type: TransitionType.All })

      // Section title for time options
      Text($r('app.string.select_time'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)
        .margin({ top: 8, bottom: 16 })
        .animation({
          duration: 400,
          curve: Curve.EaseOut,
          delay: 200,
          iterations: 1,
          playMode: PlayMode.Normal
        })
        .opacity(this.isVisible ? 1 : 0)
        .translate({ y: this.isVisible ? 0 : 10 })

      // Preset time options with more spacing
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.timeOptions, (minutes: number, index: number) => {
          this.TimeOption(minutes, index)
        })
      }
      .width('100%')
      .padding({ top: 8, bottom: 12 })
      .margin({ bottom: 24 })

      // Custom time button
      Button() {
        Row() {
          Text($r('app.string.custom_time'))
            .fontColor($r('app.color.text_primary'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .backgroundColor($r('app.color.tag_background'))
      .height(52)
      .width('100%')
      .borderRadius(26)
      .onClick(() => {
        DialogHelper.showTextInputDialog({
          title: $r('app.string.set_scheduled_shutdown'),
          text: this.pauseAt > 0 ? Math.floor((this.pauseAt - Date.now()) / 60000).toString() : '',
          inputType: InputType.Number,
          cancelButton: {
            style: CancelButtonStyle.INVISIBLE
          },
          onAction: (action: number, _dialogId: string, value: string): void => {
            if (action == DialogAction.SURE) {
              const min = parseInt(value)
              if (isNaN(min) || min <= 0) {
                ToastUtil.showToast("请输入一个有效的分钟数")
                return
              }
              this.setTimer(min)
            }
          }
        })
      })
      .animation({
        duration: 500,
        curve: Curve.EaseOut,
        delay: 300 + this.timeOptions.length * 30,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .opacity(this.isVisible ? 1 : 0)
      .scale({ x: this.isVisible ? 1 : 0.9, y: this.isVisible ? 1 : 0.9 })
    }
    .width('100%')
    .height("100%")
    .padding(24)
    .borderRadius(20)
    .animation({
      duration: 350,
      curve: Curve.EaseOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
    .opacity(this.isVisible ? 1 : 0)
    .scale({ x: this.isVisible ? 1 : 0.9, y: this.isVisible ? 1 : 0.9 })
  }
}