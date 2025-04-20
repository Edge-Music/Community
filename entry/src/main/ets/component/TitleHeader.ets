import { StyleConstants } from "../constants/StyleConstants";

@Component
export struct TitleHeader {
  @Consume('NavPathStack') pageStack: NavPathStack;
  @Prop title: ResourceStr = $r("app.string.homepage")
  @BuilderParam rightContent: () => void;
  @BuilderParam midContent: () => void;
  @State isFirstPage: boolean = true
  @Prop backActive: boolean = false

  aboutToAppear() {
    this.isFirstPage = false
  }

  @Builder
  BackButton() {
    if (!this.isFirstPage) {
      Row() {
        Image($r('app.media.ic_back'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.text_primary'))
          .scale({ x: this.backActive ? 0.9 : 1, y: this.backActive ? 0.9 : 1 })
          .translate({ x: this.backActive ? 4 : 0 })
          .animation({
            duration: 150,
            curve: Curve.FastOutSlowIn
          })
        Text($r('app.string.back'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 2 })
      }
      .height(28)
      .borderRadius(14)
      .padding({ left: 6, right: 10 })
      .backgroundColor($r('app.color.back_button_normal'))
      .onClick(() => {
        this.pageStack.pop()
      })
      .scale({ x: this.backActive ? 1.05 : 1, y: this.backActive ? 1.05 : 1 })
      .animation({
        duration: 150,
        curve: Curve.FastOutSlowIn
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row() {
        Row() {
          // this.BackButton()

          Text(this.title)
            .fontColor($r('app.color.text_title'))
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontSize($r('app.float.title_font_size'))
            .maxLines(1)

          // 自定义左侧
          if(this.midContent){
            this.midContent()
          }
          // 自定义右侧
          if (this.rightContent) {
            this.rightContent()
          }
          // Blank()
        }
        .padding({ left: 16, right: 16})
        .justifyContent(FlexAlign.SpaceBetween)
        .width(StyleConstants.FULL_WIDTH)
        .alignItems(VerticalAlign.Center)
        Row() {
          Text($r('app.string.back'))
            .fontColor($r('app.color.text_title'))
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontSize($r('app.float.title_font_size'))
            .maxLines(1)
        }
        .padding({ left: 16 })


      }
      .width(StyleConstants.FULL_WIDTH)
      .backgroundColor(Color.Transparent)
      .height(50)
      .translate({ x: this.backActive ? '-100%' : 0 }) // 初始值16与所有标题左padding一致
      .animation({
        duration: 300,
        curve: Curve.FastOutSlowIn
      })
    }
  }
}