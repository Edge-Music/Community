export function cover(url?: string, size = 100) {
  return `${url}?param=${size}y${size}`
}

export function sample<T>(arr: Array<T>) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export function shuffle<T>(arr: T[], count: number = arr.length): T[] {
  const shuffled = [...arr].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}