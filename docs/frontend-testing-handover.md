# 前端与测试联调交接文档（后端侧）

## 1. 文档目的

本文件用于前端与测试同学在联调阶段快速掌握后端能力、接口约定、环境准备、测试路径和常见问题处理方式，减少重复沟通成本，保证联调效率与验收一致性。

## 2. 当前可用服务与端口

- 后端服务（Spring Boot）：`8080`
- 算法服务（FastAPI）：`8000`
- 数据库（MySQL）：`3306`（仅后端内部访问）

建议联调时优先走后端统一网关（`8080`），不要让前端直接调算法服务。

## 3. 接口总览（前端/测试最常用）

### 3.1 获取推荐列表

- 路径：`GET /api/recommend/movie`
- 参数：
  - `userId`（必填，int）
  - `topN`（可选，int，默认 10）
- 示例：
  - `/api/recommend/movie?userId=1&topN=3`
- 返回示例：

```json
{
  "code": 0,
  "data": [
    {
      "movieId": 6,
      "title": null,
      "genres": null,
      "score": 5.66919,
      "reason": "基于相似用户偏好与矩阵分解隐语义特征生成"
    }
  ]
}
```

说明：当前若 `movies` 表未导入完整元数据，`title/genres` 可能为 `null`，不影响接口正确性。

### 3.2 提交评分

- 路径：`POST /api/rating/submit`
- Body(JSON)：

```json
{
  "userId": 1,
  "movieId": 10,
  "score": 4.5
}
```

- 返回示例：

```json
{
  "code": 0,
  "message": "ok"
}
```

说明：评分提交后会触发推荐结果刷新。

### 3.3 LLM 问答接口

- 路径：`POST /api/llm/query`
- Body(JSON)：

```json
{
  "userId": 1,
  "queryText": "推荐一部烧脑科幻片"
}
```

- 返回示例：

```json
{
  "code": 0,
  "responseText": "......",
  "relatedMovies": [
    {
      "movieId": 6,
      "title": null,
      "genres": null,
      "score": 5.66919,
      "reason": "基于相似用户偏好与矩阵分解隐语义特征生成"
    }
  ]
}
```

若 LLM 未配置成功或调用失败，`responseText` 会退化为默认文案，不影响接口可用性。

## 4. 前端接入约定

1. 使用统一 API Base URL：
   - 本地：`http://127.0.0.1:8080`
   - 服务器：`http://47.92.214.36:8080`（以实际部署域名/IP为准）
2. 业务成功条件统一按 `code === 0` 判断。
3. 对 `title/genres` 做空值兜底展示（如“未知影片”“未知类型”），防止页面报错。
4. LLM 展示建议：
   - 若 `responseText` 为默认失败文案，前端可展示为“AI解释暂不可用”，减少用户困惑。

## 5. 测试用例建议（可直接用于提测）

### 5.1 功能主链路

1. 调用推荐接口，返回 `code=0` 且 `data` 为数组。
2. 调用评分提交接口，返回 `code=0`。
3. 再调推荐接口，接口可正常返回且无 5xx。
4. 调用 LLM 问答接口，返回 `code=0` 且含 `responseText`。

### 5.2 异常与边界

1. `userId` 缺失：应返回 4xx（参数校验失败）。
2. 评分越界（如 `score=9`）：应返回 4xx。
3. LLM Key 无效时：接口仍返回 `code=0`，但 `responseText` 为降级提示。

### 5.3 稳定性

1. 连续调用推荐接口 20 次，不应出现服务崩溃。
2. 推荐与评分交替请求，不应出现明显阻塞。

## 6. 联调排查速查

1. `8080` 拒绝连接：后端未启动或已退出。
2. `8000` 拒绝连接：算法服务未启动。
3. 推荐接口 `title/genres` 为 `null`：元数据未入库。
4. LLM 默认失败文案：先查后端日志中的 `LLM` 关键字，确认状态码（如 401/429）。

## 7. 回归验收命令（服务器本机）

```bash
curl "http://127.0.0.1:8080/api/recommend/movie?userId=1&topN=3"
curl -X POST "http://127.0.0.1:8080/api/rating/submit" -H "Content-Type: application/json" -d '{"userId":1,"movieId":10,"score":4.5}'
curl -X POST "http://127.0.0.1:8080/api/llm/query" -H "Content-Type: application/json" -d '{"userId":1,"queryText":"推荐一部烧脑科幻片"}'
```

以上三条均返回 JSON 且不报连接错误，即可判定后端主功能可联调。
