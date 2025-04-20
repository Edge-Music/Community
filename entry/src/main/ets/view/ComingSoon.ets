@Component
export struct ComingSoon {
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State isButtonPressed: boolean = false;

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        // 对话框卡片
        Column() {

          // 标题文本
          Text("Coming Soon")
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ bottom: 16 })

          // 辅助描述文本
          Text("我们正在努力开发这项功能")
            .fontSize(16)
            .fontColor('#666666')
            .margin({ bottom: 8 })

          Text("敬请期待...")
            .fontSize(14)
            .fontColor('#888888')
            .fontStyle(FontStyle.Italic)
            .margin({ bottom: 32 })

          // 按钮
          Button() {
            Row() {
              Text($r('app.string.back'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('80%')
          .height(46)
          .borderRadius(23)
          .backgroundColor(this.isButtonPressed ? '#5D4FB8' : '#6A5ACD')
          .shadow({
            radius: 8,
            color: 'rgba(106, 90, 205, 0.3)',
            offsetY: 4
          })
          .scale({ x: this.isButtonPressed ? 0.96 : 1.0, y: this.isButtonPressed ? 0.96 : 1.0 })
          .animation({
            duration: 100,
            curve: Curve.EaseInOut
          })
          .onTouch((event) => {
            if (event.type === TouchType.Down) {
              this.isButtonPressed = true;
            } else if (event.type === TouchType.Up) {
              this.isButtonPressed = false;
            }
          })
          .onClick(() => {
            this.pageStack.pop();
          })
          .margin({ bottom: 24 })
        }
        .width('70%')
        .padding({ top: 16, bottom: 16 })
        .backgroundColor(Color.White)
        .borderRadius(16)
        .shadow({
          radius: 24,
          color: 'rgba(0, 0, 0, 0.15)',
          offsetY: 4
        })
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.SpaceBetween)
        .animation({
          duration: 400,
          curve: Curve.EaseOut,
          delay: 50,
          iterations: 1,
          playMode: PlayMode.Normal
        })
      }
      .height("100%")
      .width('100%')
      .gesture(
        TapGesture()
          .onAction(() => {
            this.pageStack.pop();
          })
      )
    }
    .backgroundColor('transparent')
    .hideTitleBar(true)
    .mode(NavDestinationMode.DIALOG)
  }
}