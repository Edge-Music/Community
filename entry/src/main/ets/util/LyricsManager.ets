import { Song } from "../type/Adapter";
import { avPlayerManager } from "./AVPlayerManager";
import { resourceManager } from "@kit.LocalizationKit";
import { ResourceManager } from "./ResourceManager";

export class LyricsLine {
  time: number; // 时间点（毫秒）
  text: string; // 原文歌词
  translation?: string; // 翻译/音译
  showTranslation?: boolean; // 是否显示翻译

  constructor(time: number, text: string, translation?: string, showTranslation?: boolean) {
    this.time = time;
    this.text = text;
    this.translation = translation;
    this.showTranslation = showTranslation;
  }
}

class LyricsManager {
  private song: Song | undefined
  private originalLyrics: string = ''
  private translatedLyrics: string = ''
  private hasTranslation: boolean = false
  private currentTimeMs: number = 0
  private parsedLyrics: Array<LyricsLine> = []
  private lyricsTimer: number = 0
  private currentIndex: number = 0
  private readonly PRE_HIGHLIGHT_TIME: number = 500 // 提前切换时间

  async init(){
    this.song = AppStorage.get<Song>('current_playing_song')
    this.originalLyrics = this.song?.meta?.lyric?.normal ?? ''
    this.translatedLyrics = (this.song?.meta?.lyric?.translation || this.song?.meta?.lyric?.transliteration) ?? ''
    this.parseLyrics()
    this.setLyricsInterval()
  }

  async reset(){
    this.clearLyricsInterval()
    this.song = undefined
    this.originalLyrics = ''
    this.translatedLyrics = ''
    this.lyricsTimer = 0
    this.currentTimeMs = 0
    this.parsedLyrics = []
    this.currentIndex = 0
  }

  async setLyricsInterval(){
    const player = await avPlayerManager.getAVPlayerInstance()
    this.currentTimeMs = player.currentTime

    if(this.lyricsTimer === 0){
      this.lyricsTimer = setInterval(() => {
        this.currentTimeMs = player.currentTime
        this.updateCurrentLyric()
        AppStorage.setOrCreate<LyricsLine>('current_line_lyrics', this.parsedLyrics[this.currentIndex])
        AppStorage.setOrCreate<number>('current_lyrics_index', this.currentIndex)
      }, 500)
      console.info(`歌词定时器[${this.lyricsTimer}]设置完成`)
    }
  }

  clearLyricsInterval(){
    const tmpTimer = this.lyricsTimer
    clearInterval(this.lyricsTimer)
    console.info(`歌词定时器[${tmpTimer}]清除完成`)
  }

  /**
   * 解析LRC格式原文歌词
   */
  private async parseLyrics() {
    console.info(`开始解析[${this.song?.name}]歌词`)
    // 重置状态
    this.currentIndex = 0

    if (this.originalLyrics.trim() === '') {
      this.parsedLyrics = []
      this.hasTranslation = false
      return
    }

    // 首先解析原始歌词
    const originalLines = this.parseLyricsText(this.originalLyrics)

    // 检查是否有翻译歌词
    if (this.translatedLyrics && this.translatedLyrics.trim() !== '') {
      this.hasTranslation = true
      const translationLines = this.parseLyricsText(this.translatedLyrics)

      // 合并原始歌词和翻译歌词
      this.parsedLyrics = this.mergeLyrics(originalLines, translationLines)
    } else {
      this.hasTranslation = false
      this.parsedLyrics = originalLines
    }
    AppStorage.setOrCreate<boolean>('current_lyrics_has_translation', this.hasTranslation)
    AppStorage.setOrCreate<Array<LyricsLine>>('current_parsed_lyrics', this.parsedLyrics)
    console.info(`完成解析[${this.song?.name}]歌词`)
  }

  /**
   * 解析单个LRC文本
   * @param lrcText - LRC格式文本字符串
   * @returns LyricsLine[] - 包含时间戳和对应歌词的数组，按时间戳升序排序
   */
  private parseLyricsText(lrcText: string): LyricsLine[] {
    const lines = lrcText.split('\n')
    const timeRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/
    const tempLyrics: LyricsLine[] = []

    lines.forEach(line => {
      const match = timeRegex.exec(line)
      if (match) {
        const minutes = parseInt(match[1])
        const seconds = parseInt(match[2])
        const ms = parseInt(match[3])
        // 统一转换为毫秒
        const time = minutes * 60 * 1000 + seconds * 1000 + (ms < 100 ? ms * 10 : ms)
        const text = line.replace(timeRegex, '').trim()

        if (text) {
          tempLyrics.push(new LyricsLine(time, text))
        }
      }
    })

    // 按时间排序
    return tempLyrics.sort((a, b) => a.time - b.time)
  }

  /**
   * 合并原始歌词和翻译歌词，为原始歌词添加对应的翻译
   * @param originalLyrics - 原始歌词行数组
   * @param translationLyrics - 翻译歌词行数组
   * @returns LyricsLine[] - 合并后的歌词行数组，其中原始歌词行包含了对应的翻译文本
   */
  private mergeLyrics(originalLyrics: LyricsLine[], translationLyrics: LyricsLine[]): LyricsLine[] {
    // 创建结果数组，深拷贝原始歌词避免引用问题
    const mergedLyrics: LyricsLine[] = JSON.parse(JSON.stringify(originalLyrics))

    // 为每一行原始歌词寻找最接近的翻译行
    mergedLyrics.forEach((line, _index) => {
      // 寻找时间最接近的翻译
      let closestTranslation: LyricsLine | null = null
      let minTimeDiff = Number.MAX_VALUE

      translationLyrics.forEach(transLine => {
        const timeDiff = Math.abs(transLine.time - line.time)
        // 如果找到时间差更小的翻译行
        if (timeDiff < minTimeDiff) {
          minTimeDiff = timeDiff
          closestTranslation = transLine
        }
      })

      // 如果找到匹配的翻译，且时间差在合理范围内（例如50毫秒）
      if (closestTranslation !== null && minTimeDiff <= 50) {
        line.translation = (closestTranslation as LyricsLine).text
      }
    })

    return mergedLyrics
  }

  private updateCurrentLyric() {
    // 添加预判时间提前高亮
    const adjustedTime = this.currentTimeMs + this.PRE_HIGHLIGHT_TIME

    // 查找当前应显示的歌词
    let newIndex = -1
    for (let i = 0; i < this.parsedLyrics.length; i++) {
      if (i === this.parsedLyrics.length - 1) {
        // 最后一句
        if (adjustedTime >= this.parsedLyrics[i].time) {
          newIndex = i
          this.currentIndex = newIndex
        }
      } else {
        // 非最后一句，检查是否在当前时间范围内
        if (adjustedTime >= this.parsedLyrics[i].time && adjustedTime < this.parsedLyrics[i + 1].time) {
          newIndex = i
          this.currentIndex = newIndex
          break
        }
      }
    }
  }

}

export default new LyricsManager()