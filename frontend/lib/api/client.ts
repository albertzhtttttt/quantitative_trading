import { appConfig } from '@/lib/config'

type ApiMethod = 'GET' | 'POST'

type ApiRequestOptions = Omit<RequestInit, 'method' | 'body'> & {
  method?: ApiMethod
  body?: unknown
}

type ValidationErrorItem = {
  msg?: string
}

type ApiErrorPayload = {
  detail?: string | ValidationErrorItem[]
  message?: string
}

// 统一暴露带状态码的错误对象，页面可以基于 status 区分未登录和普通请求失败。
export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

// 统一封装请求入口：默认关闭缓存，并始终携带 credentials，让 HttpOnly Cookie 自动随请求往返。
export async function apiRequest<T>(path: string, options: ApiRequestOptions = {}): Promise<T> {
  const { method = 'GET', body, headers, ...init } = options
  const requestHeaders = new Headers(headers)
  const hasJsonBody = body !== undefined

  if (hasJsonBody && !requestHeaders.has('Content-Type')) {
    requestHeaders.set('Content-Type', 'application/json')
  }

  const response = await fetch(buildApiUrl(path), {
    ...init,
    method,
    headers: requestHeaders,
    body: hasJsonBody ? JSON.stringify(body) : undefined,
    cache: init.cache ?? 'no-store',
    credentials: init.credentials ?? 'include',
  })

  return parseResponse<T>(response)
}

// 对 GET 请求保留轻量封装，调用方只需要关心 endpoint 和返回类型。
export function apiGet<T>(path: string, init?: Omit<ApiRequestOptions, 'method' | 'body'>): Promise<T> {
  return apiRequest<T>(path, { ...init, method: 'GET' })
}

// 对 POST 请求统一走 JSON body，避免页面层重复设置 headers 和序列化逻辑。
export function apiPost<T>(path: string, body?: unknown, init?: Omit<ApiRequestOptions, 'method' | 'body'>): Promise<T> {
  return apiRequest<T>(path, { ...init, method: 'POST', body })
}

// 成功响应优先按 JSON 解析；若后端返回空内容或纯文本，也保持最小兼容。
async function parseResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    throw new ApiError(await readErrorMessage(response), response.status)
  }

  if (response.status === 204) {
    return undefined as T
  }

  const contentType = response.headers.get('content-type') ?? ''
  if (contentType.includes('application/json')) {
    return response.json() as Promise<T>
  }

  return (await response.text()) as T
}

// 统一读取 FastAPI 的 detail / message 字段，让页面能直接展示后端返回的失败原因。
async function readErrorMessage(response: Response): Promise<string> {
  const contentType = response.headers.get('content-type') ?? ''

  if (contentType.includes('application/json')) {
    try {
      const payload = (await response.clone().json()) as ApiErrorPayload
      const detailMessage = formatErrorDetail(payload.detail)

      if (detailMessage) {
        return detailMessage
      }
      if (typeof payload.message === 'string' && payload.message.trim()) {
        return payload.message.trim()
      }
    } catch {
      // JSON 解析失败时退回文本兜底，避免把解析异常直接暴露给页面。
    }
  }

  const fallbackText = await response.text()
  return fallbackText || `API 请求失败: ${response.status}`
}

// FastAPI 校验错误可能是字符串，也可能是数组；这里统一折叠成适合页面展示的一行文案。
function formatErrorDetail(detail: ApiErrorPayload['detail']): string | null {
  if (typeof detail === 'string' && detail.trim()) {
    return detail.trim()
  }

  if (Array.isArray(detail)) {
    const messages = detail
      .map((item) => (typeof item?.msg === 'string' && item.msg.trim() ? item.msg.trim() : null))
      .filter((item): item is string => item !== null)

    if (messages.length > 0) {
      return messages.join('；')
    }
  }

  return null
}

// 统一处理 base URL 与 endpoint 的拼接，兼容环境变量是否携带前导斜杠。
function buildApiUrl(path: string): string {
  return `${appConfig.apiBaseUrl}${path.startsWith('/') ? path : `/${path}`}`
}
