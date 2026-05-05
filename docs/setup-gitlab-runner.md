# GitLab Runner 安装与配置指南

> 本文档说明如何为 llm_agent 项目安装、注册和配置 GitLab Runner。

## 1. 安装 GitLab Runner (Linux)

### Debian/Ubuntu

```bash
# 添加 GitLab 官方 GPG key
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash

# 安装
sudo apt-get update
sudo apt-get install -y gitlab-runner

# 验证版本
gitlab-runner --version
```

### RHEL/CentOS/Fedora

```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo yum install -y gitlab-runner
gitlab-runner --version
```

### Docker 方式 (可选)

```bash
docker run -d \
  --name gitlab-runner \
  --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

## 2. Runner 注册

### 获取 Registration Token

在 GitLab 项目页面: Settings → CI/CD → Runners → 复制 registration token。

### 注册命令

```bash
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com/" \
  --registration-token "YOUR_TOKEN" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "llm-agent-runner" \
  --tag-list "shell,docker" \
  --run-untagged="true" \
  --locked="false"
```

### 交互式注册 (适合首次设置)

```bash
sudo gitlab-runner register
```

按提示依次输入:

| 提示                              | 推荐值                            |
| --------------------------------- | --------------------------------- |
| GitLab instance URL               | `https://gitlab.example.com/`     |
| Registration token                | 从项目 CI/CD 设置页面获取         |
| Runner description                | `llm-agent-runner`                |
| Tags                              | `shell,docker`                    |
| Executor                          | `docker`                          |
| Default Docker image              | `alpine:latest`                   |

### 验证注册

```bash
sudo gitlab-runner list
sudo gitlab-runner verify
```

## 3. 配置建议

Runner 配置文件位于 `/etc/gitlab-runner/config.toml`。

### 推荐配置

```toml
concurrent = 4          # 最大并行 Job 数，建议 2~4
check_interval = 3      # 轮询 GitLab 间隔(秒)
shutdown_timeout = 0    # 关机超时

[[runners]]
  name = "llm-agent-runner"
  url = "https://gitlab.example.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "docker"

  [runners.docker]
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
    # 限制资源使用
    cpus = "2"
    memory = "2g"
    # DNS 配置 (内网 GitLab 可能需要)
    dns = ["8.8.8.8", "114.114.114.114"]

  [runners.cache]
    Type = "local"
    Path = "/var/cache/gitlab-runner"
    Shared = true
```

### Shell Executor 配置 (如果需要直接在宿主机执行)

```toml
[[runners]]
  name = "llm-agent-shell-runner"
  url = "https://gitlab.example.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "shell"

  [runners.cache]
    Type = "local"
    Path = "/var/cache/gitlab-runner"
```

### 关键参数说明

| 参数             | 说明                              | 推荐值         |
| ---------------- | --------------------------------- | -------------- |
| `concurrent`     | 并行执行的 Job 数量               | 2~4            |
| `check_interval` | Runner 轮询 GitLab 的间隔         | 3              |
| `executor`       | Job 执行方式                      | docker         |
| `image`          | Docker 默认镜像                   | alpine:latest  |
| `cpus`           | Docker 容器 CPU 限制              | 2              |
| `memory`         | Docker 容器内存限制               | 2g             |

## 4. 常见问题排查

### Q1: Runner 状态显示 "not connected"

```bash
# 检查 Runner 服务状态
sudo gitlab-runner status
sudo systemctl status gitlab-runner

# 检查网络连通性
curl -I https://gitlab.example.com/

# 查看 Runner 日志
sudo journalctl -u gitlab-runner -f
```

### Q2: Job 一直 pending 不执行

- 检查 Runner 是否在线: `sudo gitlab-runner verify`
- 检查 tags 是否匹配: 项目 .gitlab-ci.yml 的 tags 需要和 Runner 注册时的 tags 一致
- 检查 Runner 是否被锁定到其他项目

### Q3: Docker executor 拉取镜像失败

```toml
# 在 config.toml 的 [runners.docker] 段添加
[runners.docker]
  pull_policy = "if-not-present"
  # 国内镜像加速
  dns = ["114.114.114.114", "8.8.8.8"]
```

或配置 Docker daemon 镜像加速:

```json
// /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://registry.docker-cn.com"
  ]
}
```

### Q4: Shell executor 权限问题

```bash
# 确保 gitlab-runner 用户有足够权限
sudo usermod -aG docker gitlab-runner
sudo chmod 755 /home/gitlab-runner
```

### Q5: 如何取消 allow_failure 的影响

当前 `.gitlab-ci.yml` 中所有 Job 均设置了 `allow_failure: true`，这意味着即使 Job 失败 Pipeline 也会显示为成功。待稳定后可移除此设置，使失败的 Job 阻断 Pipeline。

### Q6: Runner 配置修改后如何生效

```bash
sudo gitlab-runner restart
```

## 5. 参考链接

- [GitLab Runner 官方文档](https://docs.gitlab.com/runner/)
- [Runner 配置参考](https://docs.gitlab.com/runner/configuration/advanced-configuration.html)
- [Docker Executor 配置](https://docs.gitlab.com/runner/executors/docker.html)
