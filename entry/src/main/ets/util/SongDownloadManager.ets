import { fileUri, picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ID, Song } from '../type/Adapter';
import { LogUtil, PreferencesUtil, ToastUtil } from '@pura/harmony-utils';
import { DownloadManager } from './DownloadUtils';
import { ContextHelper } from './ContextHelper';
import { getFileExtension } from './String';
import { PreferencesCache } from './PreferenceCache';
import { SourceAdapter } from '../adapter';

// 下载配置接口
interface DownloadConfig {
  prefix?: string;
  preferenceName?: string;
}

// 歌曲下载项
export interface SongDownloadItem {
  song: Song;
  path: string;
  downloadTime: number;
  lastPlayTime: number;
  size: number;
}

export interface  DownloadProgress {
  song: Song;
  progress: number;
}

// 下载队列项
interface DownloadQueueItem {
  song: Song;
  url: string;
}

// 默认配置
const DEFAULT_CONFIG: DownloadConfig = {
  prefix: 'download_',
  preferenceName: 'song_downloads'
};

/**
 * 歌曲下载管理器 - 单例模式
 * 用于管理歌曲的下载和持久化存储
 */
class SongDownloadManagerClass {
  private static instance: SongDownloadManagerClass = new SongDownloadManagerClass();
  private config: DownloadConfig = DEFAULT_CONFIG;
  private initialized: boolean = false;
  private documentViewPicker: picker.DocumentViewPicker | null = null;
  private baseUri: string = '';
  private downloadQueue: Map<ID, DownloadProgress> = new Map();

  private setQueue(songId: ID, progress: DownloadProgress): void {
    // 如果队列中已经存在该歌曲，则更新进度
    if (this.downloadQueue.has(songId)) {
      const existingItem = this.downloadQueue.get(songId);
      if (existingItem) {
        existingItem.progress = progress.progress;
      }
    } else {
      // 否则添加新的歌曲到队列
      this.downloadQueue.set(songId, progress);
    }
    AppStorage.setOrCreate('download_queue', this.downloadQueue);
  }

  private removeQueue(songId: ID): void {
    this.downloadQueue.delete(songId);
    AppStorage.setOrCreate('download_queue', this.downloadQueue);
  }

  private constructor() {
  }

  public static getInstance(): SongDownloadManagerClass {
    return SongDownloadManagerClass.instance;
  }

  // 初始化下载管理器
  public init(context: common.Context, config?: DownloadConfig): void {
    if (this.initialized) {
      LogUtil.warn('SongDownloadManager already initialized');
      return;
    }

    if (config) {
      this.config = this.mergeConfig(DEFAULT_CONFIG, config);
    }

    this.documentViewPicker = new picker.DocumentViewPicker(context);
    this.initialized = true;
  }

  // 手动实现配置合并
  private mergeConfig(defaultConfig: DownloadConfig, userConfig: DownloadConfig): DownloadConfig {
    const result: DownloadConfig = {
      prefix: userConfig.prefix !== undefined ? userConfig.prefix : defaultConfig.prefix,
      preferenceName: userConfig.preferenceName !== undefined ? userConfig.preferenceName : defaultConfig.preferenceName
    };
    return result;
  }

  private checkInitialized(): void {
    if (!this.initialized) {
      throw new Error('SongDownloadManager not initialized. Please call init() first.');
    }
  }

  /**
   * 初始化下载目录并获取基础URI
   * @returns Promise<string> 下载目录的URI
   */
  async initDownloadDirectory(): Promise<string> {
    this.checkInitialized();

    if (!this.documentViewPicker) {
      return '';
    }

    if (this.baseUri) {
      return this.baseUri;
    }

    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;

    try {
      const result = await this.documentViewPicker.save(documentSaveOptions);
      this.baseUri = result[0];
      return this.baseUri;
    } catch (err) {
      return '';
    }
  }

  private getFullKey(songId: string): string {
    return `${this.config.prefix}${songId}`;
  }

  /**
   * 下载并保存歌曲
   * @param songId 歌曲ID
   * @param url 歌曲下载URL
   * @param fileName 文件名（完整文件名，包括扩展名）
   * @param song 歌曲数据
   * @param onProgress 进度回调函数
   * @param onComplete 完成回调函数
   * @returns Promise<boolean> 是否下载成功
   */
  public async downloadSong(
    songId: ID,
    song: Song,
    onProgress?: (progress: number) => void,
    onComplete?: () => void,
    background = false
  ): Promise<boolean> {
    this.checkInitialized();

    try {
      // 确保下载目录已初始化
      if (!this.baseUri) {
        await this.initDownloadDirectory();
        if (!this.baseUri) {
          return false;
        }
      }

      LogUtil.info('SongDownloadManager ', 'Base URI: ', this.baseUri);

      // 创建音乐目录
      const musicDir = await this.createDirectory('Music');
      const cacheDir = ContextHelper.getContext()?.cacheDir;
      if (!cacheDir) {
        return false;
      }
      LogUtil.info('SongDownloadManager ', 'Music Directory: ', musicDir);
      if (!musicDir) {
        return false;
      }

      // 获取歌曲下载URL
      const br = PreferencesCache.downloadLevel()
      const downloadSong = await SourceAdapter.getSongDetail(song, br)
      const url = downloadSong?.meta?.url || '';
      if (!url) {
        ToastUtil.showShort($r('app.string.no_download_link_found'))
        return false;
      }

      const ext = getFileExtension(url)
      const fileName = `${song.name}-${song.artists.map(item => item.name).join("、")}${ext}`

      // 完整文件路径
      const uri = musicDir + '/' + fileName;
      const filePath = new fileUri.FileUri(uri).path;
      const tempFilePath = cacheDir + '/' + fileName;

      LogUtil.info('SongDownloadManager ', 'Downloading song: ', tempFilePath, ' from URL: ', url);

      // 先删除临时文件
      try {
        await fs.unlink(tempFilePath);
      } catch (e) {
        // 忽略删除文件错误
      }

      // 使用下载工具类下载文件
      this.setQueue(songId, {
        song: song,
        progress: 0
      });

      await DownloadManager.downloadFile({
        url: url,
        fileName: tempFilePath,
        background: background,
        onProgress: (progress) => {
          // 调用进度回调
          if (onProgress) {
            onProgress(progress);
          }
          // 触发进度回调
          this.setQueue(songId, {
            song: song,
            progress: progress
          });
        },
        onComplete: async () => {
          try {
            // 移动文件到目标目录
            await fs.moveFile(tempFilePath, filePath);
            const lyricContent = song.meta?.lyric?.normal;
            if (lyricContent) {
              const lyricFilePath = filePath.replace(/\.[^/.]+$/, '.lrc');
              // 创建歌词文件
              LogUtil.info('SongDownloadManager ', 'Creating lyric file: ', lyricFilePath);
              const lyric = await fs.open(lyricFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
              await fs.write(lyric.fd, lyricContent);
            }
            LogUtil.info('SongDownloadManager ', 'File moved to: ', filePath);
            // 调用完成回调
            if (onComplete) {
              onComplete();
            }
            // 触发完成回调
            this.removeQueue(songId);
          } catch (error) {
            LogUtil.error('SongDownloadManager ', 'Error moving file: ', error.message);
            if (onComplete) {
              onComplete();
            }
            // 触发完成回调
            this.removeQueue(songId);
          }
        },
        onError: () => {
          LogUtil.error('SongDownloadManager ', 'Error downloading song: ', fileName);
          if (onComplete) {
            onComplete();
          }
          // 触发完成回调
          this.removeQueue(songId);
        }
      });

      // 创建下载项
      const downloadItem: SongDownloadItem = {
        song,
        path: filePath,
        downloadTime: Date.now(),
        lastPlayTime: Date.now(),
        size: song.meta?.size || 0
      };

      // 保存到偏好设置
      await PreferencesUtil.put(
        this.getFullKey(songId.toString()),
        JSON.stringify(downloadItem),
        this.config.preferenceName
      );

      return true;
    } catch (error) {
      LogUtil.error('SongDownloadManager ', 'Error downloading song: ', error.message);
      return false;
    }
  }

  /**
   * 创建目录
   * @param dirName 目录名称
   * @returns Promise<string> 创建的目录URI
   */
  private async createDirectory(dirName: string): Promise<string> {
    try {
      if (!this.baseUri) {
        await this.initDownloadDirectory();
      }

      const dirPath = new fileUri.FileUri(this.baseUri + '/' + dirName).path;
      // try {
      //   fs.mkdirSync(dirPath);
      // } catch (err) {
      //   // 如果目录已存在，则忽略错误 (17是目录已存在的错误码)
      //   if (err.code !== 17) {
      //     return '';
      //   }
      // }

      // 首先判断目录是否存在
      // try {
      //   fs.accessSync(dirPath);
      // } catch (err) {
      //   // 如果目录不存在，则创建目录
      //   fs.mkdirSync(dirPath);
      // }
      if (!fs.accessSync(dirPath)) {
        fs.mkdirSync(dirPath);
      }

      return this.baseUri + '/' + dirName;
    } catch (err) {
      return '';
    }
  }

  /**
   * 从下载目录获取歌曲
   * @param songId 歌曲ID
   * @returns SongDownloadItem | null 歌曲下载项或null
   */
  public getSong(songId: string): SongDownloadItem | null {
    this.checkInitialized();

    try {
      const fullKey = this.getFullKey(songId);
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);

      if (!data) {
        return null;
      }

      const downloadItem: SongDownloadItem = JSON.parse(data);

      // 检查文件是否存在
      try {
        fs.accessSync(downloadItem.path);
      } catch (err) {
        // 文件不存在，删除记录
        this.removeSong(songId);
        return null;
      }

      return downloadItem;
    } catch (error) {
      return null;
    }
  }

  /**
   * 更新歌曲的最后播放时间
   * @param songId 歌曲ID
   */
  public updateLastPlayTime(songId: string): void {
    this.checkInitialized();

    try {
      const fullKey = this.getFullKey(songId);
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);

      if (!data) {
        return;
      }

      const downloadItem: SongDownloadItem = JSON.parse(data);
      downloadItem.lastPlayTime = Date.now();

      PreferencesUtil.put(fullKey, JSON.stringify(downloadItem), this.config.preferenceName);
    } catch (error) {
      // 忽略错误
    }
  }

  /**
   * 检查歌曲是否已下载
   * @param songId 歌曲ID
   * @returns boolean 是否已下载
   */
  public hasSong(songId: string): boolean {
    this.checkInitialized();

    const fullKey = this.getFullKey(songId);
    if (!PreferencesUtil.hasSync(fullKey, this.config.preferenceName)) {
      return false;
    }

    // 进一步检查文件是否存在
    try {
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);
      if (!data) {
        return false;
      }

      const downloadItem: SongDownloadItem = JSON.parse(data);
      fs.accessSync(downloadItem.path);
      return true;
    } catch (error) {
      // 文件不存在，删除记录
      this.removeSong(songId);
      return false;
    }
  }

  /**
   * 删除下载的歌曲
   * @param songId 歌曲ID
   * @returns Promise<boolean> 是否删除成功
   */
  public async removeSong(songId: string): Promise<boolean> {
    this.checkInitialized();

    try {
      const fullKey = this.getFullKey(songId);
      // 获取下载项以便删除文件
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);
      if (data) {
        const downloadItem: SongDownloadItem = JSON.parse(data);
        // 删除文件
        try {
          await fs.unlink(downloadItem.path);
        } catch (e) {
          // 忽略删除文件错误
        }
      }

      // 删除偏好设置中的条目
      await PreferencesUtil.delete(fullKey, this.config.preferenceName);
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 获取下载数量
   * @returns number 下载数量
   */
  public getDownloadCount(): number {
    this.checkInitialized();

    const allData = PreferencesUtil.getAllSync(this.config.preferenceName);
    if (!allData) {
      return 0;
    }

    return Object.keys(allData).filter(key =>
    key.startsWith(this.config.prefix || DEFAULT_CONFIG.prefix || '')
    ).length;
  }

  /**
   * 获取所有下载的歌曲
   * @returns SongDownloadItem[] 下载的歌曲列表
   */
  public getAllDownloads(): SongDownloadItem[] {
    this.checkInitialized();

    const result: SongDownloadItem[] = [];
    const allData = PreferencesUtil.getAllSync(this.config.preferenceName);
    if (!allData) {
      return result;
    }

    const keys = Object.keys(allData).filter(key =>
    key.startsWith(this.config.prefix || DEFAULT_CONFIG.prefix || '')
    );

    for (const key of keys) {
      try {
        const downloadItem: SongDownloadItem = JSON.parse(allData[key]);
        // 检查文件是否存在
        try {
          fs.accessSync(downloadItem.path);
          result.push(downloadItem);
        } catch (err) {
          // 文件不存在，删除记录
          const songId = key.replace(this.config.prefix || '', '');
          this.removeSong(songId);
        }
      } catch (error) {
        // 忽略解析错误
      }
    }

    return result;
  }

  /**
   * 计算所有下载的总大小
   * @returns number 下载的总大小（字节）
   */
  public getTotalSize(): number {
    this.checkInitialized();

    let totalSize = 0;
    const downloads = this.getAllDownloads();

    for (const item of downloads) {
      totalSize += item.size;
    }

    return totalSize;
  }

  /**
   * 清除所有下载
   * @returns Promise<boolean> 是否清除成功
   */
  public async clearAllDownloads(): Promise<boolean> {
    this.checkInitialized();

    try {
      const allData = PreferencesUtil.getAllSync(this.config.preferenceName);
      if (!allData) {
        return true;
      }

      const keys = Object.keys(allData).filter(key =>
      key.startsWith(this.config.prefix || DEFAULT_CONFIG.prefix || '')
      );

      for (const key of keys) {
        try {
          const downloadItem: SongDownloadItem = JSON.parse(allData[key]);
          // 删除文件
          await fs.unlink(downloadItem.path);
        } catch (error) {
          // 忽略删除文件错误
        }

        // 删除偏好设置中的条目
        await PreferencesUtil.delete(key, this.config.preferenceName);
      }

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 获取当前下载目录URI
   * @returns string 下载目录URI
   */
  public getBaseUri(): string {
    return this.baseUri;
  }

  /**
   * 批量下载歌曲
   * @param songs 歌曲列表
   * @returns Promise<boolean> 是否成功开始下载
   */
  public async batchDownloadSongs(
    songs: Song[]
  ): Promise<boolean> {
    this.checkInitialized();

    // 先创建下载队列
    for (const song of songs) {
      const songId = song.id.toString();
      this.setQueue(songId, {
        song: song,
        progress: 0
      });
    }

    // 按顺序下载
    for (const song of songs) {
      const songId = song.id.toString();
      try {
        await this.downloadSong(
          songId,
          song,
          undefined,
          undefined,
          true
        );
      } catch (error) {
        LogUtil.error('SongDownloadManager', `Error downloading song ${song.name}:`, error.message);
        // 下载失败时从队列中移除
        this.removeQueue(songId);
        continue;
      }
    }

    return true;
  }
}

// 导出单例实例
export const SongDownloadManager = SongDownloadManagerClass.getInstance();