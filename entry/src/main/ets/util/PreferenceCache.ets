import { ID, Song, SourceConfig } from "../type/Adapter";
import { PreferencesUtil } from '@pura/harmony-utils';
import { ResourceManager } from "./ResourceManager";

// 比特率类型
export type BitrateType = 128000 | 192000 | 320000 | 350000 | 999000;

export interface QualityLevel {
  level: string;
  description: string | Resource
  bitrate: BitrateType;
}

export const qualityLevels: QualityLevel[] = [
  { level: 'standard', description: $r('app.string.quality_standard'), bitrate: 128000 },
  { level: 'higher', description: $r('app.string.quality_higher'), bitrate: 192000 },
  { level: 'exhigh', description: $r('app.string.quality_ex_high'), bitrate: 320000 },
  { level: 'lossless', description: $r('app.string.quality_lossless'), bitrate: 350000 },
  { level: 'hires', description: $r('app.string.quality_hires'), bitrate: 999000 }
];

/**
 * 根据比特率获取音质等级
 * @param bitrate 比特率
 */
export function getQualityLevel(bitrate: BitrateType): QualityLevel {
  return qualityLevels.find(item => item.bitrate === bitrate) as QualityLevel;
}

/**
 * 系统设置偏好
 */
export class PreferencesCache {
  private static CACHE_MAP = new Map<string, string>();

  /**
   * 设置缓存
   */
  static setCache(key: string, value: string): void {
    PreferencesUtil.putSync(key, value);
    PreferencesCache.CACHE_MAP.set(key, value);
  }

  /**
   * 获取缓存
   */
  static getCache(key: string, defaultValue?: string): string {
    if (PreferencesCache.CACHE_MAP.has(key)) {
      return PreferencesCache.CACHE_MAP.get(key) as string;
    }
    const value = PreferencesUtil.getStringSync(key, defaultValue);
    PreferencesCache.CACHE_MAP.set(key, value);
    return value;
  }


  /**
   * 获取用户数据源
   */
  static getUserDataSource(): SourceConfig[] {
    const sourceConfig = PreferencesCache.getCache('user_data_source', '[]');
    return JSON.parse(sourceConfig);
  }

  /**
   * 设置用户数据源
   */
  static setUserDataSource(sourceConfig: SourceConfig[]): void {
    PreferencesCache.setCache('user_data_source', JSON.stringify(sourceConfig));
    AppStorage.set('user_data_source', sourceConfig);
  }

  /**
   * 添加用户数据源
   */
  static addUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getUserDataSource();
    sourceList.push(sourceConfig);
    PreferencesCache.setUserDataSource(sourceList);
  }

  /**
   * 更新指定用户数据源
   */
  static updateUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceConfig.id);
    if (index !== -1) {
      sourceList[index] = sourceConfig;
      PreferencesCache.setUserDataSource(sourceList);
    }
  }

  /**
   * 删除指定用户数据源
   */
  static deleteUserDataSource(sourceId: ID): void {
    const sourceList = PreferencesCache.getUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceId);
    if (index !== -1) {
      sourceList.splice(index, 1);
      PreferencesCache.setUserDataSource(sourceList);
    }
  }

  /**
   * 获取展示用户数据源
   */
  static getShowUserDataSource(): SourceConfig[] {
    const sourceConfig = PreferencesCache.getCache('show_user_data_source', '[]');
    return JSON.parse(sourceConfig);
  }

  /**
   * 设置展示用户数据源
   */
  static setShowUserDataSource(sourceConfig: SourceConfig[]): void {
    PreferencesCache.setCache('show_user_data_source', JSON.stringify(sourceConfig));
    AppStorage.set('show_user_data_source', sourceConfig);
  }

  /**
   * 添加展示用户数据源
   */
  static addShowUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getShowUserDataSource();
    sourceList.push(sourceConfig);
    PreferencesCache.setShowUserDataSource(sourceList);
  }

  /**
   * 更新展示指定用户数据源
   */
  static updateShowUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getShowUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceConfig.id);
    if (index !== -1) {
      sourceList[index] = sourceConfig;
      PreferencesCache.setShowUserDataSource(sourceList);
    }
  }

  /**
   * 删除展示指定用户数据源
   */
  static deleteShowUserDataSource(sourceId: ID): void {
    const sourceList = PreferencesCache.getShowUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceId);
    if (index !== -1) {
      sourceList.splice(index, 1);
      PreferencesCache.setShowUserDataSource(sourceList);
    }
  }

  /**
   * 获取用户偏好
   * @param key 偏好键
   * @param defaultValue 默认值
   */
  static getUserPreference(key: string, defaultValue?: string): string {
    key = 'user_preference_' + key;
    return PreferencesCache.getCache(key, defaultValue);
  }

  /**
   * 设置用户偏好
   * @param key 偏好键
   * @param value 偏好值
   */
  static setUserPreference(key: string, value: string): void {
    key = 'user_preference_' + key;
    PreferencesCache.setCache(key, value);
  }

  /**
   * 用户偏好 - 中断后继续
   * @param value 是否中断后继续（若不传值则获取当前设置）
   * @returns 是否中断后继续
   */
  static interruptingContinue(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('interrupting_continue', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('interrupting_continue') === '1';
  }

  /**
   * 用户偏好 - 播放歌词
   * @param value 是否播放歌词（若不传值则获取当前设置）
   * @returns 是否播放歌词
   */
  static playerLyric(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('player_lyric', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('player_lyric') === '1';
  }

  /**
   * 用户偏好 - 播放音质
   * @param value 音质（若不传值则获取当前设置）
   * @returns 音质
   */
  static playingLevel(value?: BitrateType): BitrateType {
    if (value) {
      PreferencesCache.setUserPreference('playing_level', value.toString());
    }
    return parseInt(PreferencesCache.getUserPreference('playing_level') || '128000') as BitrateType;
  }

  /**
   * 用户偏好 - 下载音质
   * @param value 音质（若不传值则获取当前设置）
   * @returns 音质
   */
  static downloadLevel(value?: BitrateType): BitrateType {
    if (value) {
      PreferencesCache.setUserPreference('download_level', value.toString());
    }
    return parseInt(PreferencesCache.getUserPreference('download_level') || '999000') as BitrateType;
  }

  /**
   * 用户偏好 - 播放缓存
   * @param value 缓存大小（若不传值则获取当前设置）
   * @returns 缓存大小
   */
  static playingCache(value?: number): number {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('playing_cache', value.toString());
    }

    const storedValue = PreferencesCache.getUserPreference('playing_cache');
    return storedValue !== undefined && storedValue !== null && storedValue !== ''
      ? parseInt(storedValue)
      : 100;
  }

  /**
   * 用户偏好 - 请求缓存过期时间
   * @param value 过期时间（若不传值则获取当前设置）
   * @returns 过期时间
   */
  static requestCacheExpire(value?: number): number {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('request_cache_expire', value.toString());
    }

    const storedValue = PreferencesCache.getUserPreference('request_cache_expire');
    return storedValue !== undefined && storedValue !== null && storedValue !== ''
      ? parseInt(storedValue)
      : 7;
  }

  /**
   * 歌单持久化 - 存储
   * @param songs
   */
  static playlist(songs?: Song[]): Song[] {
    if (songs) {
      PreferencesCache.setCache('playlist', JSON.stringify(songs));
    }
    return JSON.parse(PreferencesCache.getCache('playlist', '[]'));
  }

  /**
   * 上一次播放的歌曲
   * @param songs
   */
  static lastSong(song?: Song): Song | null {
    if (song) {
      PreferencesCache.setCache('last_song', JSON.stringify(song));
    }
    return JSON.parse(PreferencesCache.getCache('last_song', 'null'));
  }

  /**
   * 播放模式
   * @param value 播放模式（若不传值则获取当前设置）
   */
  static playMode(value?: number): number {
    if (value !== undefined) {
      // 将 value 转换为字符串存储
      PreferencesCache.setUserPreference('play_mode', value.toString());
    }
    const storedValue = PreferencesCache.getUserPreference('play_mode', '0'); // 默认值为 0
    // 尝试将存储的值转换为数字
    const parsedValue = parseInt(storedValue, 10);
    // 如果转换失败，返回默认值 0
    if (isNaN(parsedValue)) {
      return 0; // 默认值
    }
    return parsedValue; // 返回解析后的值
  }

  /**
   * 播放页面 封面-歌词布局翻转
   * @param value 是否翻转
   * @returns 是否翻转
   */
  static flipCoverLyric(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('flip_cover_lyric', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('flip_cover_lyric') === '1';
  }

  /**
   * 显示翻译/音译歌词
   * @param value 是否显示
   * @returns 是否显示
   */
  static showTranslationLyric(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('show_translation_lyric', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('show_translation_lyric') === '1';
  }
}