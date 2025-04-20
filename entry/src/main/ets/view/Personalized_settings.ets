import { PreferencesCache } from "../util/PreferenceCache";
import {HorizontalMode}from '../util/HorizontalCheck'
import { ResourceManager } from "../util/ResourceManager";

@Component
//'0'关。'1'开。!!!!(开关颜色日后调)
export struct Personalized_settings_Component {
  @State text_name: string = '';
  @State setUserPreference_name: string = '';
  private  text_ctrl:string =  PreferencesCache.getUserPreference(this.setUserPreference_name)
  build() {
    Column(){
      Row(){
        Text(this.text_name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: PreferencesCache.getUserPreference(this.setUserPreference_name)==='1'?true:false})
          .switchPointColor('#46B1E3')
          .selectedColor('#A6C2BE')
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.text_ctrl ='1'
              PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
            }else {
              this.text_ctrl ='0'
              PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

    }
    .padding(16)
    .backgroundColor($r('app.color.card_background_two'))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}


@Component
export struct Personalized_settings{
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State HorizontalMode_ctrl:string =  PreferencesCache.getUserPreference('HorizontalMode_ctrl','0')
  @Builder
  HorizontalMode_Ctrl(){
    Column(){
      Row(){
        Text($r('app.string.system_rotary_switch'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.HorizontalMode_ctrl==='1'?true:false})
          .switchPointColor('#46B1E3')
          .selectedColor('#A6C2BE')
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.HorizontalMode_ctrl ='1'
              HorizontalMode(this.HorizontalMode_ctrl==='1')
              PreferencesCache.setUserPreference('HorizontalMode_ctrl', this.HorizontalMode_ctrl)
            }else {
              this.HorizontalMode_ctrl ='0'
              HorizontalMode(this.HorizontalMode_ctrl==='1')
              PreferencesCache.setUserPreference('HorizontalMode_ctrl', this.HorizontalMode_ctrl)
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

    }
    .padding(16)
    .backgroundColor($r('app.color.card_background_two'))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination(){
      Column(){
        List({ space: 8, initialIndex: 0 }){
          ListItem(){this.HorizontalMode_Ctrl()}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.mini_music_control_bottom')), setUserPreference_name:'miniplaying_bottom_judge'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.swipe_cover_switch_songs')), setUserPreference_name:'img_playing_ctrl'})}
        }
      }.padding(16)
    }.title($r('app.string.custom_settings')).hideToolBar(true)

  }
}