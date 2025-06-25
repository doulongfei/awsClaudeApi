# AWS Claude API Proxy Service

## 项目简介

本项目是一个基于 Flask 的 Web 服务，提供 OpenAI API 兼容接口，底层通过 AWS Bedrock 调用 Claude 系列模型。适用于希望用 Claude 替换 OpenAI API 的场景，无需更改客户端代码即可无缝切换。

## 主要特性

- 支持 Claude 3.7 Sonnet、Claude 3 Opus、Claude 3 Sonnet、Claude 3 Haiku 等多种模型
- 完全兼容 OpenAI API（/v1/completions 和 /v1/chat/completions）
- 支持 Claude 的思考模式（Thinking Mode）
- 自动参数校验与调整，满足 AWS Bedrock 要求
- 内置重试机制，自动处理 API 限流与异常
- 日志轮转与详细日志输出
- 支持流式输出

## 安装与依赖

### 系统要求

- Python 3.8 及以上
- 已配置 AWS 账号并开通 Bedrock 服务

### Python 依赖

```bash
pip install flask boto3 tiktoken
```
或
```bash
pip install -r requirements.txt
```

## 配置

### 环境变量

- `DEBUG_MODE`：设为 `true` 启用详细日志（默认 `false`）

### AWS 凭证

请确保已通过如下任一方式配置 AWS 访问权限：

- `aws configure` 命令配置
- 环境变量 `AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY`
- EC2 实例绑定 IAM 角色

## 启动服务

```bash
python aws-claude.py
```

默认监听 0.0.0.0:5000。

## API 用法示例

### 聊天补全（/v1/chat/completions）

```bash
curl -X POST http://localhost:5000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-7-sonnet",
    "messages": [
      {"role": "user", "content": "你好 Claude！"}
    ],
    "max_tokens": 1000
  }'
```

### 文本补全（/v1/completions）

```bash
curl -X POST http://localhost:5000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-7-sonnet",
    "prompt": "写一首关于云的诗",
    "max_tokens": 200
  }'
```

### 思考模式示例

```bash
curl -X POST http://localhost:5000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-7-sonnet-thinking",
    "messages": [
      {"role": "user", "content": "997 的平方根是多少？"}
    ],
    "max_tokens": 2000
  }'
```

## 日志管理

- 日志文件路径：`logs/claude_service.log`
- 单文件最大 20MB，最多保留 5 个文件（总计 100MB）
- 可用 `tail -f logs/claude_service.log` 实时查看日志

## 常见问题

- 若无日志文件，请检查运行用户对 logs 目录的写权限
- 若 API 无法访问，请检查防火墙、端口监听、AWS 凭证等

## 生产部署建议

- 推荐使用 systemd 管理服务进程
- 建议配合 Nginx 等反向代理并启用 HTTPS

## 许可证

本项目采用 Apache License 2.0，详见 LICENSE 文件。

---

本项目基于 [forgottener/openai-bedrock-claude](https://github.com/forgottener/openai-bedrock-claude) 项目修改和扩展。

