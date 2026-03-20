const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? '/api/v1'

// 统一封装 GET 请求，后续可在这里扩展鉴权、错误映射和请求日志。
export async function apiGet<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
    cache: 'no-store',
  })

  if (!response.ok) {
    throw new Error(`API 请求失败: ${response.status}`)
  }

  return response.json() as Promise<T>
}
