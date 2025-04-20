export class SettingItem {
  type: "toggle" | "text-switch" | "text-input" | "button";
  title: ResourceStr;
  subtitle?: ResourceStr;
  value?: string | boolean | Resource;
  onClick?: () => void;
  onChange?: (value: boolean) => void;

  constructor(type: "toggle" | "text-switch" | "text-input" | "button",
    title: ResourceStr,
    subtitle?: ResourceStr,
    value?: string | boolean | Resource,
    onClick?: () => void,
    onChange?: (value: boolean) => void) {
    this.type = type;
    this.title = title;
    this.subtitle = subtitle;
    this.value = value;
    this.onClick = onClick;
    this.onChange = onChange;
  }
}