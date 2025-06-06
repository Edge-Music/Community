import { AnimationConstants } from "../constants/AnimationConstants"

@Component
export struct MenuIcon {
  @Prop active: boolean = false
  @Prop icon?: Resource = undefined

  build() {
    Button({ type: ButtonType.Normal }) {
      Image(this.icon)
        .width(24)
        .height(24)
        .fillColor(this.active ? $r('app.color.text_primary') : $r('app.color.icon_normal'))
        .scale(this.active ? { x: 1.1, y: 1.1 } : { x: 1, y: 1 })
        .animation({
          duration: AnimationConstants.ANIMATION_DURATION,
          curve: Curve.EaseOut,
          playMode: PlayMode.Normal,
        })
    }
    .backgroundColor(this.active ? 'rgba(0, 0, 0, 0.05)' : Color.Transparent)
    .width(36)
    .height(36)
    .borderRadius("50%")
    .margin({
      top: 8,
      bottom: 16,
      left: 4,
      right: 4
    })
    .animation({
      duration: AnimationConstants.ANIMATION_DURATION,
      curve: Curve.EaseOut,
      playMode: PlayMode.Normal,
    })
  }
}