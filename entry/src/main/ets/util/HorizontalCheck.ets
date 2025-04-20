import { display } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit'
import { window } from '@kit.ArkUI';
const TAG = '横屏状态'

/**
 * 检测当前设备是否处于横屏模式
 * @returns {boolean} 是否横屏模式
 */
export function isHorizontalMode(): boolean {
  // 检查设备是否支持折叠
  const isFoldable = display.isFoldable();
  let deviceTypeInfo: string = deviceInfo.deviceType;
  // 默认假设为横屏模式
  let productSeries:string=deviceInfo.productSeries
  let isHorizontalMode = true;

  if (isFoldable) {
    // 获取折叠状态
    const foldStatus = display.getFoldStatus();
    if (foldStatus !== display.FoldStatus.FOLD_STATUS_FOLDED) {
      isHorizontalMode = false;
    }
  }
  if(deviceTypeInfo=='tablet'||deviceTypeInfo=='2in1') {
    isHorizontalMode = false;
  }
  if(productSeries=='VDE'||productSeries=='LEM') {
    isHorizontalMode = true;
  }
  return isHorizontalMode;
}
//HorizontalMode
//true为设置窗口方向为传感器跟随系统自动旋转模式。
//false为设置窗口方向为传感器自动旋转模式。

export function  HorizontalMode(judge:boolean){
  try {
    if(judge===true){
      window.getLastWindow(getContext(), (err, data) => { // 获取window实例
        if (err.code) {
          console.error(TAG, 'Failed to obtain the top window. Cause: ' + JSON.stringify(err));
          return;
        }
        let windowClass = data;
        console.info(TAG, 'Succeeded in obtaining the top window. Data: ' + JSON.stringify(data));
        let orientation = window.Orientation.AUTO_ROTATION_RESTRICTED; // 设置窗口方向为传感器跟随系统自动旋转模式。
        try {
          windowClass.setPreferredOrientation(orientation, (err) => {
            if (err.code) {
              console.error(TAG, 'Failed to set window orientation. Cause: ' + JSON.stringify(err));
              return;
            }
            console.info(TAG, 'Succeeded in setting window orientation.');
          });
        } catch (exception) {
          console.error(TAG, 'Failed to set window orientation. Cause: ' + JSON.stringify(exception));
        }
        ;
      });
    }else if(judge==false){
      window.getLastWindow(getContext(), (err, data) => { // 获取window实例
        if (err.code) {
          console.error(TAG, 'Failed to obtain the top window. Cause: ' + JSON.stringify(err));
          return;
        }
        let windowClass = data;
        console.info(TAG, 'Succeeded in obtaining the top window. Data: ' + JSON.stringify(data));
        let orientation = window.Orientation.AUTO_ROTATION; // 设置窗口方向为传感器自动旋转模式。
        try {
          windowClass.setPreferredOrientation(orientation, (err) => {
            if (err.code) {
              console.error(TAG, 'Failed to set window orientation. Cause: ' + JSON.stringify(err));
              return;
            }
            console.info(TAG, 'Succeeded in setting window orientation.');
          });
        } catch (exception) {
          console.error(TAG, 'Failed to set window orientation. Cause: ' + JSON.stringify(exception));
        }
        ;
      });
    }
  } catch (exception) {
    console.error(TAG, 'judge' + JSON.stringify(exception));
  }
}
