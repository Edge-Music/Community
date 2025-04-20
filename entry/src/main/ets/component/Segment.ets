import { StyleConstants } from "../constants/StyleConstants"
import { Cover } from "./Cover"
import { HorizontalScroll } from "./HorizontalScroll"

@Component
export struct Segment {
  @Prop loading: boolean = false
  title: string | Resource = ''
  actionText: string | undefined | Resource = undefined
  onActionClick?: () => void
  radius: string | number = 8

  @BuilderParam
  items?: () => void

  @Builder
  private SkeletonLoading() {
    Column() {
      Row() {
        Text()
          .width('30%')
          .height(20)
          .backgroundColor($r('app.color.skeleton_loading'))
          .borderRadius(4)

        if(this.actionText) {
          Text()
            .width('20%')
            .height(16)
            .backgroundColor($r('app.color.skeleton_loading'))
            .borderRadius(4)
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({
        left: 12,
        top: 8,
        right: 12,
        bottom: 4
      })

      HorizontalScroll() {
        ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], () => {
          Cover({
            loading: true,
            src: $r('app.media.ic_placeholder'),
            title: '',
            radius: this.radius
          })
            .width(120)
            .padding(4)
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if(this.loading) {
        this.SkeletonLoading()
      } else {
        Row() {
          Text(this.title)
            .fontColor($r('app.color.text_title'))
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontSize(20)

          if(this.actionText) {
            Row(){
              Text(this.actionText)
                .fontColor($r('app.color.text_secondary'))
                .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
                .fontSize(14)

              Image($r('app.media.refresh'))
                .width(16)
                .fillColor($r('app.color.text_secondary'))
                .margin({ left: 2 })
            }
            .onClick(this.onActionClick)
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({
          left: 12,
          top: 8,
          right: 12,
          bottom: 4
        })

        HorizontalScroll() {
          this.items?.()
        }
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding(12)
  }
}