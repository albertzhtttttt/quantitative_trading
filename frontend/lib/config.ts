const rawApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? '/api/v1'

// 统一去掉末尾斜杠，避免后续拼接 /auth/login 这类路径时出现双斜杠。
const apiBaseUrl = rawApiBaseUrl.endsWith('/') ? rawApiBaseUrl.slice(0, -1) : rawApiBaseUrl

// 统一维护前端公开配置，页面和 API Client 都从这里读取默认值，避免各处重复读取环境变量。
export const appConfig = {
  appName: process.env.NEXT_PUBLIC_APP_NAME ?? '量化交易控制台',
  apiBaseUrl,
}
