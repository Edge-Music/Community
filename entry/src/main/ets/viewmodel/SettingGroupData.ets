import { LogUtil, ToastUtil, WantUtil } from "@pura/harmony-utils";
import { SettingItem } from "../model/SettingItem";
import { BusinessError } from "@kit.BasicServicesKit";
import { getQualityLevel, PreferencesCache, qualityLevels } from "../util/PreferenceCache";
import { DialogAction, DialogHelper } from "@pura/harmony-dialog";
import { ResponseCacheUtil } from "../util/ResponseCacheUtil";
import { SongCacheManager } from "../util/SongCacheManager";
import { ResourceManager } from "../util/ResourceManager";

// 音乐播放设置组
export const PlayerSetting = [
  // new SettingItem("toggle", $r('app.string.setting_interrupting_continue'), "暂无试验出稳定效果，所以这个只是装饰用",
  //   PreferencesCache.interruptingContinue(), undefined, () => {
  //     const newValue = !PreferencesCache.interruptingContinue();
  //     PreferencesCache.interruptingContinue(newValue);
  //     PlayerSetting[0].value = newValue
  //   }),
  new SettingItem("text-switch", $r('app.string.setting_playing_level'), undefined,
    getQualityLevel(PreferencesCache.playingLevel()).description, () => {
      DialogHelper.showSelectDialog({
        title: $r('app.string.setting_playing_level'),
        confirm: $r('app.string.back'),
        selectedIndex: qualityLevels.findIndex(bitrate => bitrate.bitrate === PreferencesCache.playingLevel()),
        radioContent: qualityLevels.map(level => level.description),
        onCheckedChanged: (index) => {
          const bitrate = qualityLevels[index].bitrate;
          const quality = getQualityLevel(bitrate);
          PreferencesCache.playingLevel(bitrate);
          PlayerSetting[0].value = quality.description
          AppStorage.setOrCreate("PlayerSetting", PlayerSetting)
          ToastUtil.showToast("音质已设置为：" + ResourceManager.getStringValueSync(quality.description as Resource));
        },
        onAction: () => {
        }
      })
    }),
  new SettingItem("text-switch", $r('app.string.setting_download_level'), undefined,
    getQualityLevel(PreferencesCache.downloadLevel()).description, () => {
      DialogHelper.showSelectDialog({
        title: $r('app.string.setting_download_level'),
        confirm: $r('app.string.back'),
        selectedIndex: qualityLevels.findIndex(bitrate => bitrate.bitrate === PreferencesCache.downloadLevel()),
        radioContent: qualityLevels.map(level => level.description),
        onCheckedChanged: (index) => {
          const bitrate = qualityLevels[index].bitrate;
          const quality = getQualityLevel(bitrate);
          PreferencesCache.downloadLevel(bitrate);
          PlayerSetting[1].value = quality.description
          AppStorage.setOrCreate("PlayerSetting", PlayerSetting)
          ToastUtil.showToast("音质已设置为：" + ResourceManager.getStringValueSync(quality.description as Resource));
        },
        onAction: () => {
        }
      })
    }),
  new SettingItem("text-input", $r('app.string.setting_playing_cache'),
    $r('app.string.setting_playing_cache_desc'), PreferencesCache.playingCache().toString(), () => {
      DialogHelper.showTextInputDialog({
        title: $r('app.string.setting_playing_cache'),
        buttons: [$r('app.string.cancel'), $r('app.string.confirm')],
        text: PlayerSetting[2].value?.toString(),
        inputType: InputType.Number,
        cancelButton: {
          style: CancelButtonStyle.INVISIBLE
        },
        onAction: (action, _dialogId, content) => {
          if (action == DialogAction.SURE) {
            const cache = parseInt(content);
            if (cache >= 0) {
              PreferencesCache.playingCache(cache);
              PlayerSetting[2].value = cache.toString()
              AppStorage.setOrCreate("PlayerSetting", PlayerSetting)
              if (cache === 0) {
                ToastUtil.showToast("现在没有播放缓存了，你满意了吧！");
              } else {
                ToastUtil.showToast("最大缓存数量已设置为：" + cache + "个");
              }
            } else {
              ToastUtil.showToast("讲真，你有点搞！");
            }
          }
        }
      })
    })
]

// 软件设置组
export const SoftwareSetting = [
  new SettingItem("text-input", $r('app.string.setting_request_cache_expire'),
    $r('app.string.setting_request_cache_expire_desc'), PreferencesCache.requestCacheExpire().toString(), () => {
      DialogHelper.showTextInputDialog({
        title: $r('app.string.setting_request_cache_expire'),
        buttons: [$r('app.string.cancel'), $r('app.string.confirm')],
        text: SoftwareSetting[0].value?.toString(),
        inputType: InputType.Number,
        cancelButton: {
          style: CancelButtonStyle.INVISIBLE
        },
        onAction: (action, _dialogId, content) => {
          if (action == DialogAction.SURE) {
            const expire = parseInt(content);
            SoftwareSetting[0].value = expire.toString()
            AppStorage.setOrCreate("SoftwareSetting", SoftwareSetting)
            if (expire >= 0) {
              PreferencesCache.requestCacheExpire(expire);
              if (expire === 0) {
                ToastUtil.showToast("现在没有请求缓存了，你满意了吧！");
              } else {
                ToastUtil.showToast("请求缓存过期时间已设置为：" + expire + "天");
              }
            } else {
              ToastUtil.showToast("讲真，你有点搞！");
            }
          }
        }
      })
    }),
  new SettingItem("button", $r('app.string.setting_clear_cache_song'), undefined, undefined, async () => {
    const size = SongCacheManager.size();
    if (size > 0) {
      await SongCacheManager.clear();
      ToastUtil.showToast("已清除" + size + "首歌曲缓存");
    } else {
      ToastUtil.showToast("暂无歌曲缓存");
    }
  }),
  new SettingItem("button", $r('app.string.setting_clear_cache_request'), undefined, undefined, () => {
    const size = ResponseCacheUtil.size();
    if (size > 0) {
      ResponseCacheUtil.clear();
      ToastUtil.showToast("已清除" + size + "个请求缓存");
    } else {
      ToastUtil.showToast("暂无请求缓存");
    }
  }),
]

// 关于设置组
export const AboutSetting = [
  new SettingItem("button", $r('app.string.setting_about'), undefined, undefined, () => {
    AppStorage.setOrCreate("setting_page_sheet_content", "about")
    AppStorage.setOrCreate("setting_page_sheet_show", true)
  }),
  new SettingItem("button", $r('app.string.setting_feedback'), undefined, undefined, () => {
    WantUtil.toWebBrowser("https://music.yby.zone/feedback.html")
      .catch((err: BusinessError) => {
        LogUtil.error("SettingGroupData", "拉起失败！", err.message);
        ToastUtil.showToast("跳转到浏览器失败！");
      });
  }),
  new SettingItem("button", $r('app.string.setting_privacy'), undefined, undefined, () => {
    WantUtil.toWebBrowser("https://music.yby.zone/policy.html")
      .catch((err: BusinessError) => {
        LogUtil.error("SettingGroupData", "拉起失败！", err.message);
        ToastUtil.showToast("跳转到浏览器失败！");
      });
  }),
  new SettingItem("button", $r('app.string.custom_settings'), undefined, undefined, () => {
    AppStorage.setOrCreate("setting_page_sheet_content", "Personalized_settings")
    AppStorage.setOrCreate("setting_page_sheet_show", true)
  }),
]
