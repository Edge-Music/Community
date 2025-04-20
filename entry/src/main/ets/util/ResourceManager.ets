import { resourceManager } from "@kit.LocalizationKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { common } from "@kit.AbilityKit";

export class ResourceManager {

  static getStringArrayValueSync(res: Resource): string[] {
    let result: string[] = []
    try {
      const context = getContext() as common.UIAbilityContext
      result = context.resourceManager.getStringArrayValueSync(res.id);
    } catch (error) {
      let code = (error as BusinessError).code;
      let message = (error as BusinessError).message;
      console.error(`getStringArrayValueSync failed, error code: ${code}, message: ${message}.`);
    } finally {
      return result
    }
  }

  static getStringValueSync(res: Resource): string {
    let result: string = ''
    try {
      const context = getContext() as common.UIAbilityContext
      result = context.resourceManager.getStringSync(res.id)
    } catch (error) {
      let code = (error as BusinessError).code;
      let message = (error as BusinessError).message;
      console.error(`getStringArrayValueSync failed, error code: ${code}, message: ${message}.`);
    } finally {
      return result
    }
  }

}