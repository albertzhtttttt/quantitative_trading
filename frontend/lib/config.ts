// 统一前端公开配置，后续页面和 API Client 都从这里读取默认值。
export const appConfig = {
  appName: process.env.NEXT_PUBLIC_APP_NAME ?? '量化交易控制台',
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL ?? '/api/v1',
}
