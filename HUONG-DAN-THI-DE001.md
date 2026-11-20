# Ôn thi DevOps Fundamentals — Đề 001

## Chạy nhanh trong IntelliJ — cập nhật 20/11/2026

Local đã kiểm tra PASS tại `http://localhost:8099`: 3 container healthy, 8 labs,
đúng thông tin sinh viên, app non-root, MySQL không publish cổng.
Repo `embedangyeunhathemattroi/dev` đang public và trống lúc kiểm tra.
PDF yêu cầu tên `devops-final-de001-phamngoclinh`; nếu đổi tên repo trên GitHub,
thay tham số `-Repo` bên dưới tương ứng. Không tự tạo lại mật khẩu student.env.

GitHub Secrets: Settings → Secrets and variables → Actions → New repository secret:

- `SERVER_HOST`: IP/hostname server Linux, không thêm http hay cổng web.
- `SERVER_USER`: user SSH được cấp, không phải GitHub username.
- `SERVER_SSH_KEY`: toàn bộ private key `.practice/deploy_key`, cả BEGIN/END; không dùng `.pub`.

Server trong hướng dẫn cũ là `221.121.5.186`, user `root`. Xác nhận đúng server của mình
trước khi chạy. Đề yêu cầu tài khoản SSH riêng, không trùng người khác trong nhóm.
Key hiện bị server từ chối; nhập mật khẩu SSH trực tiếp trong terminal để cài public key:

```powershell
Set-Location -LiteralPath 'C:\Users\TRONG TIN\Downloads\devops-final-app-de001\devops-final-app-de001'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\repair-ssh.ps1 -ServerHost 221.121.5.186 -ServerUser root
```

Chỉ sau khi có `PASS`, chạy khối sau. Script tự gửi ba secrets bằng GitHub CLI,
commit/push lên main, chờ Actions rồi xác minh server đúng SHA và 8 labs.
Không cần copy private key thủ công nếu dùng script này. Script không force push.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish-exam.ps1 -ServerHost 221.121.5.186 -ServerUser root -Repo embedangyeunhathemattroi/dev
```

Nếu server/user khác, đổi cả hai lệnh. Nếu SSH hoặc Docker server lỗi, dừng và đọc lỗi;
chưa chạy publish. Bước 8 và gói nộp chờ ảnh thật của bạn, chưa hoàn thành tự động.

Hướng dẫn dựa trên PDF 7 trang bạn gửi, làm bằng **PowerShell trong Terminal IntelliJ trên Windows**. Sau khi SSH, terminal là **Bash trên server Linux**; các khối dưới đây ghi rõ nơi chạy. Dán từng khối theo thứ tự, đợi chạy xong rồi sang bước tiếp theo. Nếu có lỗi màu đỏ, xử lý lỗi trước khi tiếp tục.

Bộ mã nguồn trong thư mục này đã hoàn thiện Dockerfile, Compose, Nginx, CI/CD. Có thêm `/api/info` và `/student.html` vì đề yêu cầu thông tin sinh viên và phiên bản SHA nhưng mã nguồn ban đầu chỉ có `/api/labs`. Không thay đổi cấu trúc JSON danh sách 8 phòng lab.

Mục tiêu là đáp ứng đủ tiêu chí 100 điểm. Điểm thực tế phụ thuộc thông tin của bạn, server truy cập được, pipeline thật chạy xanh, minh chứng và thời hạn nộp; chưa thể bảo đảm 100 điểm chỉ bằng chạy local.

## 0. Thứ tự làm nhanh

| Thời gian dự kiến | Việc | Điểm |
|---|---|---:|
| 0–10 phút | Đúng thư mục, dọn bài cũ, điền thông tin, Git riêng | 10 |
| 10–25 phút | Hiểu Dockerfile, chạy Compose và kiểm tra local | 25 + 20 |
| 25–55 phút | SSH, secrets, repo public, push, CI/CD | 35 |
| 55–75 phút | Kiểm tra server, chụp ảnh, nộp | 10 |
| 75–90 phút | Dự phòng lỗi mạng, registry, SSH | — |

Chuẩn bị trước buổi thi: Docker Desktop chạy Linux containers, Git, OpenSSH, GitHub CLI; tài khoản GitHub; server Linux **x86_64** có Docker Compose v2+, Git, curl, tài khoản SSH thuộc nhóm docker; IP/hostname và cổng HTTP được mở. Pipeline build trên runner x86_64, nên không dùng server ARM với cấu hình hiện tại. Server phải tiếp cận được từ GitHub-hosted runner; `localhost`, IP máy Windows hoặc IP LAN đơn thuần không đủ.

### 0.1. Vào đúng thư mục — PowerShell

Trên máy hiện tại, mã nguồn nằm trong **hai thư mục cùng tên lồng nhau**:

```powershell
Set-Location -LiteralPath 'C:\Users\TRONG TIN\Downloads\devops-final-app-de001\devops-final-app-de001'
Get-Item build.gradle,Dockerfile,docker-compose.yml,student.env
docker version
docker compose version
git --version
ssh -V
```

Nếu copy bài sang chỗ khác, chỉ thay đường dẫn `Set-Location`. Không chạy `git add .` ở `C:\Users\TRONG TIN`: máy này đã có Git ở thư mục người dùng, dễ kéo nhầm toàn bộ file cá nhân. Repository riêng đã được tạo trong thư mục bài này.

### 0.2. Dọn bộ Docker ôn cũ trên máy này

Đã phát hiện project cũ `phamngoclinh-de001`, 3 container, Nginx dùng cổng 8099. Lệnh dưới **xóa container/network và dữ liệu MySQL của đúng bộ bài này**, cho phép đặt mật khẩu mới và nạp lại 8 phòng lab. Không xóa Docker của các bài khác. Chỉ chạy khi bạn muốn bỏ dữ liệu ôn cũ.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action CleanOld -OldProject phamngoclinh-de001 -DeleteData
```

Muốn giữ dữ liệu cũ thì bỏ `-DeleteData`. Script sẽ kiểm tra container thuộc đúng thư mục này trước khi dọn. Nếu script báo thuộc thư mục khác, xem lại `docker compose ls`; không dùng `docker system prune -a --volumes` để chữa lỗi bài này.

### 0.3. Điền thông tin thật một lần

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action Configure
```

Nhập lần lượt: họ tên, mã SV, lớp, email, GitHub username, cổng cá nhân, tên Compose project. Ví dụ tên project: `phamngoclinh-de001`; cổng 8099 **chỉ dùng nếu còn trống và được phân cho bạn trên server**. Script tự tạo hai mật khẩu MySQL riêng cho bài ôn, giữ `EXAM_CODE=001`, `MYSQL_DATABASE=ptit_lab_db`, ghi UTF-8 không BOM và xuống dòng LF.

**Không chạy Configure mỗi lần ôn.** Mỗi lần chạy sẽ tạo mật khẩu mới. Nếu đã có volume MySQL, phải ResetData trước lần Start tiếp theo. Mật khẩu database của bài này nằm trong `student.env` theo đề; không dùng lại mật khẩu server/GitHub/tài khoản thật.

### 0.4. Nạp biến vào terminal hiện tại

Chạy lại khối này mỗi khi mở terminal mới hoặc sửa `student.env`:

```powershell
$ErrorActionPreference = 'Stop'
$cfg = @{}
Get-Content -LiteralPath student.env -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^([A-Z_]+)="([^\"]*)"$') { $cfg[$Matches[1]] = $Matches[2] }
}
$RepoName = 'devops-final-de001-' + ($cfg.COMPOSE_PROJECT_NAME -replace '-de001$','')
$Repo = $cfg.GITHUB_USERNAME + '/' + $RepoName
$AppPort = [int]$cfg.APP_PORT
$Project = $cfg.COMPOSE_PROJECT_NAME
$KeyPath = Join-Path (Get-Location) '.practice\deploy_key'
function Assert-Exit { if ($LASTEXITCODE -ne 0) { throw "Lenh vua chay bi loi: $LASTEXITCODE" } }
Write-Host "Repository: $Repo | Project: $Project | Port: $AppPort"
```

Tên repo phải theo họ tên không dấu đúng đề, ví dụ `devops-final-de001-phamngoclinh`. Nếu tên Compose của bạn là tên viết tắt, đặt lại `$RepoName` theo họ tên đầy đủ rồi cập nhật `$Repo` trước khi tạo repo.

## 1. Repository và student.env — 10 điểm

### 1.1. Khởi tạo Git riêng, cấu hình tác giả

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action InitGit
Assert-Exit
git config --local user.name $cfg.STUDENT_NAME
Assert-Exit
git config --local user.email $cfg.STUDENT_EMAIL
Assert-Exit
git rev-parse --show-toplevel
git branch --show-current
```

Kết quả root phải là thư mục đang chứa `build.gradle`; nhánh là `main`. Nếu đang ở nhánh khác và muốn dùng nó làm bài thi: `git branch -M main`. Không xóa `.git` ở thư mục người dùng. Không cần xóa lịch sử Git để ôn lại; sử dụng repo này và commit mới là nhanh nhất.

### 1.2. Kiểm tra cấu hình

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action Check
Assert-Exit
```

Đủ 13 biến, cổng từ 8080 đến 65535, Compose project viết thường kết thúc `-de001`. Kiểm tra họ tên thực tế trong `student.env`; không để mẫu Nguyễn Văn An.

## 2. Dockerfile multi-stage — 25 điểm

File `Dockerfile` đã có đủ các tiêu chí sau. Bạn cần hiểu các dòng này để tự làm lại trên bộ đề gốc:

| Tiêu chí | Dòng/ý nghĩa | Điểm |
|---|---|---:|
| Hai stage có tên, runtime chỉ JRE | `gradle:8.14-jdk21-alpine AS build`, `eclipse-temurin:21-jre-alpine AS runtime` | 6 |
| Cache dependency trước source | `COPY build.gradle settings.gradle ./` → `RUN gradle dependencies ...` → `COPY src ./src` | 5 |
| Chỉ chuyển JAR sang runtime | `COPY --from=build --chown=spring:spring /workspace/build/libs/app.jar /app/app.jar` | 4 |
| Non-root | tạo user `spring`, `USER spring` | 4 |
| Phiên bản và chạy app | `ARG APP_VERSION`, `ENV APP_VERSION`, `EXPOSE 8080`, `ENTRYPOINT ["java", "-jar", "/app/app.jar"]` | 6 |

**Không đổi sang Gradle 8.7 trong ví dụ của PDF**: Spring Boot 4 cần Gradle 8.14+ hoặc 9.x. Build Docker dùng Gradle trong image; không phụ thuộc cache Gradle Windows đã từng bị lỗi. Gradle wrapper local dùng 9.0.0 cũng hợp lệ.

```powershell
Get-Content Dockerfile -Encoding UTF8
```

## 3. Docker Compose + Nginx + MySQL — 20 điểm

Các TODO đã điền:

| Phần | Cấu hình |
|---|---|
| Build context | `context: .`, vì Compose và Dockerfile nằm cùng thư mục |
| Build arg | `APP_VERSION: ${APP_VERSION:-local}` |
| Image | `${APP_IMAGE:-devops-final-app}:${APP_TAG:-latest}` |
| DB app | `DB_HOST=mysql`, `DB_PORT=3306`, các biến tên/user/password lấy từ `MYSQL_*` |
| Publish | chỉ Nginx `${APP_PORT}:80`; MySQL và app không publish ra host |
| Mount | `./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro` |
| Networks | app tham gia `db-net` và `proxy-net`; MySQL chỉ `db-net`, Nginx chỉ `proxy-net` |
| Dữ liệu | volume `mysql_data`; mount `database/init.sql` read-only |
| Sẵn sàng | MySQL healthy → app healthy → Nginx |

PDF có chỗ ghi đường dẫn mẫu `./devops-final-de001-nguyenvan`; với cấu trúc hiện tại phải dùng `.`. PDF cũng đánh số TODO không nhất quán; đối chiếu chức năng và bảng điểm, không tự thêm service cho đủ số TODO.

### 3.1. Build và kiểm tra bằng một lệnh

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action Start
Assert-Exit
Start-Process "http://localhost:$AppPort"
```

Chờ lần build đầu tải dependency/image. Script tự build, đợi healthy, nạp lại Nginx, kiểm tra 8 bản ghi, thông tin sinh viên, HTML, Nginx syntax, non-root, MySQL không publish. Cuối cùng phải có `PASS`.

Các lệnh Docker gốc để ghi nhớ:

```powershell
docker compose --env-file student.env config --quiet
Assert-Exit
docker compose --env-file student.env up -d --build --wait --wait-timeout 300
Assert-Exit
docker compose --env-file student.env ps
curl.exe -f "http://localhost:$AppPort/api/labs"
Assert-Exit
curl.exe -f "http://localhost:$AppPort/api/info"
Assert-Exit
```

`3306/tcp` trong `docker ps` chỉ là cổng nội bộ. Sai là xuất hiện `0.0.0.0:3306->3306/tcp`. Nginx **luôn listen 80 trong container**; đổi cổng cá nhân ở `APP_PORT`, không đổi `listen 80` thành 8099.

### 3.2. Ôn lại lần 2, 3, 4

Giữ mật khẩu và dữ liệu, chỉ chạy lại:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action Start
```

Muốn làm sạch MySQL để bỏ mật khẩu/dữ liệu cũ của project hiện tại:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action ResetData -DeleteData
if ($LASTEXITCODE -ne 0) { throw 'Reset failed' }
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action Start
```

Tạm dừng sau buổi ôn để nhẹ máy, giữ volume:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action Stop
```

Nếu đổi `COMPOSE_PROJECT_NAME`, phải dọn bằng **tên cũ trước khi đổi**, hoặc dùng CleanOld với tên cũ. `down -v` theo tên mới không xóa volume tên cũ. Không cần gỡ MySQL Windows hoặc xóa nginx trên máy; bộ này sử dụng chúng bên trong container.

## 4. CI/CD GitHub Actions — 35 điểm

### 4.1. GitHub CLI trên Windows

Nếu đã có `gh --version`, bỏ bước cài. Nếu chưa có:

```powershell
winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) { throw 'Kiem tra ket qua cai GitHub CLI' }
$env:Path += ';C:\Program Files\GitHub CLI'
gh --version
```

Nếu không có winget, cài GitHub CLI từ https://cli.github.com rồi mở lại terminal IntelliJ và chạy lại mục 0.4. Đăng nhập đúng GitHub username trong `student.env`:

```powershell
gh auth login --hostname github.com --git-protocol https --web
Assert-Exit
gh auth setup-git
Assert-Exit
gh api user --jq .login
```

### 4.2. Khai báo server thật

```powershell
$ServerHost = (Read-Host 'IP hoac hostname server Linux').Trim()
$ServerUser = (Read-Host 'Tai khoan SSH cua ban').Trim()
if ($ServerHost -notmatch '^[A-Za-z0-9.-]+$' -or $ServerUser -notmatch '^[a-z_][a-z0-9_-]*$') { throw 'IP/hostname hoac user khong hop le' }
$SshTarget = "$ServerUser@$ServerHost"
ssh $SshTarget
```

Lần đầu đối chiếu fingerprint SSH với server, xác nhận rồi nhập mật khẩu SSH nếu được hỏi. Không đưa mật khẩu SSH vào file bài hoặc GitHub repo. Hướng dẫn mặc định SSH cổng 22; nếu server khác cổng, cần thêm cấu hình `SERVER_PORT` và `port` vào workflow tương ứng.

**Bây giờ đang ở Bash trên server**, chạy:

```bash
whoami
uname -m
git --version
curl --version
docker version
docker compose version
docker info >/dev/null && echo DOCKER_OK
ss -ltn
exit
```

Phải thấy `x86_64`, `DOCKER_OK`; cổng APP_PORT chưa bị người khác chiếm. Nếu tài khoản thiếu quyền Docker, quản trị viên thêm đúng user vào nhóm docker và bạn đăng xuất/SSH lại. Nếu server chưa có Docker, xem mục 7; chưa push pipeline khi bước này còn lỗi.

### 4.3. Tạo SSH key dành riêng cho pipeline

**Trở về PowerShell**. Key được giữ trong `.practice/`, đã bị loại khỏi Git, Docker build và gói nộp bài.

```powershell
New-Item -ItemType Directory -Force .practice | Out-Null
if (!(Test-Path -LiteralPath .practice\deploy_key)) {
    ssh-keygen.exe --% -t ed25519 -f .practice/deploy_key -N ""
}
if (!(Test-Path -LiteralPath .practice\deploy_key.pub)) { throw 'Chua tao duoc SSH key' }
$KeyPath = (Resolve-Path -LiteralPath .practice\deploy_key).Path
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\repair-ssh.ps1 -ServerHost $ServerHost -ServerUser $ServerUser
if ($LASTEXITCODE -ne 0) { throw 'SSH/Docker chua san sang. Xem muc 4.3.1.' }
```

`--%` giúp PowerShell Windows truyền `-N ""` đúng. Script repair yêu cầu nhập mật khẩu SSH trực tiếp trong terminal; không lưu mật khẩu. Nó lấy public key từ đúng private key, sao lưu authorized_keys hiện có, thêm key trên dòng riêng rồi kiểm tra đăng nhập không mật khẩu. Giữ nguyên các key khác và không sửa cấu hình sshd. Phải thấy `SSH_KEY_OK`, `DOCKER_OK`, `PASS` trước khi tiếp tục.

### 4.3.1. Sửa lỗi Permission denied trên server hiện tại

Đã kiểm tra trực tiếp: `221.121.5.186` truy cập được; cặp key `.practice/deploy_key` và `.pub` khớp nhau, không có passphrase; server từ chối public key được gửi lên. Chưa xác định được cấu hình/authorized_keys phía server vì đăng nhập bằng key đang thất bại.

Dán nguyên khối vào **PowerShell IntelliJ** và nhập mật khẩu root khi được hỏi:

```powershell
Set-Location -LiteralPath 'C:\Users\TRONG TIN\Downloads\devops-final-app-de001\devops-final-app-de001'
$ServerHost = '221.121.5.186'
$ServerUser = 'root'
$SshTarget = "$ServerUser@$ServerHost"
$KeyPath = (Resolve-Path -LiteralPath .practice\deploy_key).Path
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\repair-ssh.ps1 -ServerHost $ServerHost -ServerUser $ServerUser
if ($LASTEXITCODE -ne 0) { throw 'Chua sua xong SSH/Docker; doc loi ben tren.' }
```

Nếu đã thấy `SSH_KEY_OK` nhưng không có `DOCKER_OK`: key đã sửa xong, kiểm tra Docker theo mục 4.2/7. Nếu vẫn `Permission denied`, đăng nhập bằng mật khẩu để lấy chẩn đoán:

```powershell
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no $SshTarget
```

Sau khi thấy `root@...`, chạy **Bash trên server**:

```bash
id
printf 'HOME=%s\n' "$HOME"
ls -ld /root /root/.ssh /root/.ssh/authorized_keys
ssh-keygen -lf /root/.ssh/authorized_keys
/usr/sbin/sshd -T | grep -E '^(pubkeyauthentication|authorizedkeysfile|permitrootlogin|strictmodes|authenticationmethods) '
journalctl -u ssh -u sshd --since '10 minutes ago' --no-pager | tail -n 50
exit
```

Gửi kết quả chẩn đoán để sửa đúng nguyên nhân (đường dẫn authorized_keys, quyền sở hữu, chính sách đăng nhập hoặc Match block). Không tự bật root login hoặc tắt StrictModes. Không gửi private key/mật khẩu lên chat. `sshd -T` ở đây hiển thị cấu hình cơ sở; nếu có Match block cần kiểm tra thêm theo kết nối thực tế.

Theo đề thi server chung cần tài khoản riêng từng sinh viên; `root` là tài khoản bạn đang dùng để xử lý kết nối hiện tại. Khi chuyển sang tài khoản thi riêng, cài key cho tài khoản đó và cập nhật SERVER_USER trong GitHub Secrets.

### 4.4. Tạo repo public và secrets TRƯỚC push đầu tiên

Nếu đã có bộ bài cũ trên server với mật khẩu khác: trước khi push, SSH vào thư mục **bài của mình**, kiểm tra tên project/container rồi dọn theo mục 6.1. Bỏ qua nếu chưa từng triển khai repo này. Không đổi mật khẩu trong student.env rồi giữ nguyên volume cũ.

Kiểm tra repo đã tồn tại chưa; nếu có thì dùng lại, không xóa repo cũ:

```powershell
gh repo view $Repo --json nameWithOwner,isPrivate
```

Nếu trả về `Could not resolve to a Repository`, tạo mới:

```powershell
gh repo create $Repo --public
Assert-Exit
```

Repo mới để trống, không tạo README ở giao diện GitHub. Nếu repo đã có code/lịch sử khác, xem mục 6.5 trước khi push.

```powershell
$remotes = @(git remote)
if ($remotes -contains 'origin') {
    git remote set-url origin "https://github.com/$Repo.git"
} else {
    git remote add origin "https://github.com/$Repo.git"
}
Assert-Exit
gh secret set SERVER_HOST --repo $Repo --body $ServerHost
Assert-Exit
gh secret set SERVER_USER --repo $Repo --body $ServerUser
Assert-Exit
Get-Content -LiteralPath $KeyPath -Raw | gh secret set SERVER_SSH_KEY --repo $Repo
Assert-Exit
gh secret list --repo $Repo
gh repo view $Repo --json nameWithOwner,isPrivate,url
```

Phải thấy 3 tên secrets và `isPrivate: false`. `GITHUB_TOKEN` có sẵn ở Actions, không tự tạo secret tên này. Workflow đã cấp `packages: write` cho build và `packages: read` cho deploy; token đăng nhập GHCR qua stdin, không ghi vào source. Nếu repo cũ đang private, đổi sang public trong Settings trước khi nộp.

### 4.5. Hiểu pipeline đã hoàn thiện

| Bước | Việc pipeline thực hiện |
|---|---|
| Trigger | push main hoặc chạy thủ công |
| Validate | đọc student.env, kiểm tra biến, port, project, mã đề và database |
| Image | `ghcr.io/<github-username>/<repo>/app` viết thường |
| Build/test | Compose build + up --wait; kiểm tra 8 labs, thông tin sinh viên, SHA và trang HTML |
| Registry | docker/login-action; push 2 tag SHA đầy đủ và latest |
| Cleanup runner | down -v trên runner tạm, không phải database server |
| Deploy dependency | `needs: build` |
| SSH | 3 secrets ở bước trên |
| Server | clone/fetch, checkout chính xác commit SHA, pull app, up --no-build, reload Nginx |
| Verify server | API, SHA và image ID container khớp image SHA vừa pull |

Deployment dùng `~/<tên-repo>` dành riêng cho pipeline. Không chỉnh tay source trong thư mục đó vì lần deploy sau `git reset --hard` đưa nó về commit đã build. Workflow **không xóa volume MySQL trên server**.

### 4.6. Commit và push

```powershell
git add .
Assert-Exit
$leakedKeys = @(git diff --cached --name-only | Where-Object { $_ -match '(^|/)(\.practice/|deploy_key|id_rsa|id_ed25519)|\.(pem|key)$' })
if ($leakedKeys.Count -gt 0) { throw ('Dung lai: dang stage key: ' + ($leakedKeys -join ', ')) }
git diff --cached --stat
git commit -m 'Complete DevOps exam 001: Docker Compose and CI CD'
Assert-Exit
git push -u origin main
Assert-Exit
gh run list --repo $Repo --branch main --limit 3
```

Đợi vài giây để run xuất hiện. Lấy run đúng commit vừa push rồi theo dõi:

```powershell
$Commit = (git rev-parse HEAD).Trim()
$RunId = gh run list --repo $Repo --branch main --commit $Commit --limit 1 --json databaseId --jq '.[0].databaseId'
if (!$RunId) { throw 'Run chua xuat hien. Doi vai giay roi chay lai khoi nay.' }
gh run watch $RunId --repo $Repo --exit-status
Assert-Exit
gh run view $RunId --repo $Repo --web
```

Nếu run đỏ:

```powershell
gh run view $RunId --repo $Repo --log-failed
```

Sửa code → commit → push mới. Chỉ lỗi tạm thời như network/secret vừa sửa thì rerun:

```powershell
gh run rerun $RunId --repo $Repo --failed
Assert-Exit
```

### 4.7. Xác minh server đúng SHA mới nhất

```powershell
ssh -i $KeyPath $SshTarget "cd ~/$RepoName && docker compose --env-file student.env ps"
Assert-Exit
$RemoteInfo = Invoke-RestMethod "http://${ServerHost}:$AppPort/api/info" -TimeoutSec 20
$ExpectedSha = (git rev-parse HEAD).Trim()
if ($RemoteInfo.appVersion -cne $ExpectedSha) { throw 'Server chua chay SHA moi nhat' }
if ($RemoteInfo.studentId -cne $cfg.STUDENT_ID -or $RemoteInfo.studentName -cne $cfg.STUDENT_NAME) { throw 'Sai thong tin sinh vien' }
$RemoteLabs = Invoke-RestMethod "http://${ServerHost}:$AppPort/api/labs" -TimeoutSec 20
if (@($RemoteLabs).Count -ne 8) { throw 'Khong du 8 phong lab' }
$RemoteInfo | ConvertTo-Json
Start-Process "http://${ServerHost}:$AppPort"
```

Không dùng `localhost` để chụp ảnh minh chứng server. Trang gốc chuyển sang `/student.html`, hiển thị JSON phòng lab và thông tin sinh viên/SHA; `/api/labs` vẫn là JSON array như đề.

## 5. Minh chứng và nộp bài — 10 điểm

### 5.1. Chụp đủ ảnh thật

Windows: `Win + Shift + S`, lưu PNG vào `screenshots/`:

| File | Nội dung cần nhìn thấy |
|---|---|
| `01-actions.png` | Run main có cả Build & Test và Deploy xanh |
| `02-ghcr.png` | GitHub profile → Packages → package app, có tag SHA và latest |
| `03-compose-ps.png` | Kết quả Compose ps **qua SSH trên server**, đủ 3 service healthy và đúng port |
| `04-website.png` | URL server, JSON phòng lab; chụp trang `/student.html` để thấy cả tên/mã SV/SHA |

Có thể thêm `05-api-labs.png` chụp thẳng `/api/labs` và `06-version.png` nếu SHA không vừa trong ảnh. Không chụp key, token, mật khẩu. Đề yêu cầu web chạy đến khi có điểm: không down server sau khi nộp.

### 5.2. Đưa ảnh vào Git và chạy pipeline cuối

```powershell
$required = @('01-actions.png','02-ghcr.png','03-compose-ps.png','04-website.png')
foreach ($name in $required) {
    if (!(Test-Path -LiteralPath (Join-Path screenshots $name))) { throw "Thieu anh: $name" }
}
New-Item -ItemType Directory -Force submission-content | Out-Null
Copy-Item screenshots\*.png submission-content\ -Force
git add screenshots submission-content
git commit -m 'Add exam evidence'
Assert-Exit
git push
Assert-Exit
```

Commit ảnh cũng tạo SHA mới: **đợi pipeline mới xanh**, chạy lại mục 4.7. Chụp lại 4 ảnh cuối vào `submission-content/` để khớp deployment cuối rồi đưa lên server theo mục dưới. Không commit tiếp sau đó để tránh tạo vòng lặp đổi SHA. Ảnh đã commit trong repo chứng minh run thành công trước đó; bộ nộp chứa ảnh cuối cùng và SHA cuối cùng.

### 5.3. Tạo thông tin nộp và log server

```powershell
$FinalSha = (git rev-parse HEAD).Trim()
$Submission = @(
    "Repository: https://github.com/$Repo",
    "Website: http://${ServerHost}:$AppPort",
    "API: http://${ServerHost}:$AppPort/api/labs",
    "Commit: $FinalSha",
    "Student: $($cfg.STUDENT_NAME) - $($cfg.STUDENT_ID)",
    "Actions: https://github.com/$Repo/actions"
)
[IO.File]::WriteAllLines((Join-Path (Get-Location) 'submission-content\THONG-TIN-NOP.txt'), $Submission, (New-Object Text.UTF8Encoding $false))
$serverPs = ssh -i $KeyPath $SshTarget "cd ~/$RepoName && docker compose --env-file student.env ps"
Assert-Exit
$serverPs | Set-Content submission-content\compose-ps.txt -Encoding UTF8
```

### 5.4. Upload minh chứng, tải bài từ server bằng SFTP đúng đề

Vẫn chạy trong **PowerShell IntelliJ**, sau khi pipeline cuối xanh và ảnh cuối đã lưu:

```powershell
$KeyForSftp = $KeyPath.Replace('\','/')
$LocalSubmission = (Join-Path (Get-Location) 'submission-content').Replace('\','/')
$batchUpload = @(
    "cd $RepoName",
    "put -r `"$LocalSubmission`" ."
)
[IO.File]::WriteAllLines((Join-Path (Get-Location) '.practice\upload.sftp'), $batchUpload, (New-Object Text.UTF8Encoding $false))
sftp -i $KeyForSftp -b .practice\upload.sftp $SshTarget
Assert-Exit
```

Tạo ZIP **trên server** chỉ gồm source đã commit + minh chứng, không có `.git`, SSH key, cache hay dữ liệu DB. Sau đó tải ZIP bằng SFTP:

```powershell
$packCommand = 'set -e; cd "$HOME/{0}"; stage=$(mktemp -d); trap ''rm -rf "$stage"'' EXIT; mkdir -p "$stage/{0}"; git archive HEAD | tar -x -C "$stage/{0}"; cp -R submission-content/. "$stage/{0}/submission-content/"; cd "$stage"; python3 -m zipfile -c "$HOME/{0}-submission.zip" "{0}"' -f $RepoName
ssh -i $KeyPath $SshTarget $packCommand
Assert-Exit
$batchDownload = "get $RepoName-submission.zip .practice/$RepoName-submission.zip"
[IO.File]::WriteAllText((Join-Path (Get-Location) '.practice\download.sftp'), $batchDownload + "`n", (New-Object Text.UTF8Encoding $false))
sftp -i $KeyForSftp -b .practice\download.sftp $SshTarget
Assert-Exit
Get-Item ".practice\$RepoName-submission.zip"
```

Server cần `python3` cho bước đóng ZIP; không cần Python trên Windows. Nếu hệ thống nộp bắt buộc tải nguyên thư mục bằng SFTP, dùng thêm `get -r <tên-repo>` trong SFTP rồi nén thư mục tải về, loại `.git` và file không liên quan trước khi nộp.

Nộp **link repo public** và ZIP vào RAIA theo giao diện yêu cầu. Kiểm tra ZIP có `Dockerfile`, `.github/workflows/ci-cd.yml`, `student.env`, `src/`, `screenshots/`, `submission-content/`; không có `.practice/deploy_key`. Tất cả commit và run chấm điểm phải trước giờ hết bài.

## 6. Sửa lỗi nhanh, đúng nguyên nhân

### 6.1. MySQL `Access denied` sau khi đổi mật khẩu

`MYSQL_PASSWORD` chỉ khởi tạo user khi volume còn trống. Sửa student.env rồi restart không cập nhật user cũ. Với dữ liệu ôn có thể xóa: chạy ResetData -DeleteData rồi Start ở mục 3.2. Không tự chạy init.sql lần hai trên DB cũ vì có thể thêm trùng 8 bản ghi.

Trên server, chỉ khi **chấp nhận bỏ dữ liệu bài ôn của mình**: SSH, vào đúng thư mục repo, kiểm tra `docker compose --env-file student.env ps`, sau đó `docker compose --env-file student.env down -v --remove-orphans`. Quay về PowerShell rerun pipeline để pull đúng image và khởi tạo lại. Không dùng `up --no-build` riêng ở server khi chưa export APP_IMAGE/APP_TAG vì có thể tìm nhầm image mặc định local.

### 6.2. Nginx 502 / app chưa sẵn sàng

```powershell
docker compose --env-file student.env ps
docker compose --env-file student.env logs --tail 100 app mysql nginx
docker compose --env-file student.env exec -T nginx nginx -t
```

Nếu app lỗi DB → xử lý DB trước. Nếu vừa sửa `nginx/default.conf`, chạy `docker compose --env-file student.env restart nginx`. Cấu hình đã dùng Docker DNS để cập nhật IP app khi deploy lại. Redirect tương đối giữ đúng APP_PORT; không chuyển nhầm về cổng 80 trên host.

### 6.3. Port is already allocated

```powershell
docker ps --format 'table {{.Names}}\t{{.Ports}}'
Get-NetTCPConnection -LocalPort $AppPort -State Listen -ErrorAction SilentlyContinue
```

Container bài cũ của bạn → CleanOld bằng đúng tên project. Cổng của ứng dụng/người khác → chọn APP_PORT khác được phân, sửa student.env, chạy lại mục 0.4, commit/push. Không kill tất cả nginx/java hoặc xóa container người khác.

### 6.4. Compose vẫn dùng port/project/password cũ

Biến môi trường terminal có ưu tiên cao hơn `--env-file`. Xóa các override cho phiên PowerShell này rồi đọc lại file:

```powershell
@('COMPOSE_PROJECT_NAME','COMPOSE_FILE','APP_PORT','APP_IMAGE','APP_TAG','APP_VERSION','MYSQL_DATABASE','MYSQL_USER','MYSQL_PASSWORD','MYSQL_ROOT_PASSWORD','STUDENT_NAME','STUDENT_ID','STUDENT_CLASS','EXAM_CODE') | ForEach-Object {
    Remove-Item -LiteralPath "Env:$_" -ErrorAction SilentlyContinue
}
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\practice.ps1 -Action Check
```

### 6.5. Git cũ, origin cũ, push rejected

```powershell
git rev-parse --show-toplevel
git remote -v
git status
```

Nếu origin sai, `git remote set-url origin "https://github.com/$Repo.git"`. Nếu remote main đã có lịch sử, sau khi commit local:

```powershell
git fetch origin main
Assert-Exit
git log --oneline --max-count=5 origin/main
git merge origin/main --allow-unrelated-histories --no-edit
```

Nếu conflict, mở từng file IntelliJ, giữ cấu hình bài thi đã kiểm tra, xóa dấu conflict rồi `git add .`, `git commit`, `git push -u origin main`. Không dùng `git push --force` làm mặc định. Muốn ôn sạch nhất mà không gặp merge: tạo repo trống đúng tên ngay từ đầu, sau đó giữ repo ấy cho các lần ôn tiếp theo.

Không phải cứ ôn lại là xóa Git; `git init` không xóa origin/lịch sử cũ. Repo riêng hiện tại đã ngăn việc Git nhận nhầm thư mục người dùng.

### 6.6. CI build xanh, deploy đỏ

| Log | Cách sửa |
|---|---|
| `handshake failed`, `unable to authenticate` | kiểm tra SERVER_USER, private key đầy đủ, public key ở authorized_keys đúng user; chạy kiểm tra BatchMode mục 4.3 |
| SSH timeout | host phải truy cập được từ runner; mở cổng 22/firewall/security group; không dùng IP LAN |
| Permission denied docker.sock | thêm đúng user vào nhóm docker, đăng nhập SSH mới |
| `denied` khi push GHCR | repo có quyền Actions packages:write; nếu package cũ thuộc repo khác, vào Package settings → Manage Actions access cấp repo hiện tại quyền Write |
| `denied` khi pull GHCR | job deploy cần packages:read, package cho phép repo hiện tại truy cập; token hiện tại chỉ sống trong job |
| Clone yêu cầu username/password | repo phải public; kiểm tra origin/URL |
| Server 502 | kiểm tra app/mysql logs; mật khẩu volume cũ; restart nginx |
| Runner curl `/api/info` 404 | chưa commit InfoController và static/student.html; kiểm tra `git status` |
| API dùng SHA cũ | chờ deploy cuối, kiểm tra run đúng commit; đừng tự build image trên server |
| Truy cập server bằng curl nội bộ được, máy cá nhân không được | mở APP_PORT/TCP ở firewall host và firewall cloud |

### 6.7. Gradle Windows lại báo thiếu metadata.bin

Build Docker vẫn hoạt động vì dùng cache Linux riêng. Nếu cần sync IntelliJ: đóng tiến trình sync, `./gradlew.bat --stop`, đổi tên riêng `C:\Users\TRONG TIN\.gradle\caches\9.0.0\transforms` thành thư mục backup rồi Reload Gradle. Không xóa source hoặc đổi Java tùy tiện; bài dùng Java 21.

## 7. Nếu server chưa có Docker

Mục này dành cho **quản trị viên server Ubuntu**, chỉ làm một lần trước buổi thi. Nếu server chung đã cài Docker thì bỏ qua. Không cài lại Docker lên server đang có bài của người khác. Lệnh theo tài liệu Docker chính thức; cần internet và quyền sudo.

Trong Bash server Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git python3
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$(whoami)"
exit
```

SSH lại rồi `docker info`, `docker compose version`. Quản trị viên mở đúng APP_PORT/TCP trên firewall, giữ SSH 22; nếu dùng cloud phải mở security group tương ứng. Tài khoản SSH riêng của mỗi sinh viên, không dùng trùng theo đề.

## 8. Checklist trước khi bấm nộp

- [ ] Repo public, đúng tên họ tên, nhánh main; link repo nộp lên RAIA.
- [ ] student.env là thông tin thật, đủ biến, EXAM_CODE=001, DB=ptit_lab_db.
- [ ] Dockerfile 2 stage có tên, cache dependencies trước source, JRE21, non-root, ARG/ENV, exec ENTRYPOINT.
- [ ] Compose đúng biến, mount read-only, 2 mạng, volume DB; chỉ Nginx public cổng cá nhân.
- [ ] 8 bản ghi `/api/labs`, thông tin sinh viên đúng, SHA trên server đúng commit cuối.
- [ ] CI build và deploy đều xanh trước giờ kết thúc; GHCR có tag SHA và latest.
- [ ] 4 ảnh thật đủ, ảnh cuối nằm trong submission-content, ZIP tải từ server.
- [ ] Không commit private key/token/mật khẩu server; không dùng cổng trùng; giữ website chạy tới lúc chấm.

## Nguồn kiểm tra kỹ thuật

Kiểm tra local ngày 20/11/2026: đã build multi-stage bằng Docker; MySQL/app/Nginx đều healthy; 8 phòng lab; thông tin sinh viên UTF-8; root redirect HTTP 200; app UID 100 (non-root); MySQL không có host port binding. Script Verify chạy thành công; 33 khối PowerShell trong bản hướng dẫn ban đầu đã kiểm tra cú pháp; workflow qua actionlint. Việc push GHCR/deploy SSH chưa kiểm chứng trên tài khoản/server của bạn vì chưa có thông tin kết nối.

Đề PDF của bạn quyết định yêu cầu/thang điểm. Những điểm dễ nhầm được đối chiếu với tài liệu chính thức:

- Spring Boot 4 và Gradle 8.14+/9.x: https://docs.spring.io/spring-boot/4.0/gradle-plugin/
- Compose chỉ chờ readiness khi có healthcheck/service_healthy: https://docs.docker.com/compose/how-tos/startup-order/
- MySQL image không khởi tạo lại credentials trên data directory đã có dữ liệu: https://hub.docker.com/_/mysql
- GHCR và GITHUB_TOKEN/permissions: https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images
- Nginx proxy_pass qua biến và resolver: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass
- Cài Docker trên Ubuntu: https://docs.docker.com/engine/install/ubuntu/
